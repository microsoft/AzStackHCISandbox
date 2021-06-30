# Version 1.0

<#
.SYNOPSIS 

    This script:

     1. This script will create IPSEC Gateway Network Connection to the ipsec-target VM as well as peer the 
        connection to a BGP router that is located on the ipsec-target virtual machine. After this script is run, you 
        should be able to connect to resources on the Management Network. You will have to configure iDNS 
        (script is available) if you want to perform functions such as joining the domain, etc.
    
     2. Assumes that you have the defaults in your configuration file for the GRE network and Management Network.
        You can change the properties below to fit your deployment of the SDN Sandbox.

     3. Assumes that you have not deployed any other Gateways to the active Gateway VM.

     4. Assumes that you have deployed TenantVM1 and TenantVM2 as well as attached them to a VM Network.

    I have tried to comment as much as possible in this script on the parameters network controller requires
    in order to create a GRE connection. Email sdnblackbelt@microsoft.com if you require any clarification or have 
    questions regarding GRE Gateways. 

    After running this script, follow the directions in the README.md file for this scenario.
#>


[CmdletBinding(DefaultParameterSetName = "NoParameters")]

param(

    [Parameter(Mandatory = $true, ParameterSetName = "ConfigurationFile")]
    [String] $ConfigurationDataFile = 'C:\SCRIPTS\AzSHCISandbox-Config.psd1'

)

$VerbosePreference = "SilentlyContinue"
Import-Module NetworkController

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Load in the configuration file.
$SDNConfig = Import-PowerShellDataFile $ConfigurationDataFile
if (!$SDNConfig) { Throw "Place Configuration File in the root of the scripts folder or specify the path to the Configuration file." }


# Set Connection IPs
####################

$uri = "https://NC01.$($SDNConfig.SDNDomainFQDN)"  # This is the URI for Network Controller
$VMNetwork = "TenantNetwork1"                      # This is the VM Network that will used for the IPSEC Gateway
$VMSubnet = "TenantSubnet1"                        # This is the VM Subnet that will use the L3 Gateway
$vGatewayName = "IPSECGateway"                     # Name that will be used for the Gateway resource ID. This can be any string.
$gwConnectionName = "IKEv2Connection"              # Name that will be used for the Gateway Connection that will be created for the L3 Gateway. This can be any string.
$Secret = "Password01"                             # Ensure that this key matches the key in script:
$ikeIP = "131.127.0.30"                            # This is the external endpoint that the GW is going to connect to. Usually this would be a public internet address.


# Routes
########

# These are the routes that ONLY will be routable OUT of the VM Nework through the IPSEC Gateway
# You can put 0.0.0.0/0 to route all broadcast traffic if required.

$ipv4RouteDestPrefixes = @("192.168.111.0/24")      # This is the subnet on the remote site that the Gateway will pass traffic too.


# BGP  Information
########################
$intBGPASN = 05666            # This is the internal BGP ASN that the GW will use for it's BGP Router
$extBGPASN = 64525           # This is the BGP ASN of the EXTERNAL BGP server that the GW will be connecting to.
$intBGPIP = '192.172.33.6'    # This is the IP Address of the INTERNAL BGP Server that the remote VPN server will connect to.
$extBGPIP = '192.168.111.100' # This is the IP Address of the EXTERNAL BGP Server that the GW will be connecting to.

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


###############################################
#  Creating IPSEC VPN S2S Network Connection  #
###############################################


# Create a new object for Tenant Network Connection  
$nwConnectionProperties = New-Object Microsoft.Windows.NetworkController.NetworkConnectionProperties   

# Update the common object properties  
$nwConnectionProperties.ConnectionType = "IPSec"   
$nwConnectionProperties.OutboundKiloBitsPerSecond = 500   
$nwConnectionProperties.InboundKiloBitsPerSecond = 500  


# Update specific properties depending on the connection type
$nwConnectionProperties.IpSecConfiguration = New-Object Microsoft.Windows.NetworkController.IpSecConfiguration
$nwConnectionProperties.IpSecConfiguration.AuthenticationMethod = "PSK"
$nwConnectionProperties.IpSecConfiguration.SharedSecret = $Secret
$nwConnectionProperties.IpSecConfiguration.QuickMode = New-Object Microsoft.Windows.NetworkController.QuickMode 
$nwConnectionProperties.IpSecConfiguration.QuickMode.PerfectForwardSecrecy = "PFS2"
$nwConnectionProperties.IpSecConfiguration.QuickMode.AuthenticationTransformationConstant = "SHA196"
$nwConnectionProperties.IpSecConfiguration.QuickMode.CipherTransformationConstant = "AES256" 
$nwConnectionProperties.IpSecConfiguration.QuickMode.SALifeTimeSeconds = 3600
$nwConnectionProperties.IpSecConfiguration.QuickMode.IdleDisconnectSeconds = 300
$nwConnectionProperties.IpSecConfiguration.QuickMode.SALifeTimeKiloBytes = 102400

$nwConnectionProperties.IpSecConfiguration.MainMode = New-Object Microsoft.Windows.NetworkController.MainMode 
$nwConnectionProperties.IpSecConfiguration.MainMode.DiffieHellmanGroup = "Group2" 
$nwConnectionProperties.IpSecConfiguration.MainMode.IntegrityAlgorithm = "SHA1" 
$nwConnectionProperties.IpSecConfiguration.MainMode.EncryptionAlgorithm = "AES256" 
$nwConnectionProperties.IpSecConfiguration.MainMode.SALifeTimeSeconds = 28800
$nwConnectionProperties.IpSecConfiguration.MainMode.SALifeTimeKiloBytes = 819200


# Update the IPv4 Routes that are reachable over the site-to-site VPN Tunnel  
$nwConnectionProperties.Routes = @()   
$ipv4Route = New-Object Microsoft.Windows.NetworkController.RouteInfo   
$ipv4Route.DestinationPrefix = $ipv4RouteDestPrefixes   
$ipv4Route.metric = 10   
$nwConnectionProperties.Routes += $ipv4Route   

# Tunnel Destination (Remote Endpoint) Address  
$nwConnectionProperties.DestinationIPAddress = $ikeIP   

# Add the new Network Connection for the tenant 

$params = @{

    ConnectionUri    = $uri
    VirtualGatewayId = $virtualGW.ResourceId
    ResourceId       = $gwConnectionName
    Properties       = $nwConnectionProperties

}

 
New-NetworkControllerVirtualGatewayNetworkConnection @params -Force

#####################
### Configure BGP ###
#####################

# Create a new object for the Tenant BGP Router  
$bgpRouterproperties = New-Object Microsoft.Windows.NetworkController.VGwBgpRouterProperties   

# Update the BGP Router properties  
$bgpRouterproperties.ExtAsNumber = "0.$intBGPASN"   
$bgpRouterproperties.RouterId = $intBGPIP   
$bgpRouterproperties.RouterIP = @($intBGPIP)
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
    ResourceID       = 'IPSEC_Peer'
    Properties       = $bgpPeerProperties

}

New-NetworkControllerVirtualGatewayBgpPeer @params -Force -PassInnerException



# Remove-NetworkControllerVirtualGateway -ConnectionUri $uri -ResourceId $virtualGW.ResourceId
