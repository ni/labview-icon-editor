# escape=`
FROM nationalinstruments/labview:2026q1-windows
USER ContainerAdministrator

SHELL ["powershell", "-NoProfile", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
COPY Tooling/Run-LUnitWindowsContainer.ps1 C:/workspace/Tooling/Run-LUnitWindowsContainer.ps1

# Deploys checksum-verified LUnit package files directly; VIPM is not used (its installs stall in Windows containers).
RUN & C:\workspace\Tooling\Run-LUnitWindowsContainer.ps1 -Stage Setup; `
    if (-not (Test-Path C:\workspace\lunit-results\dependency-manifest.json)) { throw 'Required LUnit dependency manifest is missing.' }; `
    Copy-Item C:\workspace\lunit-results\dependency-manifest.json C:\lunit-dependency-manifest.json; `
    Remove-Item C:\workspace\Tooling\Run-LUnitWindowsContainer.ps1; `
    Remove-Item C:\workspace\lunit-results\Setup.log -Force

LABEL org.opencontainers.image.title="LabVIEW Icon Editor LUnit Windows dependencies"
