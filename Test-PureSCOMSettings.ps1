<#
  Test-PureSCOMSettings.ps1
  Version:        1.1.0.0
  Author:         Hesham Anan, Mike Nelson @ Pure Storage
.SYNOPSIS
  Helper functions to facilitate the diagnostic testing of a SCOM Management Server settings for the Pure Storage SCOM Management Pack.
.DESCRIPTION
  Helper functions to facilitate the diagnostic testing of a SCOM Management Server settings for the Pure Storage SCOM Management Pack. The script creates a randdomly named transcript output TXT file in the current users Documents folder.
.PARAMETER EndPoint
  Required. FlashArray IP or FQDN. If using FQDN, ensure DNS resolves.
.INPUTS
  Array endpoint
  Optional. If you wish to pass the FlashArray credentials to the script, you must create a variable that contains the proper credentials.
  This could be done using Get-Credential - ex. $Creds = Get-Credential
.OUTPUTS
  Diagnostic outputs for every test.
  Randomly named transcript file located in the current user Documents folder
.EXAMPLE
Test-PureSCOMSettings.ps1 -EndPoint $ArrayIP

Test the array as an IP address.

.EXAMPLE
$Creds = Get-Credential
Test-PureSCOMSettings.ps1 -EndPoint $ArrayFQDN

Create the $Creds variable and test the array as a FQDN.

.DISCLAIMER
You running this code means you will not blame the author(s) if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for any damages whatsoever arising out of the use of or inability to use the script or documentation.
#>

#Requires -RunAsAdministrator

Param (
  [Parameter(Position = 0, Mandatory = $true)][ValidateNotNullOrEmpty()][string] $EndPoint
)

Write-Host ""
Start-Transcript
Write-Host ""

# Obtain FA Credentials if not previously defined as the $Creds variable (see .INPUTS)
Write-Host "Please supply the FlashArray username and password when prompted." -ForegroundColor Yellow
Write-Host ""
If (!$Creds) {
$Creds = Get-Credential
}
# Get SCOM environment Information
$mgmtserver = Get-SCOMManagementServer
Write-Host "INFO: This Management Server: $mgmtserver.DisplayName" -ForegroundColor Green
Write-Host ""
Write-Host "--------------------"
Write-Host "INFO: Checking for Gateway Server..." -ForegroundColor Green
$gwserver = Get-SCOMGatewayManagementServer
if (!($gwserver)) {
  Write-Host "INFO: No Gateway Server found." -ForegroundColor Green
  Write-Host "--------------------"
}
else {
  Write-Host "WARNING: Management Packs should not be installed on Gateway Servers." -ForegroundColor Yellow
  Write-Host "If this is a Gateway Server, Ctrl-C out of this script. Otherwise, continue." -ForegroundColor Yellow
  Pause
  Write-Host "--------------------"
}
Write-Host "INFO: Checking for Resource Pools..." -ForegroundColor Green
$respool = Get-SCOMResourcePool
if (!($respool)) {
  Write-Host "INFO: No Resource Pools found." -ForegroundColor Green
  Write-Host "--------------------"
}
else {
  Write-Host "WARNING: Resource Pools found. Pure does not yet fully support Resource Pools having more than (1) management server for FlashArray monitoring." -ForegroundColor Yellow
  Write-Host "--------------------"
}
# Verify MP installation
Write-Host ""
Write-Host "INFO: Verifing Management Pack installation..." -ForegroundColor Green
Write-Host ""
$MPName = "PureStorageFlashArray"
$MP = Get-SCOMManagementPack -Name $MPName
if (!$MP) {
  Write-Host "ERROR: Pure Storage FlashArray Management Pack is not installed. Script will stop." -ForegroundColor Red
  break
}
else {
  Write-Host "INFO: Management Pack is installed." -ForegroundColor Green
  Write-Host "--------------------"
}
Write-Host ""
# Verify registry entry for the SDK
Write-Host "INFO: Verifying the registry entry exists for the Pure Storage PowerShell SDK module..." -ForegroundColor Green
Write-Host ""
$RegistryPath = "HKLM:\SOFTWARE\PureStorage\SCOM\PowerShellSDKPath"
$SDKKey = Get-ItemProperty -Path $RegistryPath
if ($null -eq $SDKKey -or $null -eq $SDKKey.'(default)') {
  Write-Host "ERROR: Failed to find $RegistryPath in registry." -ForegroundColor Red
  Write-Host "--------------------"
  return
}
else {
  Write-Host "INFO: $RegistryPath exists." -ForegroundColor Green
  Write-Host "--------------------"
  Write-Host ""
  Write-Host "INFO: Pleae ensure that the SCOM Action Account also has access to this registry key." -ForegroundColor Green
  Write-Host "--------------------"
}
Write-Host ""

