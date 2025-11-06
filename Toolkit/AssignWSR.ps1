echo "--------------------------------"
echo "HP Recovery Solution V1.1.0.0"
echo "HP Inc, All Rights Reseverd"
echo "support: xidong.zhang@hp.com"
echo "-------------------------------"

# 20211213 exclude optane ssd case. disk must larger than 100GB. update only HDD case.
$Disks = Get-PhysicalDisk | Where-Object { $_.BusType -notlike "USB" -and $_.BusType -notlike "*Virtual*" -and $_.Size -gt 80GB}
#分别获取固态和机械硬盘信息, 先按大小升序排序,若大小相同,按deviceID排序. 此时系统盘应为$SSD_Results[0]或$HDD_Results[0]
$SSD_Results = $Disks | Where-Object { $_.MediaType -like "SSD" } | Sort-Object -Property @{ expression = "Size"; Descending = $false }, @{ expression = "DeviceID"; Descending = $false }
$HDD_Results = $Disks | Where-Object { $_.MediaType -like "HDD" } | Sort-Object -Property @{ expression = "Size"; Descending = $false }, @{ expression = "DeviceID"; Descending = $false }

if ($null -ne $SSD_Results)
	{
	Get-Partition -DiskNumber $SSD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" } | Set-Partition -NewDriveLetter R
	Get-Partition -DiskNumber $SSD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Set-Partition -NewDriveLetter S
}
else
{
	Get-Partition -DiskNumber $HDD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" } | Set-Partition -NewDriveLetter R
	Get-Partition -DiskNumber $HDD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}" } | Set-Partition -NewDriveLetter S
}
$Partitions = Get-Partition
$FoundWin = "N"
foreach ($item in $Partitions)
{
	$testpath = -join ($item.DriveLetter, ":\Windows\System32")
	$winpart = Test-Path -Path $testpath
	if ($winpart -eq "True")
	{
		Set-Partition -DriveLetter $item.DriveLetter -NewDriveLetter W
		$WindowsPartitionInfo = Get-Partition -DriveLetter W
		$FoundWin = "Y"
		#Format-Volume -DriveLetter W -FileSystem NTFS -NewFileSystemLabel "Windows" -Force
	}
}

if ($FoundWin -eq "N") # no \Windows\System32 is found. use 1st basic par
{
	if ($null -ne $SSD_Results)
	{
		$BasicPartitions = Get-Partition -DiskNumber $SSD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" }
		$WDisk = $SSD_Results[0].DeviceID
	}
	else
	{
		$BasicPartitions = Get-Partition -DiskNumber $HDD_Results[0].DeviceID | Where-Object { $_.GptType -eq "{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}" }
		$WDisk = $HDD_Results[0].DeviceID
	}
	
	$WindowsPartitionInfo = $BasicPartitions[0]
	Set-Partition -DriveLetter $WindowsPartitionInfo.DriveLetter -NewDriveLetter W
}

$FormatWindowsPartitionScript= @"
select volume W
format fs=NTFS quick label="Windows" override
exit
"@
Out-File -InputObject $FormatWindowsPartitionScript -FilePath "X:\Windows\Temp\FormatWindowsPartition.txt" -Force -Encoding ASCII
# Start-Process -FilePath diskpart.exe -ArgumentList "/s X:\Windows\Temp\FormatWindowsPartition.txt" -NoNewWindow -Wait -PassThru

# generate log file.
"The Disk(s) Information Is:" | Out-File -FilePath X:\Windows\Temp\assignvol.log
Get-PhysicalDisk | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
$SSD_Results | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
$HDD_Results | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
"#################################" | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
"The Partitions Information Is:" | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
Get-Partition | Format-Table DiskNumber, PartitionNumber, DriveLetter, Size, Type, IsHidden | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
"#################################" | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
"The Volumes Information Is:" | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
Get-Volume | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append
"End Partition Creation..." | Out-File -FilePath X:\Windows\Temp\assignvol.log -Append