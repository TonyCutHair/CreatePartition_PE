############ Create by Seven, 2019/04/17
## Rev 100, 2019/04/17 Remove microsoft windows build-in appx 
## Rev 101, 2019/04/25 Remove HP appx in windows build-in.
##			appx list:
##			1. AD2F1837.HPBusinessSlimKeyboard
##			2. AD2F1837.HPJumpStart
## 			3. AD2F1837.HPPCHardwareDiagnosticsWindows
## Rev 102, 2019/04/25 Remove Audio Controls
##			Appx list:
##			1. 22094SynapticsIncorporate.AudioControls
## Rev 103, 2019/04/25 Remove LinkedInforWindows
##			Appx list:
##			1. 7EE7776C.LinkedInforWindows
############

$RemoveApps = @( "Microsoft.BingWeather","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection","Microsoft.MicrosoftStickyNotes",`
                                 "Microsoft.Office.OneNote","Microsoft.People","Microsoft.SkypeApp","Microsoft.windowscommunicationsapps",`
                                 "Microsoft.WindowsMaps","Microsoft.Xbox.TCUI","Microsoft.XboxApp","Microsoft.XboxGameOverlay",`
     		"Microsoft.XboxIdentityProvider","Microsoft.XboxSpeechToTextOverlay","Microsoft.ZuneMusic","Microsoft.ZuneVideo",`
		"Microsoft.Office.Desktop","AD2F1837.HPBusinessSlimKeyboard","AD2F1837.HPJumpStart","AD2F1837.HPPCHardwareDiagnosticsWindows",`
		"AD2F1837.HPPowerManager","AD2F1837.HPSystemInformation","SynapticsIncorporated.SynHPCommercialDApp",`
		"22094SynapticsIncorporate.AudioControls","7EE7776C.LinkedInforWindows")

$AppxPackages = Get-AppxPackage
ForEach ($AppxPackage in $AppxPackages)
  {
    If ($AppxPackage.PackageFullName.Split("_")[0] -in $RemoveApps)
      {Remove-AppxPackage -Package $AppxPackage.PackageFullName}
  }

$AppxProvisionedPackages = Get-AppxProvisionedPackage -online
ForEach ($AppxProvisionedPackage in $AppxProvisionedPackages)
  {
    If ($AppxProvisionedPackage.PackageName.Split("_")[0] -in $RemoveApps)
      {Remove-AppxProvisionedPackage -online -PackageName $AppxProvisionedPackage.PackageName}
  }

Get-AppxProvisionedPackage -online | format-list -Property DisplayName,PackageName
Get-AppxPackage | format-list -Property PackageFamilyName,PackageFullName