$WSize=Get-PartitionSupportedSize -DriveLetter W
$Dinfo=get-partition -DriveLetter W
$QSize=$WSize.sizemax / 4

Resize-Partition -DriveLetter W -Size $QSize

New-Partition -DiskNumber $Dinfo.DiskNumber -Size $QSize -DriveLetter J
Format-Volume -DriveLetter J -FileSystem NTFS

New-Partition -DiskNumber $Dinfo.DiskNumber -Size $QSize -DriveLetter K
Format-Volume -DriveLetter K -FileSystem NTFS

New-Partition -DiskNumber $Dinfo.DiskNumber -UseMaximumSize -DriveLetter T
Format-Volume -DriveLetter T -FileSystem NTFS

