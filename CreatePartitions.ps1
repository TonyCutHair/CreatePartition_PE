<#
========================================================================
使用情景: 三个可选变量, 强制定义-win.
1. 不指定Win分区					CreatePartitions.exe -Win 0
2. 指定Win分区百分比, 			CreatePartitions.exe -Win 30   -->占用剩余空间(除去EFI,MSR,和HP_RECOVERY)的百分比, 不是全盘比例.
3. Win和Data均分3分				CreatePartitions.exe -Win 0 -Windata 2 -Recovery xx			-->此处Windata为1~10之间.
4. 指定Win分区,剩余Data			CreatePartitions.exe -Win 100 -Recovery xx		-->此处Windata必须为 1.
5. 指定Win分区,其余均分				CreatePartitions.exe -Win 100 -Windata 2 -Recovery xx		-->此处Windata为 2~10之间.
6. 指定Win分区,Data分区大小			CreatePartitions.exe -Win 100 -Windata 200 -Recovery xx		--> 分3个区,win,data,rest of disk.

Recovery 默认为0则无HP_RECOVERY分区.

6. Datadisk 指定第一分区大小.		DataDisk=100
7. Datadisk 均分.				DataDisk=3
8. Datadisk 分一个区				DataDisk=1,默认值
========================================================================
.SYNOPSIS
	Create specified partition scheme on local disk(s) in WinPE.
	Won't clean portable media or virtual disk(s).

.DESCRIPTION
	Create specified partition scheme on local disk(s) in WinPE.
	Won't clean portable media or virtual disk(s).
	The rule is to install windows on first small SSD.
	Default partition EFI is 512MB, MSR is 128MB.

.PARAMETER Win
	[UInt32]
    Mandatory parameter to specified windows partition size.
	[0] 	will create Windows partition using rest of disk space.
	[100]	will create 100GB Windows partition and a DATA partition using rest of disk space.

.PARAMETER WinData
	[UInt32]
    Mandatory parameter, specifies number of Data partition on the Windows disk.
	Must specified -Win
	if $Win = 0
	[0]		windows using rest of disk
	[1] 	Create Windows and DATA partition using 50% of disk.
	[3]		Create Windows and DATA partitionS using 1/4 of disk. total 4 primary partitions
	if $Win != 0
	[1] 	Create DATA using rest of disk space.
	[3]		Create 3 data partitions using 1/3 of rest of disk space, total 4 primary partitions.
	
	[100] 	Specified a number larger than 100, create 2 data partitions on Windows disk.
			one is 100GB, the other one using rest of disk space.

.PARAMETER Recovery
	[UInt32]
    Mandatory parameter, specifies HP_RECOVERY partition size.
	[0] 	no recovery partition is created.
	[20]	will create 20GB HP_RECOVERY partition on the same disk of Windows partition.

.PARAMETER DataDisk
	[UInt32]
    Mandatory parameter, specifies other disk(s) partition scheme on multi disk(s) unit.
	[1] 	Default value, to create 1 partition with 100% disk space.
	[2~10]	set a number between 2 to 10, will create everage size partitions on every data disk(s).
	[100] 	set a number larger than 100, will create 2 partitions, one 100GB and the other one using rest of disk space.

.EXAMPLE
	CrePartGB -Win 0 -Windata 0 -Recovery 0
	Windows Disk:
		EFI:512MB,
		MSR:128MB
		Windows:Rest Of Disk
    
.EXAMPLE
    CrePartGB -Win 0 -Windata 0 -Recovery 20 -DataDisk 1
	Windows Disk:
		EFI:512MB
		MSR:128MB
		Windows:Rest Of Disk
		HP_RECOVERY:20GB
	Data Disk(s):
		DATADISK:100% of disk

.EXAMPLE
	CrePartGB -Win 100 -WinData 1 -Recovery 20 -DataDisk 3
	Windows Disk:
		EFI:512MB
		MSR:128MB
		Windows:Rest Of Disk
		HP_RECOVERY:20GB
	Data Disk(s):
		DATADISK1:1/3 of disk
		DATADISK2:1/3 of disk
		DATADISK3:1/3 of disk
    
