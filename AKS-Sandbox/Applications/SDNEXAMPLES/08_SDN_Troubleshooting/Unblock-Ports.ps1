<#

Gets VM NICs and sets the Port Profile to unblock the ports on NC Managed Host. This script needs to be run a host that has
the blocked VM on it.

#>

param([string]$VMName)

#Import Hyper-V Module
Import-Module Hyper-V

#Set Verbose
$VerbosePreference = "Continue"


#Port Profile Settings
$PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
$NcVendorId = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"
$portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId "9940cd46-8b06-43bb-b9d5-93d50381fd56"
$portProfileDefaultSetting.SettingData.ProfileId = "{00000000-0000-0000-0000-000000000000}"
$portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{00000000-0000-0000-0000-000000000000}"
$portProfileDefaultSetting.SettingData.CdnLabelString = "Microsoft"
$portProfileDefaultSetting.SettingData.CdnLabelId = 0
$portProfileDefaultSetting.SettingData.ProfileName = "Microsoft SDN Port"
$portProfileDefaultSetting.SettingData.VendorId = "{1fa41b39-b444-4e43-b35a-e1f7985fd548}"
$portProfileDefaultSetting.SettingData.VendorName = "NetworkController"
$portProfileDefaultSetting.SettingData.ProfileData = "2"


#Get the VMNics
$VMNics = Get-VMNetworkAdapter -VMName $VMName

#Set the extension port feature
Foreach ($VMNic in $VMNics) {
    Try {
        Write-Verbose "Adding VMSwitchExtensionPortFeature on $VMNic"
        Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $VMNic
    }
    Catch {
        throw $_
    }
}