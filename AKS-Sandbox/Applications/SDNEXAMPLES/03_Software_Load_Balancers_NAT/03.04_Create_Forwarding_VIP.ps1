# This script requires that 03.01_CreateWebServerVMs.ps1 was successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Creates a Public IP Address.
     2. Attaches Public VIP to WebServerVM2's Network Interfaces.
   

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

# Invoking command as some NC Commands are not working even with the latest RSAT on console. #Needtofix

Invoke-Command -ComputerName $networkcontroller -ScriptBlock {
    
    Import-Module NetworkController

    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"

    $uri = $using:uri



    # Create a Public IP Address

    $publicIPProperties = new-object Microsoft.Windows.NetworkController.PublicIpAddressProperties
    $publicIPProperties.ipaddress = "40.40.40.30"
    $publicIPProperties.PublicIPAllocationMethod = "static"
    $publicIPProperties.IdleTimeoutInMinutes = 4

    $param = @{

        ResourceID    = 'ForwardingIP'
        Properties    = $publicIPProperties
        ConnectionUri = $uri

    }

    $publicIP = New-NetworkControllerPublicIpAddress @param -Force -PassInnerException


    $nic = get-networkcontrollernetworkinterface  -connectionuri $uri -resourceid WebServerVM2_Ethernet1
    $nic.properties.IpConfigurations[0].Properties.PublicIPAddress = $publicIP

    $param = @{

        ConnectionUri = $uri
        ResourceId    = $nic.ResourceId
        Properties    = $nic.Properties

    }

    New-NetworkControllerNetworkInterface @param -PassInnerException -Confirm:$false -Force


}