.EXAMPLE
	CrePartGB -Win 0 -WinData 2 -Recovery 20 -DataDisk 300
	Windows Disk:
		EFI:512MB
		MSR:128MB
		Windows:1/3 of Rest Of Disk
		DATA: 1/3 of Rest Of Disk
		DATA1:1/3 of Rest Of Disk
		HP_RECOVERY:20GB
	Data Disk(s):
		DATADISK1:300GB
		DATADISK2:Rest of disk

.EXAMPLE
    CrePartGB -Win 100 -WinData 2 -Recovery 20 -DataDisk 3
	Windows Disk:
		EFI:512MB
		MSR:128MB
		Windows:100GB
		DATA: 1/2 of Rest Of Disk
		DATA1:1/2 of Rest Of Disk
		HP_RECOVERY:20GB
	Data Disk(s):
		DATADISK1:1/3 of disk
		DATADISK2:1/3 of disk
		DATADISK3:1/3 of disk
   
.INPUTS
    CreatePartitions -Win [Uint32] [-WinData [UInt32]] [-Recovery [Uint32]] [-DataDisk [Uint32]]

.OUTPUTS
    Generate a Createpartition.log in current directory.

.NOTES
	1. 2021/08/30  initial version 1.0.1.1
	2. 2021/09/13  Lines 375-488, update script, Windows partition support percent of free space.
				   Lines 261-270,721-730, support only have HDD.
	3. 2021/09/14  Lines 200-208, update -win 0 -windata 100 warning msg.

    Author: zhang, xidong
    Email: xidong.zhang@hp.om
    Copyright: All rights reserved @ 2021 HP Inc. 
#>

Param ([Parameter(Mandatory = $false, Position = 0)]
	[UInt64]$Win = 9999,
	[Parameter(Mandatory = $false)]
	[UInt32]$WinData = 0,
	[Parameter(Mandatory = $false)]
	[UInt32]$DataDisk = 1,
	[Parameter(Mandatory = $false)]
	[UInt64]$Recovery = 0
)
# help section started.
if ($Win -eq "9999")
{
	Write-Host "------------------------------------------------------------------"
	Write-Host " CreatePartitions.exe	v2.1.0.0 (WinPE)"
	Write-Host "                     @2021 HP China Inc. All Rights Reserved."
	Write-Host "                                Support: xidong.zhang@hp.com"
	Write-Host "------------------------------------------------------------------"
	Write-Host "CreatePartitions.exe -Win [*] [-WinData [*]] [-DataDisk [*]] -Recovery [[*]]"
	Write-Host ""
	Write-Host "[UInt32]  Win               Mandatory parameter, to specified windows partition size."
	Write-Host "        [0]                     Will create Windows partition using rest of disk space."
	Write-Host "        [10 to 100]             Will create specified percent(%) of rest of disk space."
	Write-Host "        [Greater than 100]      Will create specified size(GB) Windows partition and "
	Write-Host "                                a DATA partition using rest of disk space."
	Write-Host ""
	Write-Host "[UInt32] WinData            Optional parameter, Must specified -Win, specifies number"
	Write-Host "                            of DATA partition on the Windows disk."
	Write-Host "    if Win = 0"
	Write-Host "        [0] 	                Create Windows using rest of disk."
	Write-Host "        [Integer 1:10] 	        Create Windows and DATA partition using 1/[2:11] of "
	Write-Host "                                disk.total 2~11 partitions."
	Write-Host "    if Win != 0"
	Write-Host "        [1]                     Create DATA using rest of disk space."
	Write-Host "        [Integer 2:10]          Create 2~10 DATA partitions using 1/[2:10] of rest of disk space."
	Write-Host "        [Greater than 80]       Create 2 DATA partitions, one is specified size, "
	Write-Host "                                the other is rest of disk space."
	Write-Host ""
	Write-Host "[UInt32] Recovery           Optional parameter, specifies HP_RECOVERY partition size."
	Write-Host "        [0] 	                No recovery partition is created."
	Write-Host "        [20]	                Will create 20GB HP_RECOVERY partition on the same "
	Write-Host "                                disk of Windows partition."
	Write-Host ""
	Write-Host "[UInt32] DataDisk           Optional parameter, specifies other disk(s) partition scheme "
	Write-Host "                            on multi disk(s) unit."
	Write-Host ""
	Write-Host "        [1] 	                Default value, to create 1 partition with 100% disk space."
	Write-Host "        [2:10]	                Set a number between 2 to 10, will create everage size "
	Write-Host "                                partitions on every data disk(s)."
	Write-Host "        [Greater than 100]       Set a number larger than 80, will create 2 partitions, "
	Write-Host "                                one 80GB and the other one using rest of disk space."
	Write-Host "------------------------------------------------------------------------------------------"
	return
}
# help section end.

