# This script requires that 01_Create_TenantVMs_Complete.ps1, 03.03_Deploy_iDNS.ps1, and 04.02_Create_Appliance_VM.ps1 were
# successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Removes a User Defined Route   

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
$networkcontroller = "NC01.$($SDNConfig.SDNDomainFQDN)"

Invoke-Command -ComputerName $networkcontroller -ScriptBlock {

    Import-Module NetworkController
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"

    $uri = $using:uri


    # Remove Route Table from Virtual Network by setting the RouteTable property to null

    $vnet = Get-NetworkControllerVirtualNetwork -ConnectionUri $uri -ResourceId "TenantNetwork1"
    $vnet.properties.subnets[0].properties.RouteTable = $null

    $param = @{

        ConnectionUri = $uri
        Properties    = $vnet.Properties
        ResourceId    = $vnet.ResourceId

    }
    New-NetworkControllerVirtualNetwork @param -Force

    # Remove Route Table

    $param = @{

        ConnectionUri = $uri
        ResourceId    = 'Route1'

    }

    Remove-NetworkControllerRouteTable @param -Force

}