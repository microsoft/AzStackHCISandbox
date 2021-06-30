# Version 2.0 - Create-L3_Gateway

<#
.SYNOPSIS 

    This script:

     1. This script should be run on the AdminCen VM with the user logged on as Domain\Administrator 

     2. This script will create a L3 Gateway Network Connection to VLAN 200 as well as peer the L3 connection
        to a BGP router that is located on the AdminCenter virtual machine. After this script is run, you 
        should be able to connect to resources on the Management Network. You will have to configure iDNS 
        (script is available) if you want to perform functions such as joining the domain, etc.
    
     3. Assumes that you have the defaults in your configuration file for the VLAN200 network and Management Network.
        You can change the properties below to fit your deployment of the SDN Sandbox.

     4. Assumes that you have not deployed any other Gateways to the GatewayVM.

     5. Assumes that you have deployed TenantVM1 and TenantVM2 as well as attached them to a VM Network.

.NOTES

    I have tried to comment as much as possible in this script on the parameters network controller requires
    in order to create a L3 connection. Email sdnblackbelt@microsoft.com if you require any clarification or have 
    questions regarding L3 Gateways.

    To remove this configuration, run the Destroy-L3_sample.ps1 script. 

#>


[CmdletBinding(DefaultParameterSetName = "NoParameters")]

param(

    [Parameter(Mandatory = $true, ParameterSetName = "ConfigurationFile")]
    [String] $ConfigurationDataFile = 'C:\SCRIPTS\AzSHCISandbox-Config.psd1'

)



Import-Module NetworkController

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Load in the configuration file.
$SDNConfig = Import-PowerShellDataFile $ConfigurationDataFile
if (!$SDNConfig) { Throw "Place Configuration File in the root of the scripts folder or specify the path to the Configuration file." }

# Set Credential Object

$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "administrator", (ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)


# Set Connection IPs
####################

$uri = "https://NC01.$($SDNConfig.SDNDomainFQDN)"  # This is the URI for Network Controller
$VMNetwork = "TenantNetwork1"                      # This is the VM Network that will use the L3 Gateway
$VMSubnet = "TenantSubnet1"                        # This is the VM Subnet that will use the L3 Gateway
$vGatewayName = "L3Connection"                     # Name that will be used for the Gateway resource ID. This can be any string.
$vLogicalNetName = "VLAN_200_Network"              # Name that will be used for the Logical Network that will be created for the L3 Gateway. This can be any string.
$vLogicalSubnetName = "VLAN_200_Subnet"            # Name that will be used for the Logical Subnet that will be created for the L3 Gateway. This can be any string.
$gwConnectionName = "L3GW"                         # Name that will be used for the Gateway Connection that will be created for the L3 Gateway. This can be any string.


# L3 IP Configuration
#####################

$targetVLANsubnet = "192.168.200.0/24"             # This is the VLAN subnet that your VM Network is going to attach to.
$targetVLANGateway = "192.168.200.1"               # This is the default gateway of the VLAN subnet that your VM Network is going to attach to. It already must exist.
$targetVLANid = 200                                # This is the VLAN ID of the VLAN subnet that your VMNetwork is going to attach to.
$vmNetworkEndpoint = "192.168.200.254/24"          <# This is the IP Address on the VLAN subnet that the SDN Gateway will use to route traffic between the VM Network and the 
                                                      physical network. You will need to ensure that this address is not already in use.#>

# Routes
########
# These are the routes that ONLY will be routable OUT of the VM Nework through the L3 Gateway

$ipv4RouteDestPrefixes = @("192.168.1.0/24")      # This is the route for the Management Network.


# BGP
#####

$configureBGP = $true                               # Specifies whether or not to configure BGP for the L3 Connection in this sample.
$intBGPASN = "64513"                                # This BGP ASN is the BGP Router the ASN of the L3 Connection.
$intBGPName = "L3BGP"                               # This is a string name value to assign as the Resource ID for the L3 BGP Router Peering Connection. This can be any string.
$intBGPResourceID = "BgpRouterL3"                   # This is a string name value to assign as the Resource ID for the L3 BGP Router. This can be any string.
$extBGPASN = "65533"                                # THis BGP ASN is the ASN for the BGP Router the L3 Connection will connect to. In this example, it is the BGP Router on the ADMINCENTER VM.
$extBGPIP = "192.168.1.9"                           # This IP address is the address of the BGP Router that the L3 connection will peer with.
$bgpRouterID = "192.172.33.2"                       # IP Address from the VM Network that the Gateway is using to bridge between the VM Network and the L3 Connection.


#########################
#  Creating the Gateway #
######################### 