# warning section started.
if ($Win -ne "0" -and $WinData -eq "0")
{
	$WinData = 1
}

if ($Win -gt 0 -and $Win -lt 10)
{
	Write-Host ""
	Write-Host "[-Win]"
	Write-Host "Suggestion: Windows Partition Size Greater Than 100GB."
	Write-Host "Or"
	Write-Host "Specified 10~100 percent(%) Of Disk as Windows Partition. "
	Write-Host ""
	return
}

if ($Win -eq 0 -and $WinData -gt 10)
{
	Write-Host ""
	Write-Host "[-WinData]"
	Write-Host "Suggestion: When -Win set to 0, -WinData will create specified average partitions on disk"
	Write-Host "            Set a number between 1 to 10 to create 2 to 11 average partitions(include Windows partition)."
	Write-Host ""
	return
}

if ($WinData -gt 5 -and $WinData -lt 100)
{
	Write-Host ""
	Write-Host "[-WinData]"
	Write-Host "Suggestion: set 1~5 to create single or average size partition(s)."
	Write-Host "            set greater than 100 to create 2 partitions, one specified size, one use rest of disk space."
	Write-Host ""
	return
}

if ($Recovery -gt 40)
{
	Write-Host ""
	Write-Host "[-Recovery]"
	Write-Host "Suggestion: set Recovery partition size base on your image size."
	Write-Host ""
	return
}

if ($DataDisk -gt 10 -and $DataDisk -lt 100)
{
	Write-Host ""
	Write-Host "[-DiskData]"
	Write-Host "Suggestion: set 1~10 to create single or average size partition(s)."
	Write-Host "            set greater than 100 to create 2 partitions, one specified size, one use rest of disk space."
	Write-Host ""
	return
}
# warning section end

