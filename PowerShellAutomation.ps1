[CmdletBinding()]
Param (

    [Parameter(Mandatory=$False)]
	[ValidateNotNullOrEmpty()]
    [PSCredential]$Switch_cred,

  	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$BmcSwitchIP,

	[Parameter(Mandatory=$True)]
	[ValidateNotNullOrEmpty()]
    [String]$SwitchFilesFolderpath

)

function CalulateSwitchIPs() {

        Param (
  	    [Parameter(Mandatory=$True)]
	    [ValidateNotNullOrEmpty()]
	    [string]$BmcSwitchIP 
        )

        $IsIpValid= [bool]($BmcSwitchIP  -as [ipaddress] -and ($BmcSwitchIP.ToCharArray() | ?{$_ -eq "."}).count -eq 3)

        if ($IsIpValid){

        }

        else{

             throw $_.Exception.Messag
	         write-host " exception.... switch $SwitchIp"
        }

        $ValidBmcSwitchIP=$BmcSwitchIP 
		
        [hashtable]$SwitchIPTable = @{}

        #$BMCIPadd ="10.20.30.40"
        $BMCIPadd=$ValidBmcSwitchIP
        $BmcOct = $ValidBmcSwitchIP.Trim().Split('.')
        $Tor1IPadd = $BmcOct[0] + "." + $BmcOct[1] + "." + $BmcOct[2] + "." + (($BmcOct[3] -as[int])+1) -as[string]
        $Tor2IPadd = $BmcOct[0] + "." + $BmcOct[1] + "." + $BmcOct[2] + "." + (($BmcOct[3] -as[int])+2) -as[string]

        $SwitchIPTable.Add("BMCIP", $BMCIPadd)
        $SwitchIPTable.Add("Tor1IP", $Tor1IPadd)
        $SwitchIPTable.Add("Tor2IP", $Tor2IPadd)
        
        return $SwitchIPTable
     }

