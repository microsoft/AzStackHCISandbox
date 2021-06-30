# This script requires that 03.01_CreateWebServerVMs.ps1 was successfully run from the console vm.
# Version 1.0

<#
.SYNOPSIS 

In this example, you create an ACL that prevents VMs within the 192.173.44.0/24 subnet from communicating
 with each other. This type of ACL is useful for limiting the ability of an attacker to spread laterally 
 within the subnet, while still allowing the VMs to receive requests from outside of the subnet, as well 
 as to communicate with other services on other subnets.
   

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


    import-module networkcontroller  
    $uri = $using:uri
    $aclrules = @()  

    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"


    # Allow all inbound traffic.

    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Allow"  
    $ruleproperties.SourceAddressPrefix = "192.173.44.1"  # This is the gateway the external traffic will arrive on. 
    $ruleproperties.DestinationAddressPrefix = "*"  
    $ruleproperties.Priority = "100"  
    $ruleproperties.Type = "Inbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "AllowRouter_Inbound"  
    $aclrules += $aclrule  



    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Allow"  
    $ruleproperties.SourceAddressPrefix = "*"  
    $ruleproperties.DestinationAddressPrefix = "192.173.44.1"  # This is the gateway the external traffic will exit on. 
    $ruleproperties.Priority = "101"  
    $ruleproperties.Type = "Outbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "AllowRouter_Outbound"  
    $aclrules += $aclrule  

    # Next, we need to deny all INBOUND and OUTBOUND traffic on this subnet between other VMs. Since the above rules for 
    # 192.173.44.1 have a lower priority the gateway IP is not affected is not affected the blanket Deny rules which have 
    # a higher priority.


    # Deny Subnet Inbound

    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Deny"  
    $ruleproperties.SourceAddressPrefix = "192.173.44.0/24"  
    $ruleproperties.DestinationAddressPrefix = "*"  
    $ruleproperties.Priority = "102"  
    $ruleproperties.Type = "Inbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "DenySubnet_Inbound"  
    $aclrules += $aclrule  

    # Deny Subnet Outbound

    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Deny"  
    $ruleproperties.SourceAddressPrefix = "*"  
    $ruleproperties.DestinationAddressPrefix = "192.173.44.0/24"  
    $ruleproperties.Priority = "103"  
    $ruleproperties.Type = "Outbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "DenySubnet_Outbound" 

    # Allow all protocols coming in 

    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Allow"  
    $ruleproperties.SourceAddressPrefix = "*"  
    $ruleproperties.DestinationAddressPrefix = "*"  
    $ruleproperties.Priority = "104"  
    $ruleproperties.Type = "Inbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "AllowAll_Inbound"  
    $aclrules += $aclrule  


    # Allow all protocols going out

    $ruleproperties = new-object Microsoft.Windows.NetworkController.AclRuleProperties  
    $ruleproperties.Protocol = "All"  
    $ruleproperties.SourcePortRange = "0-65535"  
    $ruleproperties.DestinationPortRange = "0-65535"  
    $ruleproperties.Action = "Allow"  
    $ruleproperties.SourceAddressPrefix = "*"  
    $ruleproperties.DestinationAddressPrefix = "*"  
    $ruleproperties.Priority = "105"  
    $ruleproperties.Type = "Outbound"  
    $ruleproperties.Logging = "Enabled"  

    $aclrule = new-object Microsoft.Windows.NetworkController.AclRule  
    $aclrule.Properties = $ruleproperties  
    $aclrule.ResourceId = "AllowAll_Outbound"  
    $aclrules += $aclrule  

    $acllistproperties = new-object Microsoft.Windows.NetworkController.AccessControlListProperties  
    $acllistproperties.AclRules = $aclrules  


    # Create the ACL based off of the configuration data entered above.

    $param = @{

        ResourceId    = "Subnet-192-172-44-0"
        Properties    = $acllistproperties
        ConnectionUri = $uri

    }

    New-NetworkControllerAccessControlList @param -Force

}



