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

function Get-Configuration($folder) {
  $xml    = [xml]'<configuration/>'

  $method = [Microsoft.EnterpriseManagement.Configuration.ManagementPackFolder].GetMethod('GetItems')
  $closed = $method.MakeGenericMethod([Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscovery])

  $discovery = $closed.Invoke($folder, @()) | where Name -match 'seed' | select -first 1

  xml.DocumentElement.InnerXml = $discovery.DataSource.Configuration

  return $xml.configuration
}

# Test endpoint
$template_name   = 'PureStorageFlashArray.UITemplate.Template'
$folder_name     = 'PureStorageFlashArray.UITemplate.Folder'
$seed_class_name = 'PureStorage.FlashArray.PureArraySeed'
$profile_name    = 'PureStorage.FlashArray.FlashArrayAdminAccount'

$adminProfile = $MP.GetSecureReference($profile_name)
$items = $MP.GetTemplate($template_name).GetFolders() 
  | where Name -eq $folder_name
  | ForEach-Object { $_.GetSubFolders() }

if (!$items) {
  Write-Host "ERROR: Pure Storage FlashArray Endpoint template not found. Script will stop." -ForegroundColor Red
  Write-Host "--------------------"
  break
}
else {
  Write-Host "INFO: $($items.Count) endpoint template instance(s) have been found." -ForegroundColor Green
  Write-Host "--------------------"
  Write-Host ""
}

$seed_class       = Get-SCOMClass -Name $seed_class_name
$seed_id_property = $seed_class.GetProperties() | where Name -eq 'TemplateId' | select -first 1

$endpoints = Get-SCOMClassInstance -Class $seed_class

foreach ($item in $items) {
  $config = Get-Configuration $item

  $endpoint = $endpoints | where {$_.Item($seed_id_property).Value -eq $config.Id} | select -first 1

  if (!$endpoint) {
    Write-Host "ERROR: $($config.Endpoint) endpoint object (seed) not found. Script will stop." -ForegroundColor Red
    Write-Host "--------------------"
    break
  }
  else {
    Write-Host "INFO: $($config.Endpoint) endpoint template instance have been found." -ForegroundColor Green
    Write-Host "--------------------"
    Write-Host ""
  }

  $pool = Get-SCOMResourcePool -Id $config.Pool

  if (!$pool) {
    Write-Host "ERROR: $($config.Endpoint) endpoint Resource Pool ($pool) not found. Script will stop." -ForegroundColor Red
    Write-Host "--------------------"
    break
  }
  else {
    Write-Host "INFO: $($config.Endpoint) endpoint Resource Pool ($pool) found." -ForegroundColor Green
    Write-Host "--------------------"
    Write-Host ""
  }

  $overrides = $endpoint.GetResultantOverrides($adminProfile).ResultantSecureReferenceOverrides

  if (!$overrides.ContainsKey('SecureReferenceId')) {
    Write-Host "ERROR: $($config.Endpoint) endpoint Run As Account not set. Script will stop." -ForegroundColor Red
    Write-Host "--------------------"
    break
  }
  else {
    Write-Host "INFO: $($config.Endpoint) endpoint Run As Account is configured." -ForegroundColor Green
    Write-Host "--------------------"
    Write-Host ""
  }

  $ssid    = $overrides['SecureReferenceId'].EffectiveValue
  $account = Get-SCOMRunAsAccount
    | where {$ssid -eq ([string]::Join($null, ($_.SecureStorageId | ForEach-Object {$_.ToString('X2')})))}
    | select -first 1

  if (!$account) {
    Write-Host "ERROR: $($config.Endpoint) endpoint Run As Account ($ssid) not found. Script will stop." -ForegroundColor Red
    Write-Host "--------------------"
    break
  }
  else {
    Write-Host "INFO: $($config.Endpoint) endpoint Run As Account ($ssid) found." -ForegroundColor Green
    Write-Host "--------------------"
    Write-Host ""
  }

  $distribution = Get-SCOMRunAsDistribution -RunAsAccount $account

  if ($distribution.Security -eq 'MoreSecure') {
    [guid[]]$ds = $distribution.SecureDistribution | ForEach-Object {$_.Id}

    if (!$ds.Contains($pool.Id)) {
      Write-Host "ERROR: $($config.Endpoint) endpoint Run As Account $($account.Name) is not distributed to $($pool.DisplayName) pool. Script will stop." -ForegroundColor Red
      Write-Host "--------------------"
      break
    }
    else {
      Write-Host "INFO: $($config.Endpoint) endpoint Run As Account $($account.Name) is distributed to $($pool.DisplayName) pool." -ForegroundColor Green
      Write-Host "--------------------"
      Write-Host ""
    }
  }
}

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

# Test array login
Write-Host "INFO: Testing the ability to log into the array via the SDK..." -ForegroundColor Green
Write-Host ""
try {
  Import-Module  PureStoragePowerShellSDK

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