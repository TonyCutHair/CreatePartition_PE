#define log path
$sharedfolder = "\\servicedesk.sf-express.com\Share\software\PST_Collection\osPath\log\remove-admin"

if (Test-Path $sharedfolder)
{
    $log_path = "$sharedfolder\$env:COMPUTERNAME.log"
}
else
{
    $log_path = "$env:windir\remove-admin_$env:COMPUTERNAME.log"
}

function Write-Log ( )
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        #[string]$Path="$log_path",
	    [string]$Path="$env:windir\remove-admin_$env:COMPUTERNAME.log",	
        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",
        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {
        
        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            $NewLogFile = New-Item $Path -Force -ItemType File
            }

        else {
            # Nothing to see here yet.
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        #$FormattedDate = "[$(((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ss"))]: "

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }
        
        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append -Encoding utf8
    }
    End
    {
    }
}

function IsMemberofADGroup ($UserName)
{
    $GroupName = "Allow_Add_to_adminGroup"
    try
    {
        $user_members = (New-Object System.DirectoryServices.DirectorySearcher("(&(objectCategory=User)(samAccountName=$($UserName)))")).FindOne().GetDirectoryEntry().memberOf
        $computer_members = (New-Object System.DirectoryServices.DirectorySearcher("(&(objectCategory=Computer)(Name=$($env:computername)))")).FindOne().GetDirectoryEntry().memberOf
    }
    catch
    {
        #查询AD失败时，默认退出不处理。
        Write-Log -Level Warn $Error[0].Exception.Message
        exit 1;
    }

    #检查结果
    if (($user_members -match $GroupName) -and ($computer_members -match $GroupName))
    {
        return $true
    }
    else
    {
        return $false
    }
}

function Get-AdministratorsGroup-Members
{
    $path = "$env:TEMP\users_raw.temp"
    get-wmiobject -computername $env:COMPUTERNAME -query "select * from win32_groupuser where GroupComponent=""Win32_Group.Domain='$env:COMPUTERNAME',Name='administrators'""" | % {$_.partcomponent} | Out-File -Encoding utf8 $path
    $raw = Get-Content $path
    foreach ($item in $raw)
    {
       (($item.replace("""","")).split("="))[-1]
    }
}

#Returns true if current user in in the administrators group (directly or nested group) and false if not.
function IsCurrentUserAdmin( [String] $UserName )
{
    $obj_group = [ADSI]"WinNT://localhost/Administrators,group"
    $members= @($obj_group.psbase.Invoke("Members")) | foreach{([ADSI]$_).InvokeGet("Name")}
    If ($members -contains $UserName) {
        Return $true
    }
}

function Add-ToLocalAdminstratorsgroup ($UserName)
{
    try 
    {
        Write-Log -Level Info "Adding $UserName to administrators group"
        ([ADSI]"WinNT://$env:COMPUTERNAME/administrators,group").psbase.Invoke("Add",([ADSI]"WinNT://SF.COM/$UserName").path)
        Write-Log -Level Info "Added"
    }
    catch
    {
        Write-Log -Level Warn $Error[0].Exception.Message
    }
}

function Remove
{
    Write-Log -Level Info "Getting members from Administrators group..."
    $osversion = Get-WmiObject win32_operatingsystem | %{$_.Version}
    Write-Log -Level Info "OSVersion: $osversion"
    $user1 = "Domain Admins";$user2 = "PC_LocalAdmin";$user3 = "local-admin";$user4 = "administrator";$user5 = "Admin_Helpdesk"
    $users = Get-AdministratorsGroup-Members
    #除了这5个账号，其它账号均判断是否用户名和本机计算机名都在Allow_Add_to_adminGroup中
    Write-Log -Level Info "Here are the members: $users"
    foreach ($user in $users)
    {
        if (($user -ne $user1) -and ($user -ne $user2) -and ($user -ne $user3) -and ($user -ne $user4) -and ($user -ne $user5))
        {
            if ((IsMemberofADGroup -UserName $user) -eq $false)
            {
                try
                {
                    Write-Log -Level Info "Removing $user from local administrators group"
                    $group = [ADSI]"WinNT://$env:COMPUTERNAME/administrators"
                    $group.remove("WinNT://SF/$user")
                    Write-Log -Level Info "Removed"
                }
                catch
                {
                    Write-Log -Level Warn $Error[0].Exception.Message
                    Write-Log -Level info "Currently, disabled to removing local users!"
                    #移除本地管理员组账号
                    #Write-Log -Level Info "Trying to remove local account $user with another way"
                    #CMD.EXE /C net localgroup administrators test /del | Out-File -Encoding utf8 -Append Write-Log -Level Info "Removing $user from local administrators group"
                }
            }
            else
            {
                Write-Log -Level Info "Account privilege reserved: $user"
            }
        }
    }
    #添加固定账号到本地管理员组中
    if ((IsCurrentUserAdmin -UserName $user1) -ne $true)
    {
        Add-ToLocalAdminstratorsgroup -UserName $user1
    }
    if ((IsCurrentUserAdmin -UserName $user2) -ne $true)
    {
        Add-ToLocalAdminstratorsgroup -UserName $user2
    }
}

#$dc = $($env:LOGONSERVER.Replace('\\',''))
#Write-Log -Level Info "Logon server: $dc"

Remove