# Retrieve the Gateway Pool configuration  

$gwPool = Get-NetworkControllerGatewayPool -ConnectionUri $uri 

 
# Retrieve the Tenant Virtual Network configuration  

$Vnet = Get-NetworkControllerVirtualNetwork -ConnectionUri $uri  -ResourceId $VMNetwork


# Retrieve the Tenant Virtual Subnet configuration 
 
$RoutingSubnet = Get-NetworkControllerVirtualSubnet -ConnectionUri $uri  -ResourceId $VMSubnet -VirtualNetworkID $vnet.ResourceId   


# Create a new object for Tenant Virtual Gateway 
 
$VirtualGWProperties = New-Object Microsoft.Windows.NetworkController.VirtualGatewayProperties   
  
# Update Gateway Pool reference 
 
$VirtualGWProperties.GatewayPools = @()   
$VirtualGWProperties.GatewayPools += $gwPool   
  
# Specify the Virtual Subnet that is to be used for routing between the gateway and Virtual Network
   
$VirtualGWProperties.GatewaySubnets = @()   
$VirtualGWProperties.GatewaySubnets += $RoutingSubnet 
  
# Update the rest of the Virtual Gateway object properties
  
$VirtualGWProperties.RoutingType = "Dynamic"   
$VirtualGWProperties.NetworkConnections = @()   
$VirtualGWProperties.BgpRouters = @()   
  
# Add the new Virtual Gateway for tenant

$params = @{

    ConnectionUri = $uri
    ResourceId    = $vGatewayName
    Properties    = $VirtualGWProperties

}
  
$virtualGW = New-NetworkControllerVirtualGateway @params -Force

# For a L3 forwarding network connection to work properly, you must configure a corresponding logical network. 

# Create a new object for the Logical Network to be used for L3 Forwarding
  
$lnProperties = New-Object Microsoft.Windows.NetworkController.LogicalNetworkProperties  

$lnProperties.NetworkVirtualizationEnabled = $false  
$lnProperties.Subnets = @()  

# Create a new object for the Logical Subnet to be used for L3 Forwarding and update properties  

$logicalsubnet = New-Object Microsoft.Windows.NetworkController.LogicalSubnet  
$logicalsubnet.ResourceId = $vLogicalSubnetName
$logicalsubnet.Properties = New-Object Microsoft.Windows.NetworkController.LogicalSubnetProperties  
$logicalsubnet.Properties.VlanID = $targetVLANid
$logicalsubnet.Properties.AddressPrefix = $targetVLANsubnet 
$logicalsubnet.Properties.DefaultGateways = $targetVLANGateway  

$lnProperties.Subnets += $logicalsubnet  

# Add the new Logical Network to Network Controller

$params = @{

    ConnectionUri = $uri
    ResourceId    = $vLogicalNetName
    Properties    = $lnProperties

}
  
$vlanNetwork = New-NetworkControllerLogicalNetwork @params -Force  

# Create a Network Connection JSON Object and add it to Network Controller.
###########################################################################

# Create a new object for the Tenant Network Connection  
$nwConnectionProperties = New-Object Microsoft.Windows.NetworkController.NetworkConnectionProperties   

# Update the common object properties  
$nwConnectionProperties.ConnectionType = "L3"   
$nwConnectionProperties.OutboundKiloBitsPerSecond = 10000   
$nwConnectionProperties.InboundKiloBitsPerSecond = 10000   

# GRE specific configuration (leave blank for L3)  
$nwConnectionProperties.GreConfiguration = New-Object Microsoft.Windows.NetworkController.GreConfiguration   

# Update specific properties depending on the Connection Type  
$nwConnectionProperties.L3Configuration = New-Object Microsoft.Windows.NetworkController.L3Configuration   
$nwConnectionProperties.L3Configuration.VlanSubnet = $vlanNetwork.properties.Subnets[0]   

$nwConnectionProperties.IPAddresses = @()   
$localIPAddress = New-Object Microsoft.Windows.NetworkController.CidrIPAddress   
$localIPAddress.IPAddress = $vmNetworkEndpoint.Split("/")[0]   
$localIPAddress.PrefixLength = $vmNetworkEndpoint.Split("/")[1]    
$nwConnectionProperties.IPAddresses += $localIPAddress   

$nwConnectionProperties.PeerIPAddresses = @("$targetVLANGateway")  


# Set the routes

$nwConnectionProperties.Routes = @()  

foreach ($ipv4RouteDestPrefix in $ipv4RouteDestPrefixes) {

    $ipv4Route = New-Object Microsoft.Windows.NetworkController.RouteInfo
    $ipv4Route.DestinationPrefix = $ipv4RouteDestPrefix  
    $ipv4Route.metric = 256  
    $nwConnectionProperties.Routes += $ipv4Route   

}


