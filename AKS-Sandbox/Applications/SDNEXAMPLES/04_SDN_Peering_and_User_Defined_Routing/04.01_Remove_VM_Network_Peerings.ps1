# This script requires that 04.01_Peer_VM_Networks.ps1 was successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Removes the network peerings created in lab 04.01.  

    After running this script, follow the directions in the README.md file for this scenario.
#>

[CmdletBinding(DefaultParameterSetName = "NoParameters")]

param(

    [Parameter(Mandatory = $true, ParameterSetName = "ConfigurationFile")]
    [String] $ConfigurationDataFile = 'C:\SCRIPTS\AzSHCISandbox-Config.psd1'

)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Load in the configuration file.

$SDNConfig = Import-PowerShellDataFile $ConfigurationDataFile
if (!$SDNConfig) { Throw "Place Configuration File in the root of the scripts folder or specify the path to the Configuration file." }
$uri = "https://NC01.$($SDNConfig.SDNDomainFQDN)"

# Remove Network Peerings

Remove-NetworkControllerVirtualNetworkPeering -ConnectionUri $uri -ResourceId 'TenantNetwork1-to-webNetwork1' -VirtualNetworkId TenantNetwork1 -Force
Remove-NetworkControllerVirtualNetworkPeering -ConnectionUri $uri -ResourceId 'webNetwork1-to-TenantNetwork1' -VirtualNetworkId webNetwork1 -Force

