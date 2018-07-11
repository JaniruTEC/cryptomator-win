param([string]$buildVersion = "continuous")

# cleanup
Remove-Item -Recurse -ErrorAction Ignore -Force antbuild, libs, antkit.zip, build.xml

# configure stuff
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# download ant (if not installed)
if ((Get-Command "ant.exe" -ErrorAction SilentlyContinue) -eq $null) {
	if (Test-Path "apache-ant-1.9.12" -eq $False) {
		Invoke-WebRequest "http://mirror.softaculous.com/apache//ant/binaries/apache-ant-1.9.12-bin.zip" -OutFile "ant.zip"
		Expand-Archive -Path ant.zip -DestinationPath .
	}
	$env:Path += ".\apache-ant-1.9.12\bin\";
}

# download and extract ant-kit
Invoke-WebRequest "https://github.com/cryptomator/cryptomator/releases/download/$buildVersion/antkit.zip" -OutFile "antkit.zip"
Expand-Archive -Path antkit.zip -DestinationPath .


# build application directory
& 'ant' `
  '-Dantbuild.logback.configurationFile="logback.xml"' `
  '-Dantbuild.cryptomator.settingsPath="~/AppData/Roaming/Cryptomator/settings.json"' `
  '-Dantbuild.cryptomator.ipcPortPath="~/AppData/Roaming/Cryptomator/ipcPort.bin"' `
  '-Dantbuild.cryptomator.keychainPath="~/AppData/Roaming/Cryptomator/keychain.json"' `
  '-Dantbuild.dropinResourcesRoot="./resources/app"' `
  image
  
# adjust .app
& 'attrib' -r './antbuild/Cryptomator/Cryptomator.exe'
Copy-Item resources/app/logback.xml ./antbuild/Cryptomator/app

# build installer
Copy-Item -Recurse innosetup/* ./antbuild/
Set-Location ./antbuild
$env:CRYPTOMATOR_VERSION = "$buildVersion"
& 'C:\Program Files (x86)\Inno Setup 5\ISCC.exe' setup.iss '/sdefault="signtool $p"'

$host.UI.RawUI.ReadKey()