<#
.SYNOPSIS
  Helper functions to facilitate managing purestorage management pack overrides
.DESCRIPTION
  Helper functions to facilitate managing purestorage management pack overrides
  Version:        1.0
  Author:         Hesham Anan, Mike Nelson @ Pure Storage
<#
.DISCLAIMER
You running this code means you will not blame the author(s) if this breaks your stuff. This script/function is provided AS IS without warranty of any kind. Author(s) disclaim all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall author(s) be held liable for any damages whatsoever arising out of the use of or inability to use the script or documentation.
#>
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

function SaveChanges {
    param (
        $OverridesManagementPack
    )
    try {
        $OverridesManagementPack.Verify()
        $OverridesManagementPack.AcceptChanges()
    }
    catch {
        Write-Error $_
        $OverridesManagementPack.RejectChanges()
    }
}

function Get-SourceModule {

    param (
        $OverridableParameters,
        $ParamName
    )
    $arrModules = New-Object System.Collections.ArrayList
    Foreach ($module in $OverridableParameters.keys) {
        foreach ($parameter in $OverridableParameters.$module) {
            if ($parameter.name -ieq $ParamName) {
                $objParameter = New-Object psobject
                Add-Member -InputObject $objParameter -MemberType NoteProperty -Name Module -Value  $module.name
                Add-Member -InputObject $objParameter -MemberType NoteProperty -Name Parameter -Value  $parameter.name
                [System.Void]$arrModules.Add($objParameter)
            }
        }
    }

    If ($arrModules.Count -eq 1) {
        return $arrModules[0].Module
    }
    else {
        return $null
    }
}

function Set-RulesLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $rules = $ManagementPack | Get-SCOMRule
    for ($i = 0; $i -le $rules.Length - 1; $i++)  {
        $rule = $rules[$i]
        $objParameters = $rule.GetOverrideableParametersByModule()
        $module = Get-SourceModule -OverridableParameters $objParameters -ParamName "LogToArray"
        if ($null -ne $module) {
            Write-Host "$Action logging for rule $( $rule.Name )"
            $target = Get-SCOMClass -Id $rule.Target.Id
            $OverrideID = "LogToArrayOverride." + $rule.name
            $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRuleConfigurationOverride($OverridesManagementPack, $OverrideID)
            $override.Rule = $rule
            $Override.Parameter = 'LogToArray'
            $override.Value = $LogToArray
            $override.Context = $Target
            $override.DisplayName = $OverrideID
            $override.Enforced = $true
            $override.Module = $module
            SaveChanges -OverridesManagementPack $OverridesManagementPack
        }
    }
}

function Set-MonitorsLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $monitors = $ManagementPack | Get-SCOMMonitor | Where { $_.xmltag -eq "UnitMonitor" }
    $monitors | ForEach-Object {
        $monitor = $_
        $target = Get-SCOMClass -Id $monitor.Target.Id
        Write-Host "$Action logging for monitor $( $monitor.Name ) ... "
        $OverrideID = "LogToArrayOverride" + $monitor.name
        $Override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorConfigurationOverride($OverridesManagementPack, $OverrideID)
        $Override.Monitor = $monitor
        $Override.Parameter = "LogToArray"
        $Override.Value = $LogToArray
        $Override.Context = $target
        $Override.DisplayName = "Override LogToArray"
        $override.Enforced = $true
        SaveChanges -OverridesManagementPack $OverridesManagementPack
    }
}

function Set-DiscoveriesLogToArrayOverrides {
    param (
        $ManagementPack,
        $OverridesManagementPack
    )
    $discoveries = $ManagementPack | Get-SCOMDiscovery
    for ($i = 0; $i -le $discoveries.Length - 1; $i++) {
        $discovery = $discoveries[$i]
        $objParameters = $discovery.GetOverrideableParametersByModule()
        $module = Get-SourceModule -OverridableParameters $objParameters -ParamName "LogToArray"
        if ($null -ne $module) {
            Write-Host "$Action logging for discovery $( $discovery.Name )"
            $target = Get-SCOMClass -Id $discovery.Target.Id
            $OverrideID = "LogToArrayOverride" + $discovery.name
            $Override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryConfigurationOverride($OverridesManagementPack, $OverrideID)
            $Override.Discovery = $discovery
            $Override.Parameter = "LogToArray"
            $Override.Value = $LogToArray
            $Override.Context = $target
            $Override.DisplayName = "Override LogToArray"
            $override.Enforced = $true
            $override.Module = $module
            SaveChanges -OverridesManagementPack $OverridesManagementPack
        }
    }
}

