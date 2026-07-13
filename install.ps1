# [ZipLoot] Private Temp Mail Installer
# ==============================================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = $pwd }
Set-Location $scriptDir

# Check if Python is installed
$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    Write-Host "[ERROR] Python is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install Python 3 and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit
}

# Run the Python deployment helper script
python deploy_helper.py