# Add the new Network Connection for the tenant  


$params = @{

    ConnectionUri    = $uri
    VirtualGatewayId = $virtualGW.ResourceId
    ResourceID       = $gwConnectionName
    Properties       = $nwConnectionProperties

}

New-NetworkControllerVirtualGatewayNetworkConnection @params -Force


if ($configureBGP) {

    ### Configure BGP

    # Create a new object for the Tenant BGP Router  
    $bgpRouterproperties = New-Object Microsoft.Windows.NetworkController.VGwBgpRouterProperties   

    # Update the BGP Router properties  
    $bgpRouterproperties.ExtAsNumber = "0.$intBGPASN"   
    $bgpRouterproperties.RouterId = $bgpRouterID   
    $bgpRouterproperties.RouterIP = @("$bgpRouterID")
    $bgpRouterproperties.IsEnabled = $true  

    # Add the new BGP Router for the tenant  

    $params = @{
    
        ConnectionUri    = $uri
        VirtualGatewayID = $virtualGW.ResourceId
        ResourceID       = $intBGPResourceID
        Properties       = $bgpRouterproperties
    
    }

    $bgpRouter = New-NetworkControllerVirtualGatewayBgpRouter @params -Force

    # Add the BGPPeer (Which will be the BGP-ToR-Router VM)

    # Create a new object for Tenant BGP Peer  
    $bgpPeerProperties = New-Object Microsoft.Windows.NetworkController.VGwBgpPeerProperties   

    # Update the BGP Peer properties  
    $bgpPeerProperties.PeerIpAddress = $extBGPIP  
    $bgpPeerProperties.AsNumber = $extBGPASN   
    $bgpPeerProperties.ExtAsNumber = "0.$extBGPASN"   

    # Add the new BGP Peer for tenant

    $params = @{

        ConnectionUri    = $uri
        VirtualGatewayID = $virtualGW.ResourceId
        BGPRouterName    = $bgpRouter.ResourceId
        ResourceID       = $intBGPName
        Properties       = $bgpPeerProperties

    }

    New-NetworkControllerVirtualGatewayBgpPeer @params -Force

}

<#######################################
# Set Routing on the Physical Network  #
########################################

Now that we have our L3 Gateway setup, we need to configure the following:

   We need to add a static route to the Top of Rack Switch so that the switch "knows" how to find the 
   router to the VM Network's IP address range or (if we are using BGP with the L3 Connection) how to 
   get to the Router IP (in this example: 192.172.33.2) so that we can peer an External BGP router.
   In this example, we are going to make a call to the BGP-ToR-Router to add the necessary routes

#>


### Set the BGP-ToR-Router to be able to router to the VM Network via the VLAN 200 endpoint

Write-Verbose "Configuring Static Route to VMNetwork on the BGP-ToR-Router"

# Set VM Network's subnet:

$DestinationPrefix = $Vnet[0].Properties.Subnets.properties.AddressPrefix

# Set the Next Hop

$NextHop = $vmNetworkEndpoint.Split("/")[0]

# Set the BGP Router IP

$routerIP = $SDNConfig.BGPRouterIP_MGMT.Split("/")[0]


Invoke-Command -ComputerName $routerIP -Credential $localCred  -ScriptBlock {


    $params = @{

        DestinationPrefix = $using:DestinationPrefix
        AddressFamily     = 'IPv4'
        NextHop           = $using:NextHop
        InterfaceAlias    = 'VLAN200'

    }


    New-NetRoute @params


}

if ($configureBGP) {

    <# 
######################
# Set L3 BGP Peering #
######################

If BGP is going to be enabled on this sample, we will use a BGP Router located on the Adminhost VM.
Please note that this is only an example of on how to connect to a BGP Router through an L3 connection
and that no routes will be added to the BGP router. In a production environment, you would be using 
a physical router\switch and you would have to add the peering information according to the router\switch
vendor's instructions.

#>

    Write-Verbose "Setting up L3 BGP Peering"



    $params = @{

        Name           = 'L3Connection'
        LocalIPAddress = $extBGPIP
        PeerIPAddress  = $bgpRouterID
        LocalASN       = $extBGPASN
        PeerASN        = $intBGPASN
        OperationMode  = 'Mixed'
        PeeringMode    = 'Automatic' 

    }

    Add-BgpPeer @params


}



<#
##############
# Validation #
##############

In this section, we are going to run through some validation tests to automatically ensure that everything is working correctly
In our configuration.

#>

$VerbosePreference = "SilentlyContinue"

