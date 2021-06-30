# This script requires that 04.02_Create_Port_Mirror.ps1 was successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Removes the Port Mirror created in lab 4.02

   

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

    $uri = $using:uri
    Import-Module NetworkController
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"

    # Get the configuration of the NIC being mirrored
    $srcNic = get-networkcontrollernetworkinterface -ConnectionUri $uri -ResourceId "TenantVM1_Ethernet1"

    # Set the Service Insertion properties to null. (Gets rid of the previous Service Insertion)
    $srcNic.Properties.IpConfigurations[0].Properties.ServiceInsertion = $null

    # Instantiate the new NIC settings.
    $srcNic = New-NetworkControllerNetworkInterface -ConnectionUri $uri  -Properties $srcNic.Properties -ResourceId $srcNic.ResourceId -Force

    # Now that there are no NICs using the Service Insertion (Mirroring) we can delete the insertion.

    Remove-NetworkControllerServiceInsertion -ConnectionUri $uri -ResourceId "Mirror3389" -Force -PassInnerException

}


