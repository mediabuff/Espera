Set-StrictMode -version Latest
$ErrorActionPreference = "Stop"

Write-Host "Building Espera..." -ForegroundColor Green

# ==================================== Functions

Function GetMSBuildExe {
	[CmdletBinding()]
	$DotNetVersion = "4.0"
	$RegKey = "HKLM:\software\Microsoft\MSBuild\ToolsVersions\$DotNetVersion"
	$RegProperty = "MSBuildToolsPath"
	$MSBuildExe = Join-Path -Path (Get-ItemProperty $RegKey).$RegProperty -ChildPath "msbuild.exe"
	Return $MSBuildExe
}

Function ZipFiles($Filename, $Source)
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $CompressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($Source, $Filename, $CompressionLevel, $false)
}

# ==================================== Variables

$NuGet = "$PSScriptRoot\.nuget\NuGet.exe"
&($Nuget) restore Espera.sln
$SquirrelPackagePath = (ls .\packages\squirrel.windows.*)[0]
$Squirrel = Join-Path  $SquirrelPackagePath "tools\Squirrel.com"
$SquirrelUpdate = Join-Path  $SquirrelPackagePath "tools\Squirrel.exe"

$BuildPath = "$PSScriptRoot\Espera.View\bin\Release"
$NuSpecPath = "$PSScriptRoot\Espera.nuspec"
$ReleasesFolder = "$PSScriptRoot\Releases"
$Icon = "$PSScriptRoot\Espera.View\Images\ApplicationIcon.ico"

# ==================================== NuSpec Metadata

$NuSpecXml = [xml](Get-Content $NuSpecPath)
$Version = $NuSpecXml.package.metadata.version

# ==================================== Build

If(Test-Path -Path $BuildPath) {
	Remove-Item -Confirm:$false "$BuildPath\*.*"
}

&(GetMSBuildExe) Espera.sln `
	/t:Clean`;Rebuild `
	/p:Configuration=Release `
	/p:AllowedReferenceRelatedFileExtensions=- `
	/p:DebugSymbols=false `
	/p:DebugType=None `
	/clp:ErrorsOnly `
	/v:m
	
If(!(Test-Path -Path $ReleasesFolder )){
	New-Item -ItemType directory -Path $ReleasesFolder
}

# ==================================== Squirrel

$NuPkgPath = "$PSScriptRoot\Espera.$Version.nupkg"

&($NuGet) pack $NuSpecPath

$SquirrelFullNuPkgOutputPath = "$ReleasesFolder\Espera-$Version-full.nupkg"
If(Test-Path -Path $SquirrelFullNuPkgOutputPath) {
	Remove-Item -Confirm:$false $SquirrelFullNuPkgOutputPath
}

$SquirrelDeltaNuPkgOutputPath = "$ReleasesFolder\Espera-$Version-delta.nupkg"
If(Test-Path -Path $SquirrelDeltaNuPkgOutputPath) {
	Remove-Item -Confirm:$false $SquirrelDeltaNuPkgOutputPath
}

$OutputSetupExe = "$ReleasesFolder\Espera.Setup.$Version.exe"
If(Test-Path -Path $OutputSetupExe) {
	Remove-Item -Confirm:$false $OutputSetupExe
}

&($Squirrel) --releasify $NuPkgPath -r $ReleasesFolder

$SquirrelSetupExe = "$ReleasesFolder\Setup.exe"
If(Test-Path -Path $SquirrelSetupExe) {
	Rename-Item $SquirrelSetupExe $OutputSetupExe
}

# ==================================== Portable

$PortableFolder = "$ReleasesFolder\EsperaPortable"
$PortableAppPath = "$PortableFolder\Espera"
$ReleaseZip = "$ReleasesFolder\EsperaPortable.zip"

If(Test-Path -Path $PortableFolder) {
	Remove-Item -Confirm:$false $PortableFolder -Recurse -Force
}

If(Test-Path -Path $ReleaseZip) {
	Remove-Item -Confirm:$false $ReleaseZip
}

New-Item -ItemType directory -Path $PortableAppPath

# This file tells Espera that it's a portable application
New-Item "$PortableAppPath\PORTABLE" -type file

# Create a Squirrel-conforming app directory
New-Item -ItemType directory -Path "$PortableAppPath\packages"

cp $SquirrelFullNuPkgOutputPath "$PortableAppPath\packages"
cp "$ReleasesFolder\RELEASES" "$PortableAppPath\packages"
cp "$BuildPath" "$PortableAppPath\app-$Version" -Recurse
cp $SquirrelUpdate "$PortableAppPath\Update.exe"
cp $Icon "$PortableAppPath\Icon.ico"

# Create the shortcut that Squirrel will update for us
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$PortableAppPath\Espera.lnk")
$Shortcut.TargetPath = "$PortableAppPath\app-$Version\Espera.exe"
$Shortcut.Save()

# Create a batch file to launch the shortcut we've just created, 
# because we can't really link a shortcut to another shortcut
"start Espera\Espera.lnk" | out-file -Encoding ascii "$PortableAppPath\Espera.cmd"

# Create a static shortcut to the batch file we've just created, 
# this shortcut is the one the user will use
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$PortableFolder\Espera.lnk")
$Shortcut.TargetPath = "$PortableAppPath\Espera.cmd"
$Shortcut.IconLocation = "$PortableAppPath\Icon.ico"
$Shortcut.Save()

ZipFiles $ReleaseZip $PortableFolder

# ==================================== Cleanup

If(Test-Path -Path $NuPkgPath) {
	Remove-Item -Confirm:$false $NuPkgPath
}

# ==================================== Complete

Write-Host "Build $Version complete: $ReleasesFolder" -ForegroundColor Green