function TargetFWVersionInCFGfile {
    
        param (

	    [Parameter(Mandatory=$True)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchFilesFolderpath

    )
         $BmcFWVersion = (Get-ChildItem $SwitchFilesFolderpath -File *BMC.cfg |Get-Content  | select-string -Pattern " FW Version").ToString()
         $TargetFWVersion=  $BmcFWVersion.Split("/")[0].Split(":")[1]

          return $TargetFWVersion
        }

 function IndentifySwitchMake {
    
        param (

	    [Parameter(Mandatory=$True)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchFilesFolderpath

        )   

        $BMCfileName=(Get-ChildItem $SwitchFilesFolderpath -file *BMC.CFG).BaseName

        if ($BMCfileName -like "*CISCO-*"){
        $switchMake="CISCO"

        }

        elseif ($BMCfileName -like "*ARISTA-*"){

        $switchMake="ARISTA"

        }

        else{

        $switchMake="HPE"

        }

        Return $switchMake
}
 function FilePreProcess {
    
        param (

	    [Parameter(Mandatory=$True)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchFilesFolderpath

        )

        #validate Folder path
    
        try {
            if (Test-Path -Path $SwitchFilesFolderpath) 
            {
            Write-Host "checking the switch config files "
            }

        } catch{

           Write-Host "Path is in valid provide a correct path"

           }

         # Modeify the number Files

         Get-ChildItem -path $SwitchFilesFolderpath | Rename-Item -NewName { $_.Name -replace  $_.Name,$((Get-Date).ToString("MMddyyyy")+"_"+$_.name) }
          
          $BMCCFGFile  = (Get-ChildItem $SwitchFilesFolderpath -file *BMC.CFG).FullName 
          $TOR1CFGFile = (Get-ChildItem $SwitchFilesFolderpath -file *TOR1.cfG).FullName
          $TOR2CFGFile = (Get-ChildItem $SwitchFilesFolderpath -file *TOR2.cfG).FullName 

          $ProcessedFilesMap= @{
          BMC=$BMCCFGFile
          TOR1=$TOR1CFGFile
          TOR2=$TOR2CFGFile
          
          }
         
         return $ProcessedFilesMap

       }

function SwitchSSHConnectvityAndExistingFW {
    
        param (

	    [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchIp,
		
        [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [PSCredential]$Switch_cred,

        [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [Int] $Timeout = 300

        )
         
        $Switch_connection = New-SSHSession -ComputerName $SwitchIp -Credential $Switch_cred -AcceptKey       
        $swicth_connection_sessionID = $Switch_connection.SessionId
	
        if ($Switch_connection.Connected -eq $true)
        {
           write-host "Successfully connected to switch $SwitchIp"	
        } 
	    else{
            throw $_.Exception.Messag
	    write-host " exception.... switch $SwitchIp"
        }

         $result = Invoke-SSHCommand -SessionId $swicth_connection_sessionID -Command "system-view`ndisplay current-configuration"
         $FWVersion= ($result.Output| Select-String -Pattern "FW Version:" ).ToString()
         $ExistingFWVERSIONOnSwitch =$FWVersion.Split("/")[0].Split(":")[1]
         return $ExistingFWVERSIONOnSwitch
        }

function New-SwitchSession {
    Param (
	    [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchIp,
		
        [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [PSCredential]$Switch_cred,

	    [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [Int] $Timeout = 300
    )

    $Switch_connection = New-SSHSession -ComputerName $SwitchIp -Credential $Switch_cred -AcceptKey       
    #$swicth_connection_sessionID = $Switch_connection.SessionId
	
    if ($Switch_connection.Connected -eq $true)
    {
       write-host "Successfully connected to switch $SwitchIp"	
    } 
	else{
        throw $_.Exception.Messag
	write-host " exception.... switch $SwitchIp"
    }
    return $Switch_connection
}


 function Copy-fileToSwitch {
    
    param (

	    [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchIp,
		
        [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [PSCredential]$Switch_cred,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String] $switch_cfg_file_path,
        
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String] $Swith_Path = "/",

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String] $Command = "system-view`nsftp server enable"

  )

                    #$switch_cfg_file= Split-Path -path $switch_cfg_file_path -Leaf

                    $SwitchSSHsession = New-SwitchSession -SwitchIp $SwitchIp -Switch_cred $Switch_cred 

                    $swicth_connection_sessionID = $SwitchSSHsession.SessionId


                    if ($SwitchSSHsession.Connected -eq $true) {

		                Write-Output "Successfully connected to swicth $SwitchIp"

		                # Invoking ssh command to pass commands to switch.


		                $result = Invoke-SSHCommand -SessionId $swicth_connection_sessionID -Command $Command


		                # Establishing new sftp session to transfer files from hlh to switch.

		                $Sftp_session = New-SFTPSession -ComputerName $SwitchIp -Credential $Switch_cred 
		                $Sftp_sessionID = $Sftp_session.SessionId
		
		                # Transferring required files from hlh to swtch.

		                Set-SFTPFile -SessionId $Sftp_sessionID -LocalFile $switch_cfg_file_path -RemotePath $Swith_Path -Overwrite

		                Write-Output "File Copied Successfully"
                        
                        # Disconnecting sftp session

                        $Rm_Sftp_session = Remove-SFTPSession -SessionId  $Sftp_sessionID
    
                        if ($Rm_Sftp_session -eq $true) {
                            
                            Write-Host "Successfully disconnected sftp session from switch $SwitchIp"
    
                        }


                        # Disconnecting SSH session

                        $Rm_ssh_session = Remove-SSHSession -SessionId $swicth_connection_sessionID


                        if ($Rm_ssh_session -eq $true) {
                            
                            Write-Host "Successfully disconnected ssh session from switch $SwitchIp"
                        }
				         
	                }

                    else {
                        Write-Output "Failed to Establishing the Connection"
                    }
                }

  function LoadNewCFGAndRebootSwitch{

   
    param (

	    [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [String]$SwitchIp,
		
        [Parameter(Mandatory=$False)]
	    [ValidateNotNullOrEmpty()]
        [PSCredential]$Switch_cred,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String] $switch_cfg_file_path
       
  )

        $switch_cfg_file= Split-Path -path $switch_cfg_file_path -Leaf

        $switch_connection = New-SwitchSession -SwitchIp $SwitchIp -Switch_cred $Switch_cred
        $sessionID = $switch_connection.SessionId
        Invoke-SSHCommand -SessionId $sessionID -Command "startup saved-configuration flash:/$switch_cfg_file"
        try{
        Invoke-SSHCommand -SessionId $sessionID -Command "reboot`nN`Y"  -ErrorAction Continue
        }
        Catch{
        Write-Host $_
        }
        DO { $Ping= Test-Connection  $SwitchIp -quiet; write-host " Trying to Establsh the connection with $SwitchIp  "} Until ($ping -eq $true) 

        Write-Host " $SwitchIp Switch is online"

        $result = Invoke-SSHCommand -SessionId $sessionID -Command "system-view`ndisplay current-configuration"
        $FW = ($result.Output| Select-String -Pattern "FW Version:" ).ToString()
        $FWversio_oneSwichn= $FW.Split("/")[0].Split(":")[1]

        Return $FWversio_oneSwichn

  }

     $Switch_cred = Get-Credential

      #CAlculete ToR1 and ToR2 switch IPS from the given switch IP BMC IP

     $SwitchIPaddressMap= CalulateSwitchIPs -BmcSwitchIP $BmcSwitchIP
      
     $BMCSwitchIP =$SwitchIPaddressMap.BMCIP
     $ToROneIP=$SwitchIPaddressMap.Tor1IP
     $ToRTwoIP=$SwitchIPaddressMap.Tor2IP

     $SwitchArray = @($ToRTwoIP,$BMCSwitchIP,$ToROneIP)

        Foreach ($EacSwitch in $SwitchArray)

        {

          $ExistingFWversion = SwitchSSHConnectvityAndExistingFW -SwitchIp $EacSwitch -Switch_cred $Switch_cred 
          Write-Host " The $EacSwitch succesfully connected and  $ExistingFWversion on the switch "

        }
 
     #Find FW version from the form the latest Switch CFG files
      $DesiredFWVersion= TargetFWVersionInCFGfile -SwitchFilesFolderpath $SwitchFilesFolderpath
     
     # Modify the input files by appening Date

     $PreProssedFilesMap= FilePreProcess -SwitchFilesFolderpath $SwitchFilesFolderpath

     # Identify the Switch Make

     $SwitchMake= IndentifySwitchMake -SwitchFilesFolderpath $SwitchFilesFolderpath 

     Write-Host "  The Switch is $SwitchMake Make"

     # Map the SwitchConfigs With the respecive IPs


     $confirmation = Read-Host " switches will be falshed with $DesiredFWVersion version Are you Sure You Want To Proceed: Enter Y"
     if ($confirmation -eq 'Y') {
   
     # proceed

     $ConfigFilesAndIPaddressMap=  [ordered]@{
     $PreProssedFilesMap.TOR2=$SwitchIPaddressMap.Tor2IP
     $PreProssedFilesMap.BMC =$SwitchIPaddressMap.BMCIP
     $PreProssedFilesMap.TOR1=$SwitchIPaddressMap.Tor1IP
     }

     $ConfigFilesAndIPaddressMap.GetEnumerator() | ForEach-Object {"$($_.Key) - $($_.Value)"

         $switch_config_file_path=$_.Key
         $SwitchIp = $_.Value

     Copy-fileToSwitch -SwitchIp $SwitchIp -Switch_cred $Switch_cred -switch_cfg_file_path  $switch_config_file_path 

     }

 }     

    else {
    Write-Host ' Terminating teh Switch flashing task as per your Input'
     
     }

     $ConfigFilesAndIPaddressMap.GetEnumerator() | ForEach-Object {"$($_.Key) - $($_.Value)"

         $switch_config_file_path=$_.Key
         $SwitchIp = $_.Value

    $NewonFWonSwitch = LoadNewCFGAndRebootSwitch -SwitchIp $SwitchIp -Switch_cred $Switch_cred -switch_cfg_file_path $switch_config_file_path

      Write-Host " The $SwitchIp Switch succesfully flashed with DESIRED FW is $NewonFWonSwitch "

     }
       #  $Tor2SwCFG=$PreProssedFilesMap.TOR2

       #   

       #   Write-Host " the $ToRTwoIP succesfully DESIRED FW is $NewonFWonSwitch  "
        



