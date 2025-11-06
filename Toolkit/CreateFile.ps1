$CreateUnattendedFile = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Themes>
                <DesktopBackground>C:\Windows\Setup\default_desktop.jpg</DesktopBackground>
                <ThemeName>pic1</ThemeName>
            </Themes>
            <RegisteredOwner />
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>cmd /c C:\Windows\Setup\RenamePC.exe</CommandLine>
                    <Description>rename PC</Description>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>shutdown -r -t 0</CommandLine>
                    <Description>reboot after rename PC</Description>
                    <Order>2</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>C:\Windows\Setup\SysConf.vbs C:\Windows\Setup\SysConf.cmd</CommandLine>
                    <Description>runonce</Description>
                    <Order>3</Order>
                    <RequiresUserInput>false</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
            <TimeZone>China Standard Time</TimeZone>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>zh-CN</InputLocale>
            <SystemLocale>zh-CN</SystemLocale>
            <UILanguage>zh-CN</UILanguage>
            <UILanguageFallback>zh-CN</UILanguageFallback>
            <UserLocale>zh-CN</UserLocale>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>C:\Windows\Setup\Install-MultiLang.exe</Path>
                    <Description>install language</Description>
                    <WillReboot>OnRequest</WillReboot>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>C:\Windows\Setup\CT.exe</Path>
                    <Description>CT</Description>
                    <WillReboot>OnRequest</WillReboot>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
"@
Out-File -InputObject $CreateUnattendedFile -FilePath "W:\Windows\Panther\Unattend.xml" -Force -Encoding ASCII