# Validate Network Controller Virtual Gateway

$params = @{

    ConnectionUri = $uri
    ResourceId    = $vGatewayName

}

$virtGatewayStatus = Get-NetworkControllerVirtualGateway @params

Write-Host "`n`n"
Write-Host "Virtual Gateway $($virtGatewayStatus.ResourceId) Status" -ForegroundColor Yellow
Write-Host "`nVirtual Gateway $($virtGatewayStatus.ResourceId)'s Provisioning State: $($virtGatewayStatus.Properties.ProvisioningState)"
Write-Host "Virtual Gateway $($virtGatewayStatus.ResourceId)'s Configuration State: $($virtGatewayStatus.Properties.ConfigurationState.Status)"


# Validate Network Controller Logical Network

$params = @{

    ConnectionUri = $uri
    ResourceId    = $vLogicalNetName

}

$gwLNStatus = Get-NetworkControllerLogicalNetwork @params

Write-Host "`n`nLogical Network $($gwLNStatus.ResourceId) Status" -ForegroundColor Yellow
Write-Host "`nLogical Network $($gwLNStatus.ResourceId)'s Provisioning State: $($gwLNStatus.Properties.ProvisioningState)"
Write-Host "Logical Network $($gwLNStatus.ResourceId)'s Subnet $($gwLNStatus.Properties.Subnets[0].ResourceId)'s Provisioning State: $($gwLNStatus.Properties.Subnets[0].Properties.ProvisioningState)"


# Validate Network Controller Virtual Gateway Network Connection

$params = @{

    ConnectionUri    = $uri
    VirtualGatewayId = $virtualGW.ResourceId
    ResourceID       = $gwConnectionName


}

$gwConnectStatus = Get-NetworkControllerVirtualGatewayNetworkConnection @params 
Write-Host "`n`nVirtual Gateway Network Connection $($gwConnectStatus.ResourceId) Status" -ForegroundColor Yellow
Write-Host "`nVirtual Gateway Network Connection $($gwConnectStatus.ResourceId)`s Provisioning State: $($gwConnectStatus.Properties.ProvisioningState)"
Write-Host "Virtual Gateway Network Connection $($gwConnectStatus.ResourceId)`s ConfigurationState: $($gwConnectStatus.Properties.ConfigurationState.Status)"
Write-Host "Virtual Gateway Network Connection $($gwConnectStatus.ResourceId)`s ConnectionState: $($gwConnectStatus.Properties.ConnectionState)"
Write-Host "Virtual Gateway Network Connection $($gwConnectStatus.ResourceId)`s ConnectionStatus: $($gwConnectStatus.Properties.ConnectionStatus)"

if ($configureBGP) {

    # Validate BGP Router Status

    $params = @{

        ConnectionUri    = $uri
        VirtualGatewayId = $virtualGW.ResourceId
        ResourceID       = $intBGPResourceID

    }


    $bgpStatus = Get-NetworkControllerVirtualGatewayBgpRouter @params

    Write-Host "`n`nBGP Router $($bgpStatus.ResourceId) Status" -ForegroundColor Yellow
    Write-Host "`nBGP Router $($bgpStatus.ResourceId)'s Provisioning State: $($bgpStatus.Properties.ProvisioningState)"
    Write-Host "BGP Router $($bgpStatus.ResourceId)'s Configuration State: $($bgpStatus.Properties.ConfigurationState.Status)"

    # Validate BGP Peer Status

    $params = @{

        ConnectionUri    = $uri
        VirtualGatewayId = $virtualGW.ResourceId
        BgpRouterName    = $bgpRouter.ResourceId
        ResourceId       = $intBGPName

    }

    $bgpPeerStatus = NetworkControllerVirtualGatewayBgpPeer @params

    Write-Host "`n`nBGP Peer $($bgpPeerStatus.ResourceId) Status" -ForegroundColor Yellow
    Write-Host "`nBGP Peer $($bgpPeerStatus.ResourceId)'s Provisioning State: $($bgpPeerStatus.Properties.ProvisioningState)"
    Write-Host "BGP Peer $($bgpPeerStatus.ResourceId)'s Connection State: $($bgpPeerStatus.Properties.ConnectionState)"

}


# Ping Tests to Tenant VM1 

Write-Host "`n`nTesting Connection to TenantVM1..." -ForegroundColor Yellow
$TenantVM1Connection = Test-Connection -Quiet -Count 10 -ComputerName 192.172.33.4

if ($TenantVM1Connection) { Write-Host "`nSuccess" -ForegroundColor Green }
else { Write-Host "`nFailed" -ForegroundColor Red }

  