#rename PC name to XL-%SN%
$StrSN = (Get-WmiObject Win32_BIOS).serialnumber.trim()
$StrComputerName = "XL-" + $StrSN
(Get-WmiObject -Class Win32_ComputerSystem).Rename($StrComputerName)