# CreateWindowsPartition section started
Function CreateWindowsPartition
{
	# System Partition - "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
	# Microsoft Reserved - "{e3c9e316-0b5c-4db8-817d-f92df00215ae}"
	# Basic data - "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
	# Microsoft Recovery - "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}"
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $True)]
		[UInt32]$DiskIndex,
		[Parameter(Mandatory = $True)]
		[UInt64]$Win,
		[Parameter(Mandatory = $True)]
		[UInt32]$WinData,
		[Parameter(Mandatory = $True)]
		[UInt64]$Recovery
		# Unit : GB
	)
	if ($SSD_Count.Count -eq "0")
	{
		$DiskIndex = $HDD_Results[0].DeviceID
		$DiskSize = $HDD_Results[0].Size
	}
	else
	{
		$DiskIndex = $SSD_Results[0].DeviceID
		$DiskSize = $SSD_Results[0].Size
	}
	
	[Uint32]$DiskSizeGB = $DiskSize /(1024*1024*1024)
	"Windows Installed on Disk" + $DiskIndex | Out-File -FilePath .\CreatePartition.log -Append
	"Total Disk Size" + $DiskSizeGB | Out-File -FilePath .\CreatePartition.log -Append
	
	Write-Host "-Cleanning Disk (" $DiskIndex ")."
	"-Cleanning Disk (" + $DiskIndex + ")." | Out-File -FilePath .\CreatePartition.log -Append
	$Null = Clear-Disk -Number $DiskIndex -RemoveData -RemoveOEM -Confirm:$false
	$Null = Initialize-Disk -Number $DiskIndex -PartitionStyle GPT
	
	Write-Host "---Creating Partition EFI On Disk (" $DiskIndex ")."
	"---Creating Partition EFI On Disk (" + $DiskIndex + ")." | Out-File -FilePath .\CreatePartition.log -Append
	$Null = New-Partition -DiskNumber $DiskIndex -Size 512MB -DriveLetter S -GptType "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}"
	$Null = Format-Volume -DriveLetter S -FileSystem FAT32 -NewFileSystemLabel "SYSTEM" -Force
	
	Write-Host "---Creating Partition MSR On Disk (" $DiskIndex ")."
	"---Creating Partition MSR On Disk (" + $DiskIndex + ")." | Out-File -FilePath .\CreatePartition.log -Append
	$Null = New-Partition -DiskNumber $DiskIndex -Size 128MB -GptType "{e3c9e316-0b5c-4db8-817d-f92df00215ae}"
	
	if ($Win -eq "0") # rest of disk is windows + data
	{
		if ($Recovery -ne "0") # has recovery partition
		{
			if ($WinData -eq "0") # win + recovery, create windows + recovery
			{
				$WinActualSize = $DiskSize - (642 + $Recovery * 1024) * 1024 * 1024
				$WinActualSizeGB = $WinActualSize / 1024 / 1024 / 1024
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
			}
			else # average win + data(s) + recovery, create windows + create data(s) + recovery
			{
				$ActualSize = ((get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024) / ($WinData + 1) # byte
				[UInt32]$ActualSizeMB = $ActualSize / 1024 / 1024 # Int MB
				$Null = New-Partition -DiskNumber $DiskIndex -Size $ActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$ActualSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 0; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
			}
		}
		else # has no recovery partition
		{
			if ($WinData -eq "0") # win part, create Windows
			{
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -UseMaximumSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
			}
			elseif ($WinData -eq "1") # average win + data(s), create win + data via diskpart.
			{
				$ActualSize = ((get-disk -Number $DiskIndex).Size - 642 * 1024 * 1024 ) / 2 # byte
				[UInt32]$ActualSizeMB = $ActualSize / 1024 / 1024 # Int MB
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$ActualSizeMB
format fs=NTFS quick label="Windows"
assign letter="W"
create partition primary
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
			}
			else # average win + data(s), create win + (create data(s) - 1) + create last data partition.
			{
				$ActualSize = ((get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024) / ($WinData + 1) # byte
				[UInt32]$ActualSizeMB = $ActualSize / 1024 / 1024 # Int MB
				$Null = New-Partition -DiskNumber $DiskIndex -Size $ActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$ActualSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 1; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
				
				$CreateLastWinDataScript = @"
select disk $DiskIndex
create partition primary
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateLastWinDataScript -FilePath "X:\Windows\Temp\CreateLastWinDataScript.txt" -Force -Encoding ASCII
				Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateLastWinDataScript.txt" -NoNewWindow -Wait -PassThru
			}
		}
	}
	elseif ($Win -gt 10 -and $Win -lt 100) # create Windows partition using percent(%) of rest of disk space.
	{
		if ($Recovery -ne "0") # has recovery partition
		{
			if ($WinData -eq "1") # win + data + recovery
			{
				
				[UInt64]$WinActualSize =( (get-disk -Number $DiskIndex).Size - (642 +  $Recovery * 1024) * 1024 * 1024 ) * ( $Win / 100 )
				[UInt64]$DataSize = (get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024 - $WinActualSize
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				Write-Host "---Creating DATA Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $DataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "DATA" -Force
			}
			elseif (($WinData -gt "1") -and ($WinData -lt "9")) # win + average data(s) + recovery
			{
				
				[UInt64]$WinActualSize = ((get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024) * ($Win / 100)
				[UInt64]$DataSize = ((get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024 - $WinActualSize ) / $WinData
				
				[UInt32]$DataSizeMB = $DataSize /1024 /1024 #MB
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$DataSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 0; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
			}
			else # windata > 10, win + windata + rest of disk + recovery
			{
				[UInt64]$WinActualSize = ((get-disk -Number $DiskIndex).Size - (642 + $Recovery * 1024) * 1024 * 1024) * ($Win / 100)
				$WinDataSize = $WinData * 1024 * 1024 * 1024
				$DataSize2 = (get-disk -Number $DiskIndex).Size - (642 + ($WinData + $Recovery) * 1024) * 1024 * 1024 - $WinActualSize
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinDataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $DataSize2 -DriveLetter M -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter M -FileSystem NTFS -Force
			}
		}
		else # has no recovery partition.
		{
			if ($WinData -eq "1") # win + data
			{
				[UInt64]$WinActualSize = ((get-disk -Number $DiskIndex).Size - (642 * 1024 * 1024)) * ($Win / 100)

				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				Write-Host "---Creating DATA Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -UseMaximumSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "DATA" -Force
			}
			elseif (($WinData -gt "1") -and ($WinData -lt "9")) # win + average data(s) 
			{
				[UInt64]$WinActualSize = ((get-disk -Number $DiskIndex).Size - (642 * 1024 * 1024)) * ($Win / 100)
				[UInt64]$DataSize = ((get-disk -Number $DiskIndex).Size - 642 * 1024 * 1024 - $WinActualSize) / $WinData

				[UInt32]$DataSizeMB = $DataSize /1024 /1024 #MB
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$DataSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 1; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
				$CreateLastWinDataScript = @"
select disk $DiskIndex
create partition primary
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateLastWinDataScript -FilePath "X:\Windows\Temp\CreateLastWinDataScript.txt" -Force -Encoding ASCII
				Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateLastWinDataScript.txt" -NoNewWindow -Wait -PassThru
			}
			else # windata > 10, win + windata + rest of disk
			{
				[UInt64]$WinActualSize = ((get-disk -Number $DiskIndex).Size - (642 * 1024 * 1024)) * ($Win / 100)
				$WinDataSize = $WinData * 1024 * 1024 * 1024
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinDataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -Force
				$Null = New-Partition -DiskNumber $DiskIndex -UseMaximumSize -DriveLetter M -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter M -FileSystem NTFS -Force
			}
		}
	}
	else # specified windows partition size larger than 100.
	{
		if ($Recovery -ne "0") # has recovery partition
		{
			if ($WinData -eq "1") # win + data + recovery
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				$DataSize = (get-disk -Number $DiskIndex).Size - (642 + ($Win + $Recovery) * 1024) * 1024 * 1024
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				Write-Host "---Creating DATA Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $DataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "DATA" -Force
			}
			elseif (($WinData -gt "1") -and ($WinData -lt "9")) # win + average data(s) + recovery
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				$DataSize = ((get-disk -Number $DiskIndex).Size - (642 + ($Win + $Recovery) * 1024) * 1024 * 1024) / $WinData
				[UInt32]$DataSizeMB = $DataSize /1024 /1024 #MB
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$DataSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 0; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
			}
			else # windata > 10, win + windata + rest of disk + recovery
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				$WinDataSize = $WinData * 1024 * 1024 * 1024
				$DataSize2 = (get-disk -Number $DiskIndex).Size - (642 + ($Win + $WinData + $Recovery) * 1024) * 1024 * 1024
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinDataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS  -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $DataSize2 -DriveLetter M -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter M -FileSystem NTFS  -Force
			}
		}
		else # has no recovery partition.
		{
			if ($WinData -eq "1") # win + data
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				Write-Host "---Creating DATA Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -UseMaximumSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -NewFileSystemLabel "DATA" -Force
			}
			elseif (($WinData -gt "1") -and ($WinData -lt "9" )) # win + average data(s) 
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				$DataSize = ((get-disk -Number $DiskIndex).Size - (642 + $Win * 1024) * 1024 * 1024) / $WinData
				[UInt32]$DataSizeMB = $DataSize /1024 /1024 #MB
				
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				
				$CreateWinDataScript = @"
select disk $DiskIndex
create partition primary size=$DataSizeMB
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateWinDataScript -FilePath "X:\Windows\Temp\CreateWinDataScript.txt" -Force -Encoding ASCII
				for ($x = 1; $x -lt $WinData; $x = $x + 1)
				{
					Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateWinDataScript.txt" -NoNewWindow -Wait -PassThru
				}
				$CreateLastWinDataScript = @"
select disk $DiskIndex
create partition primary
format fs=NTFS quick
assign
"@
				Out-File -InputObject $CreateLastWinDataScript -FilePath "X:\Windows\Temp\CreateLastWinDataScript.txt" -Force -Encoding ASCII
				Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateLastWinDataScript.txt" -NoNewWindow -Wait -PassThru
			}
			else # windata > 10, win + windata + rest of disk
			{
				$WinActualSize = $Win * 1024 * 1024 * 1024
				$WinDataSize = $WinData * 1024 * 1024 * 1024
				Write-Host "---Creating Windows Partition On Disk (" $DiskIndex ")."
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinActualSize -DriveLetter W -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
				$Null = New-Partition -DiskNumber $DiskIndex -Size $WinDataSize -DriveLetter T -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter T -FileSystem NTFS -Force
				$Null = New-Partition -DiskNumber $DiskIndex -UseMaximumSize -DriveLetter M -GptType "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}"
				$Null = Format-Volume -DriveLetter M -FileSystem NTFS -Force
			}
		}
	}
	
	if ($Recovery -ne "0")
	{
		# create recovery partition.
		Write-Host "---Creating HP_RECOVERY Partition On Disk (" $DiskIndex ")."
		$CreateRecoveryPartition = @"
select disk $DiskIndex
create partition primary ID=de94bba4-06d1-4d40-a16a-bfd50179d6ac
format quick fs=ntfs label="HP_RECOVERY"
gpt attributes=0x8000000000000001
assign letter="R" 
"@
		Out-File -InputObject $CreateRecoveryPartition -FilePath "X:\Windows\Temp\CreateRecoveryPartitionScript.txt" -Force -Encoding ASCII
		Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\CreateRecoveryPartitionScript.txt" -NoNewWindow -Wait -PassThru
	}
	
}
# CreateWindowsPartition section end

