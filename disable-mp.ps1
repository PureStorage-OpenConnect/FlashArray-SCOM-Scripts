# Disables Pure Storage Management Pack Rules, Monitors and Discovery
param(
    [Parameter(Mandatory=$true)]
    [string] $OverridesMPName
)

function CreateManagementPack {
    param (
        $Name
    )

    $ManagementPackID = $Name 
    $MG = Get-SCOMManagementGroup
    $MPStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore
    $MP = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($ManagementPackID, $Name, (New-Object Version(1, 0, 0)), $MPStore)
    $MG.ImportManagementPack($MP)
    $MP = $MG.GetManagementPacks($ManagementPackID)[0]
    $MP.DisplayName = $Name
    $MP.Description = "Auto Generated Management Pack $Name"
    $MP.AcceptChanges()
}

CreateManagementPack -Name $OverridesMPName
$overides_mp = Get-SCOMManagementPack -Name $OverridesMPName
$overides_mp
$mp = Get-SCOMManagementPack -Name PureStorageFlashArray

$mp | Get-SCOMRule | ForEach-Object  {
    $rule = $_
    $target = Get-SCOMClass -Id $rule.Target.Id
    Write-Host "Disabling rule $($rule.Name)"
    Disable-SCOMRule -Rule $rule -ManagementPack $overides_mp -Class $target -Enforce
}

$mp | Get-SCOMDiscovery | ForEach-Object {
    $discovery = $_
    $target = Get-SCOMClass -Id $discovery.Target.Id
    Write-Host "Disabling discovery $($discovery.Name)"
    Disable-SCOMDiscovery -Discovery $discovery -ManagementPack $overides_mp -Class $target -Enforce
}


$mp | Get-SCOMMonitor | ForEach-Object  {
    $monitor = $_
    $target = Get-SCOMClass -Id $monitor.Target.Id    
    Write-Host "Disabling monitor $($monitor.Name) ... "
    Disable-SCOMMonitor -Monitor $monitor -ManagementPack $overides_mp -Class $target -Enforce
}