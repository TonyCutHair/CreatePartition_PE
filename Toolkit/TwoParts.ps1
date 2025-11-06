$WSize=Get-PartitionSupportedSize -DriveLetter W
$Dinfo=get-partition -DriveLetter W
$HalfSize=$WSize.sizemax / 2

Resize-Partition -DriveLetter W -Size $HalfSize
New-Partition -DiskNumber $Dinfo.DiskNumber -UseMaximumSize -DriveLetter T
Format-Volume -DriveLetter T -FileSystem NTFS

