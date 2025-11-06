<#
.Synopsis
    Inject Drivers with zip or wim file
.DESCRIPTION
    Inject Drivers with zip or wim file

.EXAMPLE
    
.NOTES
    Created:	 2024-02-28
    Version:	 1.0.1 - Beta Test
    Author - Nguyen Trong Tinh
    Disclaimer:
    This script is provided 'AS IS' with no warranties, confers no rights and 
    is not supported by the author.
.NOTES

#>
# Figure out if we can use the task sequence object
try {
    $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment -ErrorAction Stop
}
catch [System.Exception] {
Write-Log -Message "Unable to create Microsoft.SMS.TSEnvironment object, aborting..."
Break
}


$LogPath = $TSEnv.Value("_SMSTSLogPath") 
$Logfile = "$LogPath\ApplyDrivers.log"
$DeployShare = $TSEnv.Value("DeployRoot")
$DriveLetter = $TSEnv.Value("OSDisk")
# Set ModelName var equal ModelAlias
$ModelName = $TSEnv.Value("ModelAlias")

# Delete any existing logfile if it exists
If (Test-Path $Logfile){Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false}

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated : $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii

}

# Create Drivers folder
Write-Log -Message "Create Drivers folder"
$Drivers = New-Item -Path "$DriveLetter\Drivers" -ItemType Directory -Force

# Unpack drivers
Write-Log -Message "Unpacking ZIP"
Expand-Archive -Path "$DeployShare\Packages\DriverPackages\$ModelName.zip" -DestinationPath "$Drivers" -Force -Verbose

Write-Log -Message "Unpacking WIM"
Expand-WindowsImage -ImagePath "$DeployShare\Packages\DriverPackages\$ModelName.wim" -ApplyPath "$Drivers" -Index 1 -Verbose

# Apply drivers
Write-Log -Message "Apply Drivers Package"
# DISM.exe /Image:$DriveLetter\ /Add-Driver "/Driver:$Drivers\" /Recurse /logpath:"$Logfile"
Write-Log "--------------------------------------"
Write-Log "Starting DISM Driver Install"
#Start the DISM Process, but redirect the output from the console to a logfile which we can read to provide the info
    Write-Log 'Start-Process DISM.EXE -ArgumentList '"/Image:$DriveLetter\ /Add-Driver /Driver:$Drivers\ /recurse"' -PassThru -NoNewWindow -RedirectStandardOutput $Logfile'
    $DISM = Start-Process DISM.EXE -ArgumentList "/Image:$DriveLetter\ /Add-Driver /Driver:$Drivers\ /recurse" -PassThru -NoNewWindow -RedirectStandardOutput $Logfile
    $SameLastLine = $null
    do {  #Continous loop while DISM is running
        Start-Sleep -Milliseconds 300

        #Read in the DISM Logfile   
        $Content = Get-Content -Path $Output -ReadCount 1
        $LastLine = $Content | Select-Object -Last 1
        if ($LastLine){
            if ($SameLastLine -ne $LastLine){ #Only continue if DISM log has changed
                $SameLastLine = $LastLine
                Write-Log $LastLine
                if ($LastLine -match "Searching for driver packages to install..."){
                    #Write-Log $LastLine
                }
                elseif ($LastLine -match "Installing"){
                    #Write-Log $LastLine
                    $Message = $Content | Where-Object {$_ -match "Installing"} | Select-Object -Last 1
                    if ($Message){
                        $ToRemove = $Message.Split(':') | Select-Object -Last 1
                        $Message = $Message.Replace(":$($ToRemove)","")
                        $Message = $Message.Replace($Drivers,"")
                        $Message = $Message.Replace("\offline","")
                        $Total = (($Message.Split("-")[0]).Split("of") | Select-Object -Last 1).replace(" ","")
                        $Counter = ((($Message.Split("-")[0]).Split("of") | Select-Object -First 1).replace(" ","")).replace("Installing","")
                        #Write-Log $Message
                    }
                }
                elseif ($LastLine -match "The operation completed successfully."){
                }
                else{
                }
            }
        }
        
    }
    until (!(Get-Process -Name DISM -ErrorAction SilentlyContinue))

    Write-Log "Dism Step Complete"
    Write-Log "See DISM log for more Details: $Logfile"

else
    {
    Write-Log "Drivers Not Found, exiting out"
    }
Write-Log "--------------------------------------"

# Cleanup drivers source
Write-Log -Message "Clean up drivers folder"
Remove-Item $Drivers -Recurse

# Copy the logs file to C Drive for better reading
Write-Log -Message "Copy the logs file to C:\OSD\ApplyDrivers for better reading"

# Generate logs folder
$Logs = New-Item -Path "$DriveLetter\OSD\ApplyDrivers" -ItemType Directory -Force
Copy-Item -Path $Logfile -Destination $Logs -Recurse