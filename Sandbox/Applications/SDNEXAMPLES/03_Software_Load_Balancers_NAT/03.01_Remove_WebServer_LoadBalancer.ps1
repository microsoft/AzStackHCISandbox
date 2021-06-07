# This script requires that 03.01_LoadBalanceWebServerVMs.ps1 was successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Removes the load balancer WEBLB
     2. Removes the WEBLB-IP Public IP address.
   

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

# Remove the Load Balancer
Remove-NetworkControllerLoadBalancer -ResourceId "WEBLB" -ConnectionUri $uri -Force
Remove-NetworkControllerPublicIpAddress -ResourceId WEBLB-IP -ConnectionUri $uri -Force