

#
# Copyright (c) 2021  Chad Aiena <caiena78@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# 



param(
    [parameter(
        Mandatory = $true,
        ValueFromPipeline = $true)]
    $pipelineInput
)

Begin {

    Write-Host `n"The begin {} block runs once at the start, and is good for setting up variables."
    Write-Host "-------------------------------------------------------------------------------"
    
    function smbobj {
        param (
            $smb
        )
        $smbobj = New-Object -TypeName 'System.Collections.ArrayList';
        foreach ($item in $smb) {
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
        $server = New-CimSession -ComputerName $computername
        $fsid = Get-FileShare -CimSession $server -AsJob
        $null = Wait-Job -id $fsid.id
        $fileshare = Receive-Job -job $fsid    
    
        $file = "{0}.json" -f $computername
        $filehash = "{0}.hash" -f $computername
        $file = Join-Path -path $path -ChildPath $file
        $filehash = Join-Path -path $path -ChildPath $filehash

        foreach ($share in $fileshare) {
            $data = "" | Select-Object server, uri, smb_name, smb_acl, FileShare, NTFS_ACL
            $path = "\\{0}\{1}" -f $share.pscomputername, $share.name    
            #Write-Host $path
            $acl = get-acl $path 
            $smbacljob = Get-SmbShareAccess -CimSession $server -name $share.name -AsJob 
            $null = Wait-Job -id $smbacljob.id      
            $smbdata = receive-job -job $smbacljob
            $data.server = $share.pscomputername
            $data.uri = $path
            $data.smb_name = $share.name 
            $data.smb_acl = $smbdata | select-object AccessControlType, AccessRight, AccountName, Name, PSComputerName  
            $data.fileshare = $share | Select-Object HealthStatus, OperationalStatus, ShareState, FileSharingProtocol, Description, EncryptData, Name, VolumeRelativePath, PSComputerName
            $data.ntfs_acl = $acl | select-object AccessToString
            $_TempCliXMLString = [System.Management.Automation.PSSerializer]::Serialize($data, [int32]::MaxValue)    
            $null = $items.add(  [System.Management.Automation.PSSerializer]::Deserialize($_TempCliXMLString)) 
        }
        $items.ToArray() | ConvertTo-Json  | Set-Content -path $file
        $hash = Get-FileHash -path $file
        $hash.hash | Set-Content -path $filehash   
        return $file, $filehash
    }


    function compareHash {
        param (
            $temphash,
            $serverhash
        )
        $hash_temp = Get-Content -Path $temphash
        $hash_Server = Get-Content -Path $serverhash
        if ($hash_temp -eq $hash_Server) {
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
        if (test-path -path $ServerHash -PathType Leaf) {
            if (compareHash $tempHash $ServerHash) {
                return 2  # 2 = unchanged   
            }
            else {
                return 1 # 1 = changed
            }

        }
        else {
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
        foreach ($file in $tempFiles) {
            write-host $file
            Copy-Item -path $file  -Destination $serverLocation
        }
    
    
    }

    function compareFiles {
        param (
            $serverFile,    
            $tempFile       
        )
        $serverObj = Get-Content -path $serverFile 
        $tempobj = Get-Content -path $tempFile 
        $output = compare-object -ReferenceObject $tempobj -DifferenceObject $serverObj
        return $output
    }



}



Process {

    
    

    $basPath = Get-Location
    $tempPath = Join-Path -path $basPath -ChildPath 'temp'
    $serverPath = Join-Path -path $basPath -ChildPath "servers"

    ForEach ($server in $pipelineInput) {
        $file, $filehash = GetSharInfo $server $tempPath       
        $baseFile = split-path $filehash -Leaf
        $serverHash = Join-Path -path $serverPath -ChildPath $baseFile
        $statusCode = CheckState $filehash $serverHash
        if ($statusCode -eq 0) {
            updateFiles @($filehash, $file) $serverPath
        }
        if ($statusCode -eq 1) {
            write-host "changes"
            $basefileJson = split-path $file -Leaf
            $serverJson = join-path -Path $serverPath -ChildPath $basefileJson
            $diff = compareFiles $file  $serverJson
            $diff            
            updateFiles @($filehash, $file) $serverPath
        }
        if ($statusCode -eq 2) {
            write-host "No updates"
        }
    }   
    
   

}















