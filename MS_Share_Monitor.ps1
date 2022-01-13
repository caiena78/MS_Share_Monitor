

function smbobj {
    param (
        $smb
    )
    $smbobj=New-Object -TypeName 'System.Collections.ArrayList';
    foreach ($item in $smb){
        $smbobj.add(("@" | select-object AccessControlType, AccessRight, AccountName, Name, PSComputerName))
    }

    
}


function GetSharInfo {
    param (
        $computername,
        $path
    )

    # $data= "" | select server,uri,smb_name,smb_acl,FileShare,NTFS_ACL
    $items = [System.Collections.ArrayList]::new()
    #$computername="smhfilep6"
    $server=New-CimSession -ComputerName $computername
    $fsid=Get-FileShare -CimSession $server -AsJob
    $null= Wait-Job -id $fsid.id
    $fileshare=Receive-Job -job $fsid    
    
    $file="{0}.json" -f $computername
    $filehash="{0}.hash" -f $computername
    $file = Join-Path -path $path -ChildPath $file
    $filehash = Join-Path -path $path -ChildPath $filehash

    foreach ($share in $fileshare){
        $data= "" | Select-Object server,uri,smb_name,smb_acl,FileShare,NTFS_ACL
        $path="\\{0}\{1}" -f $share.pscomputername, $share.name    
        #Write-Host $path
        $acl=get-acl $path 
        $smbacljob=Get-SmbShareAccess -CimSession $server -name $share.name -AsJob 
        $null = Wait-Job -id $smbacljob.id      
        $smbdata=receive-job -job $smbacljob
        $data.server=$share.pscomputername
        $data.uri=$path
        $data.smb_name=$share.name 
        $data.smb_acl=$smbdata | select-object AccessControlType, AccessRight, AccountName, Name, PSComputerName  
        $data.fileshare=$share | Select-Object HealthStatus, OperationalStatus, ShareState,FileSharingProtocol,Description,EncryptData,Name,VolumeRelativePath,PSComputerName
        $data.ntfs_acl=$acl | select-object AccessToString
        $_TempCliXMLString  =   [System.Management.Automation.PSSerializer]::Serialize($data, [int32]::MaxValue)    
        $null=$items.add(  [System.Management.Automation.PSSerializer]::Deserialize($_TempCliXMLString)) 
    }
    $items.ToArray() | ConvertTo-Json  | Set-Content -path $file
    $hash=Get-FileHash -path $file
    $hash.hash | Set-Content -path $filehash   
    return $file, $filehash
}


function compareHash{
    param (
        $temphash,
        $serverhash
    )
   $hash_temp=Get-Content -Path $temphash
   $hash_Server=Get-Content -Path $serverhash
   if ($hash_temp -eq $hash_Server){
       return $true
   }
   return $false
}

function CheckState {
    param (
        $tempHash,
        $ServerHash
    )
    # 0 = does not exist
    # 1 = changed
    # 2 = unchanged       
    if (test-path -path $ServerHash -PathType Leaf){
       if (compareHash $tempHash $ServerHash){
          return 2  # 2 = unchanged   
       }else {
           return 1 # 1 = changed
       }

    }else {
        return 0 # does not exist
    }

}


function hashupdate {
    param (
        $temphash,
        $serverFilePath
    )
    Copy-Item -path $temphash -Destination $serverFilePath
    
}

function  updateFiles {
    param (
        $tempFiles,
        $serverLocation
    )
    foreach ($file in $tempFiles){
        write-host $file
        Copy-Item -path $file  -Destination $serverLocation
    }
    
    
}

function compareFiles {
    param (
        $serverFile,    
        $tempFile       
    )
    $serverObj=Get-Content -path $serverFile | convertfrom-json 
    $tempobj= Get-Content -path $tempFile | ConvertFrom-Json
    $output=compare-object -ReferenceObject $tempobj -DifferenceObject $serverObj
    return $output
}


$basPath=Get-Location
$tempPath=Join-Path -path $basPath -ChildPath 'temp'
$serverPath=Join-Path -path $basPath -ChildPath "servers"

$Servers=@("smhfilep6","smhfilep7","its-chad")

foreach ($server in $servers){
    $file,$filehash = GetSharInfo $server $tempPath       
    $baseFile=split-path $filehash -Leaf
    $serverHash = Join-Path -path $serverPath -ChildPath $baseFile
    $statusCode=CheckState $filehash $serverHash
    if ($statusCode -eq 0){
        updateFiles @($filehash,$file) $serverPath
    }
    if($statusCode -eq 1){
       write-host "changes"
       $basefileJson=split-path $file -Leaf
       $serverJson= join-path -Path $serverPath -ChildPath $basefileJson
       $diff=compareFiles $file  $serverJson
       $diff
       $diff | Set-Content output.txt
       updateFiles @($filehash,$file) $serverPath
    }
    if($statusCode -eq 2){
        write-host "No updates"
    }
}   


# 147.206.164.161



