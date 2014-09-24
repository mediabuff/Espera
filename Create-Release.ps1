$MSBuildLocation = "C:\Program Files (x86)\MSBuild\12.0\bin"

if (Test-Path .\Release) {
    rmdir -r -force .\Release
}

mkdir .\Release
mkdir .\Release\EsperaPortable

# Build the portable version
Write-Host "Building Portable Version"
& "$MSBuildLocation\MSBuild.exe" /t:Rebuild /p:Configuration=Release /p:Platform="x86" /v:quiet ".\Espera\Espera.sln"

cp ".\Espera\Espera.View\bin\Release\*.dll" ".\Release\EsperaPortable\"
cp ".\Espera\Espera.View\bin\Release\Espera.exe" ".\Release\EsperaPortable\"
cp ".\Espera\Espera.View\bin\Release\Espera.exe.config" ".\Release\EsperaPortable\"
cp ".\Changelog.md" ".\Release\EsperaPortable\Changelog.txt"

# Build the ClickOnce version
Write-Host "Building ClickOnce version"

# We explicitely clean the solution, as rebuilding and publish somehow won't work together
& "$MSBuildLocation\MSBuild.exe" /t:clean /p:Configuration=Release /p:Platform="x86" /v:quiet ".\Espera\Espera.sln"
& "$MSBuildLocation\MSBuild.exe" /t:publish /p:Configuration=Release /p:Platform="x86" /v:quiet ".\Espera\Espera.sln"

cp -r ".\Espera\Espera.View\bin\Release\app.publish\" ".\Release\"
Rename-Item ".\Release\app.publish\setup.exe" "EsperaSetup.exe"