# CreateDataPartition section started.
Function CreateDataPartition
{
	param (
		[Parameter(Mandatory = $True)]
		[UInt32]$DiskNum,
		[Parameter(Mandatory = $True)]
		[UInt32]$DataDisk,
		[Parameter(Mandatory = $True)]
		[String]$Type
	)
	
	# get disk index and get disk size by Byte.
	if ($Type -eq "HDD")
	{
		$DiskDataSize = $HDD_Results[$DiskNum].Size
		$DiskDataNum = $HDD_Results[$DiskNum].DeviceID
	}
	else
	{
		$DiskDataSize = $SSD_Results[$DiskNum].Size
		$DiskDataNum = $SSD_Results[$DiskNum].DeviceID
	}
	
	Write-Host "---Creating Data Partitions On Other Disks " $DiskDataNum
	
	Clear-Disk -Number $DiskDataNum -RemoveData -RemoveOEM -Confirm:$False
	Initialize-Disk -Number $DiskDataNum -PartitionStyle GPT
	
	if (($DataDisk -eq "1") -or ($DataDisk -eq "0") ) # create only 1 partition for data disk(s)
	{
		$DataPartitionScript= @"
Select Disk $DiskDataNum

Create Partition Primary
Format FS=NTFS quick
assign
exit
"@
		Out-File -InputObject $DataPartitionScript -FilePath "X:\Windows\Temp\DataDiskScript.txt" -Force -Encoding ASCII
		Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\DataDiskScript.txt" -NoNewWindow -Wait -PassThru
	}
	elseif ($DataDisk -gt "10" ) # create 2 partitions, 1 is specified size, 1 is rest of disk.
	{
		$DataDisk = $DataDisk * 1024 #MB
		$DataPartitionScript = @"
Select Disk $DiskDataNum

Create Partition Primary Size=$DataDisk
Format FS=NTFS quick
assign
Create Partition Primary
Format FS=NTFS quick
assign
exit
"@
		Out-File -InputObject $DataPartitionScript -FilePath "X:\Windows\Temp\DataDiskScript.txt" -Force -Encoding ASCII
		Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\DataDiskScript.txt" -NoNewWindow -Wait -PassThru
	}
	else
	{
		# use specified size for all except last partition.
		[uint32]$EveryDataPartitionSize = $DiskDataSize / $DataDisk / 1024 / 1024 #MB
		$DataPartitionScript = @"
Select Disk $DiskDataNum

Create Partition Primary Size=$EveryDataPartitionSize
Format FS=NTFS quick
assign
exit
"@
		Out-File -InputObject $DataPartitionScript -FilePath "X:\Windows\Temp\DataDiskScript.txt" -Force -Encoding ASCII
		$LastDataPartitionScript = @"
Select Disk $DiskDataNum

Create Partition Primary
Format FS=NTFS quick
assign
exit
"@
		Out-File -InputObject $LastDataPartitionScript -FilePath "X:\Windows\Temp\LastDataDiskScript.txt" -Force -Encoding ASCII
		
		for ($x = 1; $x -lt $DataDisk; $x = $x + 1) 
		{
			Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\DataDiskScript.txt" -NoNewWindow -Wait -PassThru
		}
		# create last partition on data disk.
		Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\LastDataDiskScript.txt" -NoNewWindow -Wait -PassThru
	}
}
# CreateDataPartition section end.

