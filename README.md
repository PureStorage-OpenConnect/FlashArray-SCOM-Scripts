# Pure Storage FlashArray SCOM Scripts and Utilities

These scripts and utilities are intended to assist Pure Storage customers and SCOM administrators with Management Pack Rules, Monitors, Discoveries, and Overrides.
*We encourage Pull requests for this repository to further enhance the code and give back to the community.*
Reach out to fa-solutions@purestorage.com if you have any questions.
Be sure to join the [Code Slack Team](https://codeinvite.purestorage.com)

## Test-PureSCOMSettings.ps1

This diagnostic script runs various tests to ensure a proper Management Pack configuration as well as tests connectivity to an array. This script must run on a SCOM Management Server.

## PureStorage-utils.psm1

A collection helper functions to facilitate managing Pure Storage Management Pack Overrides. Functions included:

* `Set-LoggingToArray` - Enable/Disable logging to array for Systems Center Operations Manager and Pure Storage FlashArray SCOM Management Pack. *
* `Set-OverrideableConfig` - Create overrides for overridable configuration parameters *
* `Update-Overrides` -  Update discovery workflows stored in overrides management pack *
