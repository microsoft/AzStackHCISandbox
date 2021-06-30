# This script requires that 01_Create_TenantVMs_Complete.ps1, 03.03_Deploy_iDNS.ps1, and 04.02_Create_Appliance_VM.ps1 were
# successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Creates a User Defined Route   

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

    # create the Route Table object

    $routetableproperties = new-object Microsoft.Windows.NetworkController.RouteTableProperties

    <#/
Add a route to the routing table properties.

Any route not in the same VM subnet (192.172.33.25) gets routed to the Appliance VM at 192.172.33.25.
The appliance must have a virtual network adapter attached to the virtual network with that IP
assigned to a network interface.
 #>

    $route = new-object Microsoft.Windows.NetworkController.Route
    $route.ResourceID = "0_0_0_0_0"
    $route.properties = new-object Microsoft.Windows.NetworkController.RouteProperties
    $route.properties.AddressPrefix = "0.0.0.0/0"
    $route.properties.nextHopType = "VirtualAppliance"
    $route.properties.nextHopIpAddress = "192.172.33.25"  #This is the appliance VM.
    $routetableproperties.routes += $route

    #Add the Route table to Network Controller

    $param = @{

        ConnectionUri = $uri
        Properties    = $routetableproperties 
        ResourceId    = 'Route1'

    }

    $routetable = New-NetworkControllerRouteTable @param -Force

    <#
Here we apply the routing table to the virtual subnet.

When you apply the route table to the virtual subnet, the first virtual subnet in the TenantNetwork1 network 
 uses the route table. You can assign the route table to as many of the subnets in the virtual network as you
 want.
#>

    $vnet = Get-NetworkControllerVirtualNetwork -ConnectionUri $uri -ResourceId "TenantNetwork1"
    $vnet.properties.subnets[0].properties.RouteTable = $routetable

    $param = @{

        ConnectionUri = $uri
        Properties    = $vnet.Properties
        ResourceId    = $vnet.ResourceId

    }
    New-NetworkControllerVirtualNetwork @param -Force

    <#
 As soon as you apply the routing table to the virtual network, traffic gets forwarded to the virtual appliance.
  You must configure the routing table in the virtual appliance to forward the traffic, in a manner that is 
  appropriate for your environment.
 #>


}