# Main process started.
"Main program started..." | Out-File -FilePath .\CreatePartition.log
# Get disks informations.
$Disks = Get-PhysicalDisk | Where-Object { $_.BusType -notlike "USB" -and $_.BusType -notlike "*Virtual*" }
#sort disks by GBU windows installation rule.
$SSD_Results = $Disks | Where-Object { $_.MediaType -like "SSD" } | Sort-Object -Property @{ expression = "Size"; Descending = $false }, @{ expression = "DeviceID"; Descending = $false }
$HDD_Results = $Disks | Where-Object { $_.MediaType -like "HDD" } | Sort-Object -Property @{ expression = "Size"; Descending = $false }, @{ expression = "DeviceID"; Descending = $false }
$SSD_Count = $SSD_Results | Measure-Object
$HDD_Count = $HDD_Results | Measure-Object

Write-Host "Partition is Creating..."
"Partition is Creating..." | Out-File -FilePath .\CreatePartition.log -Append

if ($SSD_Count.Count -eq "0")
{
	#Scenario 1： only have HDD, follow GBU rule to install win, format others.
	CreateWindowsPartition -DiskIndex 0 -Win $Win -Recovery $Recovery -WinData $WinData
	# format HDD except windows disk.
	for ($x = 1; $x -lt $HDD_Count.Count; $x = $x + 1)
	{
		CreateDataPartition -DiskNum $x -DataDisk $DataDisk -Type HDD
	}
}
elseif ($SSD_Count.Count -eq "1")
{
	#Scenario 2： only have 1 SSD. Create Win on SSD, Format others.
	CreateWindowsPartition -DiskIndex 0 -Win $Win -Recovery $Recovery -WinData $WinData
	if ($HDD_Count.Count -ne "0")
	{
		for ($x = 0; $x -lt ($HDD_Count.Count); $x = $x + 1)
		{
			CreateDataPartition -DiskNum $x -DataDisk $DataDisk -Type HDD
		}
	}
}
else
{
	#Scenario 3： have multi SSD, follow GBU rule to install win, format others.
	CreateWindowsPartition -DiskIndex 0 -Win $Win -Recovery $Recovery -WinData $WinData
	# format SSD except windows disk.
	for ($x = 1; $x -lt $SSD_Count.Count; $x = $x + 1)
	{
		CreateDataPartition -DiskNum $x -DataDisk $DataDisk -Type SSD
	}
	# format HDD.
	if ($HDD_Count.Count -ne "0")
	{
		for ($x = 0; $x -lt ($HDD_Count.Count); $x = $x + 1)
		{
			CreateDataPartition -DiskNum $x -DataDisk $DataDisk -Type HDD
		}
	}
}
# Main process end.

# generate log file.
Write-Host "Complete Partition Creating..."
"The Disk(s) Information Is:" | Out-File -FilePath .\CreatePartition.log -Append
$SSD_Results | Out-File -FilePath .\CreatePartition.log -Append
$HDD_Results | Out-File -FilePath .\CreatePartition.log -Append
"#################################" | Out-File -FilePath .\CreatePartition.log -Append
"The Partitions Information Is:" | Out-File -FilePath .\CreatePartition.log -Append
Get-Partition | Format-Table DiskNumber, PartitionNumber, DriveLetter, Size, Type, IsHidden | Out-File -FilePath .\CreatePartition.log -Append
"#################################" | Out-File -FilePath .\CreatePartition.log -Append
"The Volumes Information Is:" | Out-File -FilePath .\CreatePartition.log -Append
Get-Volume | Out-File -FilePath .\CreatePartition.log -Append
"End Partition Creation..." | Out-File -FilePath .\CreatePartition.log -Append
# log files end.
