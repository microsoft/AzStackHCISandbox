# This script requires that 01_Create_TenantVMs_Complete.ps1, 03.03_Deploy_iDNS.ps1, and 04.02_Create_Appliance_VM.ps1 were
# successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Creates a port mirror between Appliance VM and TenantVM1.   

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

    $uri = $using:uri
    Import-Module NetworkController
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"


    # Get the virtual  network that the Appliance VM\TenantVM1 VM are attached to.

    $vnet = Get-NetworkControllerVirtualNetwork -ConnectionUri $uri -ResourceId "TenantNetwork1"

    # Get the Network Controller network interfaces for the mirroring source and destination by querying for their resource id

    $dstNic = get-networkcontrollernetworkinterface -ConnectionUri $uri -ResourceId "Appliance_Ethernet1"
    $srcNic = get-networkcontrollernetworkinterface -ConnectionUri $uri -ResourceId "TenantVM1_Ethernet1"

    #Create a serviceinsertionproperties object to contain the port mirroring rules and the element which represents the destination interface.

    $portmirror = [Microsoft.Windows.NetworkController.ServiceInsertionProperties]::new()
    $portMirror.Priority = 1


    <#
Create a serviceinsertionrules object to contain the rules that must be matched in order for the traffic to be sent to the appliance.
The rules defined below match all traffic, both inbound and outbound, which represents a traditional mirror. 
You can adjust these rules if you are interested in mirroring a specific port, or specific source/destinations.
In this lab, we just want to look at RDP traffic which is on port 3389.
#>

    $portmirror.ServiceInsertionRules = [Microsoft.Windows.NetworkController.ServiceInsertionRule[]]::new(1)

    $portmirror.ServiceInsertionRules[0] = [Microsoft.Windows.NetworkController.ServiceInsertionRule]::new()
    $portmirror.ServiceInsertionRules[0].ResourceId = "Rule1"
    $portmirror.ServiceInsertionRules[0].Properties = [Microsoft.Windows.NetworkController.ServiceInsertionRuleProperties]::new()

    $portmirror.ServiceInsertionRules[0].Properties.Description = "Port Mirror Rule"
    $portmirror.ServiceInsertionRules[0].Properties.Protocol = "All"
    $portmirror.ServiceInsertionRules[0].Properties.SourcePortRangeStart = "0"
    $portmirror.ServiceInsertionRules[0].Properties.SourcePortRangeEnd = "65535"
    $portmirror.ServiceInsertionRules[0].Properties.DestinationPortRangeStart = "0"
    $portmirror.ServiceInsertionRules[0].Properties.DestinationPortRangeEnd = "65535"
    $portmirror.ServiceInsertionRules[0].Properties.SourceSubnets = "*"
    $portmirror.ServiceInsertionRules[0].Properties.DestinationSubnets = "*"

    # Create a serviceinsertionelements object to contain the network interface of the mirrored appliance.

    $portmirror.ServiceInsertionElements = [Microsoft.Windows.NetworkController.ServiceInsertionElement[]]::new(1)

    $portmirror.ServiceInsertionElements[0] = [Microsoft.Windows.NetworkController.ServiceInsertionElement]::new()
    $portmirror.ServiceInsertionElements[0].ResourceId = "Element1"
    $portmirror.ServiceInsertionElements[0].Properties = [Microsoft.Windows.NetworkController.ServiceInsertionElementProperties]::new()

    $portmirror.ServiceInsertionElements[0].Properties.Description = "Port Mirror Element"
    $portmirror.ServiceInsertionElements[0].Properties.NetworkInterface = $dstNic
    $portmirror.ServiceInsertionElements[0].Properties.Order = 1

    <#
Add the service insertion object in Network Controller.
When you issue this command, all traffic to the appliance network interface specified in the previous step stops.
#>

    $portMirror = New-NetworkControllerServiceInsertion -ConnectionUri $uri -Properties $portmirror -ResourceId "Mirror3389" -Force

    #Update the network interface of the source to be mirrored.

    $srcNic.Properties.IpConfigurations[0].Properties.ServiceInsertion = $portMirror
    $srcNic = New-NetworkControllerNetworkInterface -ConnectionUri $uri  -Properties $srcNic.Properties -ResourceId $srcNic.ResourceId -Force

    #After completing these steps, the Appliance_Ethernet1 interface mirrors traffic from the TenantVM1_Ethernet1 interface.

}


