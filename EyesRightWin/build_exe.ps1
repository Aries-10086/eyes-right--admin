# Build Eyes Right for Windows 10 / 11
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "[1/3] Creating venv..."
python -m venv .venv
& .\.venv\Scripts\Activate.ps1

Write-Host "[2/3] Installing dependencies..."
python -m pip install -U pip
pip install -r requirements.txt

Write-Host "[3/3] Building with PyInstaller..."
pyinstaller --noconfirm EyesRight.spec

Write-Host ""
Write-Host "Done."
Write-Host "Run: dist\EyesRight\EyesRight.exe"
Write-Host "Zip the dist\EyesRight folder to distribute (Win10/Win11, x64)."
