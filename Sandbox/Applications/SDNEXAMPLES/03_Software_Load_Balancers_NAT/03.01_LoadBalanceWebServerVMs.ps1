# This script requires that 03.01_CreateWebServerVMs.ps1 was successfully run from the console vm.
# Version 2.0

<#
.SYNOPSIS 

    This script:
    
     1. Creates a load balancer named WEBLB that attaches to  WebServerVM1 and WebServerVM2's NIC Interfaces.
     2. Creates Rules to let port 80 (http) and port 3389 (RDP) into load balancer.
   

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


    # Load Balancer Name

    $ResourceID = 'WEBLB'

        
    # Create VIP (Public IP)

    $publicIPProperties = new-object Microsoft.Windows.NetworkController.PublicIpAddressProperties
    $publicIPProperties.PublicIPAllocationMethod = "dynamic"
    $publicIPProperties.IdleTimeoutInMinutes = 4

    $param = @{

        ResourceId    = "WEBLB-IP" 
        Properties    = $publicIPProperties
        ConnectionUri = $uri

    }

    $publicIP = New-NetworkControllerPublicIpAddress @param -force
        

    # Clear variables

    $LoadBalancerProperties = $null
    $FrontEnd = $null
    $BackEnd = $null
    $lbrule = $null

    # Set Variables

    $FrontEndName = "DefaultAll"
    $BackendName = "Backend1"

    $LoadBalancerProperties = new-object Microsoft.Windows.NetworkController.LoadBalancerProperties

    # Create a front-end IP configuration

    $LoadBalancerProperties.frontendipconfigurations += $FrontEnd = new-object Microsoft.Windows.NetworkController.LoadBalancerFrontendIpConfiguration
    $FrontEnd.properties = new-object Microsoft.Windows.NetworkController.LoadBalancerFrontendIpConfigurationProperties
    $FrontEnd.resourceId = $FrontEndName
    $FrontEnd.ResourceRef = "/loadbalancers/$Resourceid/frontendipconfigurations/$FrontEndName"
    $FrontEnd.properties.PublicIPAddress = $PublicIP

    # Create a back-end address pool

    $BackEnd = new-object Microsoft.Windows.NetworkController.LoadBalancerBackendAddressPool
    $BackEnd.properties = new-object Microsoft.Windows.NetworkController.LoadBalancerBackendAddressPoolProperties
    $BackEnd.resourceId = $BackendName
    $BackEnd.ResourceRef = "/loadbalancers/$Resourceid/BackEndAddressPools/$BackendName"
    $LoadBalancerProperties.backendAddressPools += $BackEnd

    # Create the Load Balancing Rules

    # This rule will allow port 80 traffic going to the VIP through to the one of the Web Servers.

    $LoadBalancerProperties.loadbalancingRules += $lbrule = new-object Microsoft.Windows.NetworkController.LoadBalancingRule
    $lbrule.properties = new-object Microsoft.Windows.NetworkController.LoadBalancingRuleProperties
    $lbrule.ResourceId = "webserver1"
    $lbrule.properties.frontendipconfigurations += $FrontEnd
    $lbrule.properties.backendaddresspool = $BackEnd 
    $lbrule.properties.protocol = "TCP"
    $lbrule.properties.frontendPort = 80
    $lbrule.properties.backendPort = 80
    $lbrule.properties.IdleTimeoutInMinutes = 4

    # This rule will allow port 3389 traffic going through the VIP through to one of the Web Servers.

    $LoadBalancerProperties.loadbalancingRules += $lbrule = new-object Microsoft.Windows.NetworkController.LoadBalancingRule
    $lbrule.properties = new-object Microsoft.Windows.NetworkController.LoadBalancingRuleProperties
    $lbrule.ResourceId = "RDP"
    $lbrule.properties.frontendipconfigurations += $FrontEnd
    $lbrule.properties.backendaddresspool = $BackEnd 
    $lbrule.properties.protocol = "TCP"
    $lbrule.properties.frontendPort = 3389
    $lbrule.properties.backendPort = 3389
    $lbrule.properties.IdleTimeoutInMinutes = 4


    # Create a health probe

    $Probe = new-object Microsoft.Windows.NetworkController.LoadBalancerProbe
    $Probe.ResourceId = "Probe1"
    $Probe.ResourceRef = "/loadBalancers/$LBResourceId/Probes/$($Probe.ResourceId)"

    $Probe.properties = new-object Microsoft.Windows.NetworkController.LoadBalancerProbeProperties
    $Probe.properties.Protocol = "HTTP"
    $Probe.properties.Port = "80"
    $Probe.properties.RequestPath = "/"
    $Probe.properties.IntervalInSeconds = 5
    $Probe.properties.NumberOfProbes = 11

    $LoadBalancerProperties.Probes += $Probe


    # Create WEBLB

    $param = @{

        ConnectionUri = $uri
        ResourceId    = $ResourceID
        Properties    = $LoadBalancerProperties

    }

    $lb = New-NetworkControllerLoadBalancer @param -Force



    # Add Network Interfaces attached to WebServerVM1 and WebServerVM2

    $lbresourceid = "WEBLB"
    $lb = (Invoke-WebRequest -Headers @{"Accept" = "application/json" } -ContentType "application/json; charset=UTF-8" -Method "Get" -Uri "$uri/Networking/v1/loadbalancers/$lbresourceid" -DisableKeepAlive -UseBasicParsing).content | convertfrom-json

    # Add Configuration to WebServerVM1_Ethernet1

    $nic1 = get-networkcontrollernetworkinterface  -connectionuri $uri -resourceid "WebServerVM1_Ethernet1"
    $nic1.properties.IpConfigurations[0].properties.LoadBalancerBackendAddressPools += $lb.properties.backendaddresspools[0] 

    $param = @{

        ConnectionUri = $uri
        ResourceId    = "WebServerVM1_Ethernet1" 
        Properties    = $nic1.properties

    }

    new-networkcontrollernetworkinterface @param -force

    # Add Configuration to WebServerVM2_Ethernet1

    $nic2 = get-networkcontrollernetworkinterface  -connectionuri $uri -resourceid "WebServerVM2_Ethernet1"
    $nic2.properties.IpConfigurations[0].properties.LoadBalancerBackendAddressPools += $lb.properties.backendaddresspools[0] 

    $param = @{

        ConnectionUri = $uri
        ResourceId    = "WebServerVM2_Ethernet1" 
        Properties    = $nic2.properties

    }

    new-networkcontrollernetworkinterface @param -force

    # Get Public IP Address Assigned

    $assignedIP = (Get-NetworkControllerPublicIpAddress -ResourceId WEBLB-IP -ConnectionUri $uri).properties.ipaddress
    Write-Host "Your VIP for your WEBServer is $assignedIP" -ForegroundColor Green


}