$INITIAL_DISCOVERY_SCRIPT_REGEX = '(?s)<ScriptName>PureStorage\.FlashArray\.PureArray\.Discovery\.ps1</ScriptName>.*?<ScriptBody>(?<script>.*?)</ScriptBody>'
function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string]$name = [System.Guid]::NewGuid()
    $path = (Join-Path $parent $name)
    New-Item -ItemType Directory -Path  $path
}

function Get-InitialDiscoveryScript {
    param (
        $content
    )

    $match = $content | Select-String $INITIAL_DISCOVERY_SCRIPT_REGEX
    if ($match) {
        $script = $match.Matches[0].Value
        return $script
    }
}


function Update-RuleParam {
    param(
        $RuleName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $RuleName : Overriding $ParamName to $ParamValue"
    $rule = Get-SCOMRule -Name $RuleName
    if (!$rule) {
        Write-Error "Could not find rule : $RuleName"
    }
    $objParameters = $rule.GetOverrideableParametersByModule()
    $module = Get-SourceModule -OverridableParameters $objParameters -ParamName $ParamName
    if (!$module) {
        Write-Error "Could not find module that includes parameter : $ParamName"
        return
    }
    $target = Get-SCOMClass -Id $rule.Target.Id
    $OverrideID = $ParamName + "Override." + $rule.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackRuleConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Rule = $rule
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    $override.Module = $module
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Update-DiscoveryParam {
    param(
        $DiscoveryName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $DiscoveryName : Overriding $ParamName to $ParamValue"
    $discovery = Get-SCOMDiscovery -Name $DiscoveryName
    if (!$discovery) {
        Write-Error "Could not find discovery : $DiscoveryName"
    }
    $objParameters = $discovery.GetOverrideableParametersByModule()
    $module = Get-SourceModule -OverridableParameters $objParameters -ParamName $ParamName
    if (!$module) {
        Write-Error "Could not find module that includes parameter : $ParamName"
        return
    }
    $target = Get-SCOMClass -Id $discovery.Target.Id
    $OverrideID = $ParamName + "Override." + $discovery.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Discovery = $discovery
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    $override.Module = $module
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Update-MonitorParam {
    param(
        $MonitorName,
        $ParamName,
        $ParamValue,
        $OverridesManagementPack
    )

    Write-Host "Updating $MonitorName : Overriding $ParamName to $ParamValue"
    $monitor = Get-SCOMMonitor -Name $MonitorName
    if (!$monitor) {
        Write-Error "Could not find discovery : $MonitorName"
    }
    $target = Get-SCOMClass -Id $monitor.Target.Id
    $OverrideID = $ParamName + "Override." + $monitor.name
    $override = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorConfigurationOverride($OverridesManagementPack, $OverrideID)
    $override.Monitor = $monitor
    $Override.Parameter = $ParamName
    $override.Value = $ParamValue
    $override.Context = $target
    $override.DisplayName = $OverrideID
    $override.Enforced = $true
    SaveChanges -OverridesManagementPack $OverridesManagementPack
}

function Get-Json {
    param (
        $Path
    )
    $json = Get-Content $path | ConvertFrom-Json
    # Convert to hashtable
    $result = @{
    }
    $json.psobject.properties | ForEach-Object {
        $result[$_.Name] = $_.Value
    }
    return $result
}

# helper to turn PSCustomObject into a list of key/value pairs
function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{
            Key = $key; Value = $obj."$key"
        }
    }
}
function Write-ProgressHelper {
    param(
        [int]$StepNumber,
        [string]$Message
    )
    Write-Progress -Activity 'Modifing the Pure Storage SCOM Management Pack' -Status $Message -PercentComplete (($StepNumber / $steps) * 100)
}

function End {
    param (
        $ScriptLog
    )
    if ($ScriptLog) {
        Stop-Transcript
    }
}

<#
.SYNOPSIS
  Enable/Disable logging to array for Systems Center Operations Manager and Pure Storage FlashArray SCOM Management Pack.
.DESCRIPTION
  This script will programatically set the LogToArray parameter in all rules, discoveries, & monitors in the Pure Storage SCOM Management Pack for FlashArray to either true or false. Disabling this logging will reduce the amount of log entries generated on the array by the MP.
.PARAMETER OverridesManagementPackName
    Required. This is the name of the new management pack override necessary to set the new value.
.PARAMETER LogToArray
    Required. Set to "true" or "false".
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
.INPUTS
  None
.OUTPUTS
  Results can also be viewed in the SCOM audit logs.
.EXAMPLE
  Set-LoggingToArray -OverridesManagementPackName "MyOverride" -LogToArray $true -ScriptLog $true
  #>

function Set-LoggingToArray {
    param(
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $true)]
        [bool] $LogToArray,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    if ($LogToArray) {
        $Action = "Enabling"
    }
    else {
        $Action = "Disabling"
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 4 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0
    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }

    Write-ProgressHelper -Message 'Creating Management Pack Override' -StepNumber ($stepCounter++)
    $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Host "Creating management pack $OverridesManagementPackName..."
        CreateManagementPack -Name $OverridesManagementPackName
    }
    Write-ProgressHelper -Message 'Processing Rules' -StepNumber ($stepCounter++)
    Set-RulesLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp

    Write-ProgressHelper -Message 'Processing Discoveries' -StepNumber ($stepCounter++)
    Set-DiscoveriesLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp

    Write-ProgressHelper -Message 'Processing Monitors' -StepNumber ($stepCounter++)
    Set-MonitorsLogToArrayOverrides -ManagementPack $mp -OverridesManagementPack $overrides_mp
    End -ScriptLog $Scriptlog
}