# Test 443 & SSH connection to array
Write-Host ""
Write-Host "INFO: Testing network connectivity to the array..." -ForegroundColor Green
$TestResolution = Test-NetConnection -ComputerName $EndPoint -InformationLevel "Detailed"
if ($TestResolution.NameResolutionSucceeded -ne "True") {
  $TestPorts = "false"
  Write-Host ""
  Write-Warning "DNS name resolution is not working for the supplied array name. Further testing is not possible."
  Write-Warning "Try this cmdlet with an IP address instead or resolve the DNS issue."
  Write-Warning "Exiting."
  Write-Host "--------------------"
  break
}
else {
  $TestPorts = "true"
}
If ($TestPorts -eq "true") {
  $testports = @("443", "22")
  foreach ($testport in $testports) {
    Write-Host "INFO: Testing port $testport" -ForegroundColor Green
    Write-Host ""
    try {
      $results = Test-NetConnection -Port $testport -ComputerName $EndPoint -InformationLevel "Detailed"
      $testresult = $results.TcpTestSucceeded
      if ($testresult -eq 'True') {
        Write-Host ""
        Write-Host "INFO: Port $testport success." -ForegroundColor Green
        $results
        Write-Host "--------------------"
      }
      else {
        Write-Host ""
        Write-Host "ERROR: Port $testport failed." -ForegroundColor Red
        $results
        Write-Host "--------------------"
      }
    }
    catch {
      Write-Warning $Error[0]
    }

  }
}
Write-Host ""

$SDKPath = $SDKKey.'(default)'
# Test array login
Write-Host "INFO: Testing the ability to log into the array via the SDK..." -ForegroundColor Green
Write-Host ""
Write-Host "INFO: SDK Key Path = $SDKPath" -ForegroundColor Green
Write-Host ""
try {
  $pathtest = Test-Path $SDKPath -PathType leaf
  if ($pathtest -eq $false) {
    Write-Host "ERROR: Path to SDK DLL file does not exist or is incorrect." -ForegroundColor Red
    Write-Host "--------------------"
  }
  Import-Module $SDKPath -Force
  Write-Host "INFO: Module information:" -ForegroundColor Green
  Get-Module PureStoragePowerShellSDK
  Get-Module -ListAvailable | Where-Object -Property Name -EQ PureStoragePowerShellSDK | Format-Table -GroupBy Path
  Write-Host "--------------------"
  Write-Host ""
  Write-Host "INFO: Connecting to array..." -ForegroundColor Green
  Write-Host ""
  $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials $Creds -IgnoreCertificateError
  if ($null -eq $FlashArray) {
    Write-Host "ERROR: Failed to connect to $EndPoint. Check the audit logs on the array." -ForegroundColor Red
    Write-Host "--------------------"
  }
  else {
    Write-Host "INFO: Successfully connected to array $EndPoint." -ForegroundColor Green
    return $FlashArray
    Write-Host "--------------------"
  }
}
# Complete script
finally {
  Write-Host ""
  Write-Host "INFO: Script completed." -ForegroundColor Green
  Write-Host ""
  Stop-Transcript
}

#End