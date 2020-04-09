param(
  [string]$upstreamVersion = "continuous",
  [string]$signtool = "signtool sign /sha1 FF52240075AD7D14AF25629FDF69635357C7D14B `$p"
)

$buildDir = Split-Path -Parent $PSCommandPath
$buildVersion = & git rev-list --count HEAD

Write-Output "`$upstreamVersion=$upstreamVersion"
Write-Output "`$buildVersion=$buildVersion"
Write-Output "`$signtool=$signtool"
Write-Output "`$buildDir=$buildDir"
Write-Output "`$Env:JAVA_HOME=$Env:JAVA_HOME"

$dokanInstallerVersion = & $PSScriptRoot"\Get-MSIFileInformation.ps1" .\resources\innosetup\Dokan_x64.msi "ProductVersion"

if (-not (Test-Path $Env:JAVA_HOME)) {
    Write-Output "JAVA_HOME not set or does not exist: $Env:JAVA_HOME"
    exit 1;
}

if(-not (Test-Path $Env:JAVA_HOME\jmods\jdk.packager.jar)){
    Write-Output "$Env:JAVA_HOME\jmods\jdk.packager.jar does not exist. You need to patch your JDK installation with the jar provided under ./tools"
    exit 1;
}

if(-not (Test-Path $Env:JAVA_HOME\bin\jdk.packager.jar)){
    Write-Output "$Env:JAVA_HOME\bin\jdk.packager.jar does not exist. You need to patch your JDK installation with the jar provided under ./tools"
    exit 1;
}

if(-not (Test-Path $Env:JAVA_HOME\bin\jpackager.exe)){
    Write-Output "$Env:JAVA_HOME\bin\jpackager.exe does not exist. You need to patch your JDK installation with the exe provided under ./tools"
    exit 1;
}

if(-not (Test-Path "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe")){
    Write-Output "C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe does not exist. Please install from http://www.angusj.com/resourcehacker."
    exit 1;
}

if(-not ($dokanInstallerVersion -eq [System.Diagnostics.FileVersionInfo]::GetVersionInfo(".\resources\app\dlls\dokan1.dll").FileVersion)){
    Write-Output "The Dokany version of the installer does not match the signed Dokan-DLL. Please update one of them such they belong to the same release."
    exit 1;
}

# cleanup
Remove-Item -Recurse -ErrorAction Ignore -Force buildkit.zip, app, libs

# configure stuff
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# download and extract buildkit
$buildkitUrl = "https://dl.bintray.com/cryptomator/cryptomator/${upstreamVersion}/buildkit-win.zip"
$wc = New-Object System.Net.WebClient
Write-Output "Downloading ${buildkitUrl}..."
$wc.Downloadfile($buildkitUrl, "buildkit.zip")
Expand-Archive -Path buildkit.zip -DestinationPath . -Force
if (-not (Test-Path libs)) {
    Write-Output "libs/ does not exist. Buildkit damaged?"
    exit 1;
}

# create application dir
& "$Env:JAVA_HOME\bin\jpackager" `
  create-image `
  --verbose `
  --echo-mode `
  --input libs `
  --output app `
  --name Cryptomator `
  --class org.cryptomator.launcher.Cryptomator `
  --main-jar launcher-$upstreamVersion.jar `
  --icon resources/app/Cryptomator.ico `
  --jvm-args "-Dcryptomator.logDir=`"~/AppData/Roaming/Cryptomator`"" `
  --jvm-args "-Dcryptomator.settingsPath=`"~/AppData/Roaming/Cryptomator/settings.json`"" `
  --jvm-args "-Dcryptomator.ipcPortPath=`"~/AppData/Roaming/Cryptomator/ipcPort.bin`"" `
  --jvm-args "-Dcryptomator.keychainPath=`"~/AppData/Roaming/Cryptomator/keychain.json`"" `
  --jvm-args "-Xss2m" `
  --jvm-args "-Xmx512m" `
  --identifier org.cryptomator `
  --version $upstreamVersion `
  --module-path `"$Env:JAVA_HOME\jmods`" `
  --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.unsupported,java.net.http,jdk.crypto.ec `
  --strip-native-commands

# adjust .app
& 'attrib' -r 'app/Cryptomator/Cryptomator.exe'
& 'C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe' `
  -open "resources\resourcehacker\cryptomator.rc" `
  -save "resources\resourcehacker\cryptomator.res" `
  -action compile
& 'C:\Program Files (x86)\Resource Hacker\ResourceHacker.exe' `
  -open "app\Cryptomator\Cryptomator.exe" `
  -resource "resources\resourcehacker\cryptomator.res" `
  -save "app\Cryptomator\Cryptomator.exe" `
  -action modify `
  -mask ",,,"
Copy-Item resources/app/dlls/* app/Cryptomator/

# build installer
Copy-Item -Recurse resources/innosetup/* app/
Set-Location app/
$env:CRYPTOMATOR_VERSION = "$upstreamVersion"
$env:DOKAN_VERSION = "$dokanInstallerVersion"
& 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe' setup.iss /Qp "/sdefault=`"$signtool`""