<#
.SYNOPSIS
  Update discovery workflows stored in overrides management pack
.DESCRIPTION
  This script will update code for initial discovery stored in the overrides management pack
.PARAMETER OverridesManagementPackName
    Required. This is the name of the overrides management pack.
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
 EXAMPLE
  Update-Overrides -OverridesManagementPackName "MyOverride"
  #>
function Update-Overrides {
    param (
    # Overrides management pack name
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 3 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0

    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }

    $overrides_mp = Get-SCOMManagementPack -DisplayName $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Error "Failed to find management pack '$OverridesManagementPackName'"
        End -ScriptLog $Scriptlog
        exit
    }

    Write-ProgressHelper -Message 'Inspecting existing management packs' -StepNumber ($stepCounter++)
    $temp_dir = New-TemporaryDirectory
    $overrides_mp | Export-SCManagementPack -Path $temp_dir
    $mp | Export-SCManagementPack -Path $temp_dir

    $mp_xml_path = (Join-Path $temp_dir $mp.Name) + ".xml"
    $mp_xml = Get-Content $mp_xml_path -Raw

    Write-ProgressHelper -Message 'Updating overrides management pack $OverridesManagementPackName' -StepNumber ($stepCounter++)
    $overrides_xml_path = (Join-Path $temp_dir $overrides_mp.Name) + ".xml"
    $overrides_xml = Get-Content $overrides_xml_path -Raw

    $mp_script = Get-InitialDiscoveryScript -content $mp_xml
    $overrides_script = Get-InitialDiscoveryScript -content $overrides_xml

    $overrides_xml = $overrides_xml.Replace($overrides_script, $mp_script)
    # Resolve management pack references
    $overrides_xml = $overrides_xml.Replace("`$Reference/Self`$", "PureStorageFlashArray!")

    Set-Content -Path $overrides_xml_path -Value $overrides_xml

    # Import to SCOM
    Write-Output "Updating management pack $OverridesManagementPackName ..."
    Import-SCOMManagementPack $overrides_xml_path
    Write-Output "Finished updating management pack $OverridesManagementPackName ..."

    Write-ProgressHelper -Message 'Finalizing updates ..' -StepNumber ($stepCounter++)
    # Cleanup
    Remove-Item -Path $temp_dir -Recurse -Force
    End -ScriptLog $Scriptlog
}

<#
.SYNOPSIS
  Creates overrides for overridable configuration parameters
