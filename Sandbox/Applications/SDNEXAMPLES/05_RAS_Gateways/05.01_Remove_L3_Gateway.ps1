# Version 2.0 - Remove-L3-Gateway.ps1

<#
.SYNOPSIS 

 Removes the configuration created by the Configure-L3_sample.ps1. If you changed connection or name 
 values, change them bolow.

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

# Set Credential Objects

$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "administrator", (ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)


# Set Connection IPs
####################

$uri = "https://NC01.$($SDNConfig.SDNDomainFQDN)"  # This is the URI for Network Controller
$vGatewayName = "L3Connection"                     # Name that will be used for the Gateway resource ID. This can be any string.
 

# Remove the Virtual Gateway

Write-Verbose "Attempting to Remove L3 Gateway"

$params = @{

    ConnectionUri = $uri
    ResourceID    = $vGatewayName 

}

$ErrorActionPreference = "SilentlyContinue"

$gwtoDelete = Get-NetworkControllerVirtualGateway @params -ErrorAction Ignore

if ($gwtoDelete) {


    Remove-NetworkControllerVirtualGateway @params -Force -ErrorAction Ignore


}

else { Write-Host "Could not find Gateway with a ResourceID of $vGatewayName" -ForegroundColor Yellow }


$ErrorActionPreference = "Stop"


# Clear BGP Peering on Server Admin Center

Write-Verbose "Removing all BGP Peering on the AdminCenter virtual machine"


Get-BgpPeer | Remove-BgpPeer -Force -Confirm:$false


# Clear VLAN 200 Route on the BGP-ToR-Router

Write-Verbose "Removing route for TenantNetwork1 from the BGP-ToR-Router virtual machine"

Invoke-Command -ComputerName ($SDNConfig.BGPRouterIP_MGMT.Split("/")[0]) -ScriptBlock {

    Remove-NetRoute -DestinationPrefix 192.172.33.0/24 -Confirm:$false


} -Credential $localCred
