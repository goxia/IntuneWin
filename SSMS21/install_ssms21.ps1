
# Install-SSMS21.ps1
# SSMS 21 Offline Installation
# Supports Local / ISO / Intune

$ErrorActionPreference = "Stop"
$Source = $PSScriptRoot

try {
    # 1. Check administrator privileges
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)

    if (-not $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Administrator privileges are required."
    }

    # 2. Locate installation files
    $Setup = Join-Path $Source "vs_SSMS.exe"
    $CertDir = Join-Path $Source "certificates"
    $CertUtil = Join-Path $env:SystemRoot "System32\certutil.exe"

    if (-not (Test-Path $Setup -PathType Leaf)) {
        throw "SSMS installer not found: $Setup"
    }

    # 3. Define certificates
    $Certificates = @(
        @{ File = "manifestRootCertificate.cer"; Store = "Root" },
        @{ File = "manifestCounterSignRootCertificate.cer"; Store = "Root" },
        @{ File = "vs_installer_opc.RootCertificate.cer"; Store = "Root" },
        @{ File = "Microsoft Windows Code Signing PCA 2024.crt"; Store = "CA" }
    )

    # 4. Check certificate files
    foreach ($Item in $Certificates) {
        $Path = Join-Path $CertDir $Item.File

        if (-not (Test-Path $Path -PathType Leaf)) {
            throw "Certificate not found: $Path"
        }
    }

    # 5. Force import certificates
    Write-Output "Importing certificates..."

    foreach ($Item in $Certificates) {
        $Path = Join-Path $CertDir $Item.File

        Write-Output "Importing: $($Item.File)"

        & $CertUtil -f -addstore $Item.Store $Path

        if ($LASTEXITCODE -ne 0) {
            throw "Certificate import failed: $($Item.File), ExitCode=$LASTEXITCODE"
        }

        # Verify certificate thumbprint
        $Cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Path)

        $Installed = Get-Item `
            "Cert:\LocalMachine\$($Item.Store)\$($Cert.Thumbprint)" `
            -ErrorAction SilentlyContinue

        if (-not $Installed) {
            throw "Certificate verification failed: $($Item.File)"
        }

        Write-Output "Verified: $($Item.File)"
    }

    # 6. Install SSMS 21
    Write-Output "Installing SSMS 21..."

    $Process = Start-Process `
        -FilePath $Setup `
        -ArgumentList "--noWeb --downloadThenInstall --quiet --wait --norestart" `
        -WorkingDirectory $Source `
        -Wait `
        -PassThru

    Write-Output "SSMS installer exit code: $($Process.ExitCode)"

    exit $Process.ExitCode
}
catch {
    Write-Error $_
    exit 1
}