.DESCRIPTION
  This script will create overrides for overridable configuration parameters
.PARAMETER OverridesConfigPath
    Required. Path to JSON file that includes overrides information in the following format:.
    {
    "monitor":  {
        "<monitor name>>":  {
            "<param name>>":  <param value>>,
            ...
        }
        ,
        ....
    },
    "rule":  {
        "<rule name>":  {
            "<param name>>":  <param value>>,
            ...
        },
        .....
    },
    "discovery":  {
        "<discovery name>":  {
            "<param name>>":  <param value>>,
            ...
            }
        },
        ......
    }

    The following is a sample OveridesCOnfig JSON file
    {
    "monitor":  {
        "PureStorageFlashArray.ArrayOPSMonitor.Powershell":  {
            "LogToArray":  false,
            "Threshold":  200
        }
    },
    "rule":  {
        "PureStorage.FlashArray.PureHost.PowerShell.Script.Perf.WriteBandwidth.Rule":  {
            "LogToArray":  true
        }
    },
    "discovery":  {
        "PureStorage.FlashArray.PureArray.Discovery":  {
            "LogToArray":  true
            }
        }
    }

.PARAMETER OverridesManagementPackName
    Required. This is the name of the overrides management pack.
.PARAMETER ScriptLog
    If set to $true, this will enable the PowerShell Start-Transcript cmdlet to log all verbose output. The default log location is in the script root.
.EXAMPLE
  Set-OverridableConfig -OverridesConfigPath "MyConfigOverrides.json"  -OverridesManagementPackName "MyOverridesMP"
 #>

function Set-OverridableConfig {
    param (
        [Parameter(Mandatory = $true)]
        [string] $OverridesConfigPath,
        [Parameter(Mandatory = $true)]
        [string] $OverridesManagementPackName,
        [Parameter(Mandatory = $false)]
        [bool] $Scriptlog
    )

    if ($ScriptLog) {
        $logFile = "$PSScriptRoot\LoggingToArray.txt"
        Start-Transcript -Path $logFile -Append
    }

    Write-Host " "
    Write-host "Beginning processing..."
    Write-Host "Depending on SCOM environment, this may take several minutes to complete."
    Write-Host "Do not close this session until script has finished."
    Write-Host " "
    Start-Sleep 2

    $script:steps = 3 # Number of Write-ProgressHelper commands in this function
    $stepCounter = 0

    $mp = Get-SCOMManagementPack -Name PureStorageFlashArray
    if (!$mp) {
        Write-Error "Failed to find management pack 'PureStorageFlashArray'"
        End -ScriptLog $Scriptlog
        exit
    }
    $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    if (!$overrides_mp) {
        Write-Host "Creating management pack $OverridesManagementPackName..."
        CreateManagementPack -Name $OverridesManagementPackName
        $overrides_mp = Get-SCOMManagementPack -Name $OverridesManagementPackName
    }
    $config = Get-Json -path $OverridesConfigPath
    foreach ($item in $config) {
        foreach ($entityKey in $item.Keys) {
            $entity = $item[$entityKey] | Get-ObjectMembers
            foreach ($scom_entity in $entity) {
                $name = $scom_entity.Key
                $params = $scom_entity.Value | Get-ObjectMembers
                foreach ($param in $params) {
                    $paramName = $param.Key
                    $paramValue = $param.Value
                    # Create overrides
                    switch ($entityKey) {
                        "rule" {
                            Write-ProgressHelper -Message 'Processing Rules' -StepNumber ($stepCounter++)
                            Update-RuleParam -RuleName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                        "discovery" {
                            Write-ProgressHelper -Message 'Processing Discoveries' -StepNumber ($stepCounter++)
                            Update-DiscoveryParam -DiscoveryName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                        "monitor" {
                            Write-ProgressHelper -Message 'Processing Monitors' -StepNumber ($stepCounter++)
                            Update-MonitorParam -MonitorName $name -ParamName $paramName -ParamValue $paramValue -OverridesManagementPack $overrides_mp
                        }
                    }
                }
            }
        }
    }
    End -ScriptLog $Scriptlog
}

Export-ModuleMember -Function Set-LoggingToArray
Export-ModuleMember -Function Update-Overrides
Export-ModuleMember -Function Set-OverridableConfig