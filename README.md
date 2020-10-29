## Pure Storage FlashArray SCOM Scripts and Utilities

These scripts and utilities are intended to assist Pure Storage customers and SCOM administrators with Management Pack Rules, Monitors, Discoveries, and Overrides.
*We encourage Pull requests for this repository to further enhance the code and give back to the community.*
Reach out to openconnect@purestorage.com if you have any questions.
Be sure to join or Code Slack Team as well at https://codeinvite.purestorage.com

**PureStorage-utils.psm1**

A collection helper functions to facilitate managing Pure Storage Management Pack Overrides. Functions included:

 - `Set-LoggingToArray` - Enable/Disable logging to array for Systems Center Operations Manager and Pure Storage FlashArray SCOM Management Pack.
 - `Set-OverrideableConfig` - Create overrides for overridable configuration parameters
 - `Update-Overrides` -  Update discovery workflows stored in overrides management pack