<#
  Test-PureSCOMSettings.ps1
  Version:        1.0.1.0
  Author:         Hesham Anan, Mike Nelson @ Pure Storage
.SYNOPSIS
  Helper functions to facilitate the diagnostic testing of a SCOM Management Server settings for the Pure Storage SCOM Management Pack.
.DESCRIPTION
  Helper functions to facilitate the diagnostic testing of a SCOM Management Server settings for the Pure Storage SCOM Management Pack. The script creates a randdomly named transcript output TXT file in the current users Documents folder.
.PARAMETER EndPoint
  Required. FlashArray IP or FQDN.
.INPUTS
  Array endpoiint
.OUTPUTS
  Diagnostic outputs for every test.
  Randomly named transcript file located in the current user Documents folder
.EXAMPLE
Test-PureSCOMSettings.ps1 -EndPoint $ArrayIPAddress

.DISCLAIMER
You running this code means you will not blame the author(s) if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for any damages whatsoever arising out of the use of or inability to use the script or documentation.
#>

#Requires -RunAsAdministrator

Param (
    [Parameter(Position = 0, Mandatory)][ValidateNotNullOrEmpty()][string] $EndPoint
    )

Start-Transcript

# Obtain FA Credentials
Write-Host ""
Write-Host "Please supply the FlashArray username and password." -ForegroundColor Yellow
Write-Host ""
$Creds = Get-Credential

# Get SCOM environment Information
$mgmtserver = Get-SCOMManagementServer | format-table -AutoSize
$mgmtserver
$gwserver = Get-SCOMGatewayManagementServer
if (!($gwserver)) {
  Write-Host "No Gateway Server found. Continuing..." -ForegroundColor Yellow
}
$respool = Get-SCOMResourcePool
if (!($respool)) {
  Write-Host "No Resource Pools found. Continuing..." -ForegroundColor Yellow
}

# Verify management Pack installation
$MPName = 'PureStorageFlashArray'
$MP = Get-SCOMManagementPack -Name $MPName
if (!$MP) {
    Write-Host "ERROR: Pure Storage FlashArray Management Pack is not installed. Script will stop." -ForegroundColor Red
    break
}
else {
    Write-Host "Management Pack is installed." -ForegroundColor Green
}
Write-host "Continuing..."

# Verify registry entry for the SDK
Write-Host "Verifying the registry entry exists for the Pure Storage PowerShell SDK module..."
$RegistryPath = "HKLM:\SOFTWARE\PureStorage\SCOM\PowerShellSDKPath"
$SDKKey = Get-ItemProperty -Path $RegistryPath
if ($null -eq $SDKKey -or $null -eq $SDKKey.'(default)') {
    Write-Host "ERROR: Failed to find $RegistryPath in registry." -ForegroundColor Red
    return
}
else {
    Write-Host "$RegistryPath exists." -ForegroundColor Green
    Write-Host ""
    Write-Host "Pleae ensure that the service account that SCOM runs scripts as also has access to this registry key."
}
Write-Host ""
Write-Host "Continuing..."

#Set variables
$SDKPath = $SDKKey.'(default)'
Write-Host "Key Path = $SDKPath"

# Test 443 & SSH connection to array
Write-Host ""
Write-Host "Testing network connectivity to the array..."
$testports = @("443","22")
foreach ($testport in $testports) {
    $results = Test-NetConnection -Port $testport -ComputerName $ArrayAddress
    $testresult = $results.TcpTestSucceeded
        if ($testresult -eq 'True') {
          Write-Host ""
          Write-Host "Port $testport success." -ForegroundColor Green
}
        else{
          Write-Host ""
          Write-Host "ERROR: Port $testport failed." -ForegroundColor Red
}
}
Write-Host ""
Write-Host "Continuing..."
# Test array login
Write-Host ""
Write-host "Testing the ability to log into the array via the SDK..."
try {
    $pathtest = Test-Path $SDKPath -PathType leaf
    if ($pathtest -eq $false) {
        Write-Host "ERROR: Path to SDK DLL file does not exist or is incorrect." -ForegroundColor Red
    }
    Import-Module $SDKPath -Force
    Get-Module PureStoragePowerShellSDK
    Get-Module -ListAvailable | Where-Object -Property Name -eq PureStoragePowerShellSDK | Format-Table -GroupBy Path
    $FlashArray = New-PfaArray -EndPoint $ArrayAddress -Credentials $Creds -IgnoreCertificateError
    if ($null -eq $FlashArray) {
        Write-Host "ERROR: Failed to connect to array. Check the logs." -ForegroundColor Red
    }
    else {
        Write-Host "Successfully connected to array $ArrayAddress" -ForegroundColor Green
        return $FlashArray
    }
}
finally {
    Write-Host "Script completed." -ForegroundColor Yellow
    Stop-Transcript
}

#End