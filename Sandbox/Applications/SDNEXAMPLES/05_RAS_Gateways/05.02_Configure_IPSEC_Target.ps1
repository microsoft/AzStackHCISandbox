###################################
# Fill in the following variables #
###################################

###################################
## S2S VPN Interface Information ##
###################################

$ConnectionName = 'ipsecdemo'
$Destination = '40.40.40.1'   # This is the Public VIP of the Gateway. This is the sourceIPAddress from https://<NC>/networking/v1/virtualgateways 
$IPv4Subnet = '192.172.33.6'  # This is the routerId from https://<NC>/networking/v1/virtualgateways 
$SharedSecret = 'Password01'

###########################
## BGP\Route Information ##
###########################

$DestinationPrefix = '40.40.40.0/24' # Subnet that the Destination Public VIP is on.
$NextHop = '131.127.0.1'             # Gateway that can route to the Public VIP
$InterfaceAlias = 'Internet'         # Interface to route the Next Hop through
$LocalIPAddress = '192.168.111.100'  # Address of the local BGP router.
$LocalASN = 64525                    # ASN of the BGP Router installed on the ipsec-target virtual machine
$PeerASN = 5666                      # ASN of the Gateway the ipsec-target virtual machine is peering with


# Set the VPN Connection. Here we are going to create a connection to the RAS Gateway that was just created.
# Ensure that the IPSEC Policy parameters match the RAS Gateway that was created.

$params = @{

     Name                             = $ConnectionName
     Destination                      = $Destination
     Protocol                         = 'IKEv2'
     AuthenticationMethod             = 'PSKOnly'
     SharedSecret                     = $SharedSecret
     IPv4Subnet                       = "$IPv4Subnet/32:10"
     AuthenticationTransformConstants = "SHA196"
     CipherTransformConstants         = 'AES256'
     DHGroup                          = 'Group2'
     EncryptionMethod                 = 'AES256'
     IntegrityCheckMethod             = 'SHA1'
     PfsGroup                         = 'PFS2'
     SALifeTimeSeconds                = 28800
     IdleDisconnectSeconds            = 500

}

Add-VpnS2SInterface @params -CustomPolicy 


<# Here we are going to set a static route which allows us to route the 
     to the IPSec connection's public VIP so we can communicate back and
     forth with the RAS Gateway. This would not be necessary if we used 
     BGP #>


$params = @{

     DestinationPrefix = $DestinationPrefix
     NextHop           = $NextHop
     InterfaceAlias    = $InterfaceAlias

}

New-NetRoute @params


# Peer BGP Routers

$params = @{

     Name           = $ConnectionName
     LocalIPAddress = $LocalIPAddress
     PeerIPAddress  = $IPv4Subnet
     LocalASN       = $LocalASN
     PeerASN        = $PeerASN
     OperationMOde  = 'Mixed'
     PeeringMode    = 'Automatic'

}

Add-BgpPeer @params