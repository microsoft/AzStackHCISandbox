
# Version 2.0

<#
.SYNOPSIS 

    This script:
    
     1. Creates a Single Server (Desktop Experience) VHD file for Appliance.vhdx, injects a unattend.xml
     2. Creates a Virtual Machine Named Appliance
     3. Adds Appliance VM to the S2DCluster 
     4. Creates two NIC Adapters: 1 attached to the management network, 1 attached to TenantNetwork1   

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

# Set Credential Object
$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($SDNConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"), `
(ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)

# Set fqdn
$fqdn = $SDNConfig.SDNDomainFQDN


Invoke-Command -ComputerName AzSHOST1 -Credential $domainCred -ScriptBlock {


    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"


    # Create Appliance and VHDX file

    Write-Verbose "Copying Over VHDX file for Appliance VM. This can take some time..."

 
    $csvfolder = "S2D_vDISK1"
    $VMName = 'Appliance'

   

    $Password = $using:SDNConfig.SDNAdminPassword
    $ProductKey = $using:SDNConfig.GUIProductKey
    $dnsIP = $using:SDNConfig.SDNLABDNS
    $gateway = $using:SDNConfig.SDNLABRoute  
    $sysIP = ($using:SDNconfig.DCIP).Replace("254", "50")
    $Domain = $using:fqdn


    Write-Verbose "Domain = $Domain"
    Write-Verbose "VMName = $VMName"
    Write-Verbose "ProductKey = $ProductKey"
    Write-Verbose "DNS IP = $dnsIP"
    Write-Verbose "Gateway IP = $gateway"
    Write-Verbose "System IP = $sysIP"

    # Copy over GUI VHDX

    Write-Verbose "Copying GUI.VHDX for $vmname..."

    $params = @{

        Path     = "C:\ClusterStorage\$csvfolder"
        Name     = $VMName
        ItemType = 'Directory'

    }

    $tenantpath = New-Item @params -Force

    Copy-Item -Path 'C:\ClusterStorage\S2D_vDISK1\GUI.VHDX' -Destination $tenantpath.FullName -Force

    # Inject Answer File
    Write-Verbose "Injecting Answer File for Appliance $VMName..."

    $params = @{

        Path     = 'D:\'
        Name     = $VMName
        ItemType = 'Directory'

    }


    $MountPath = New-Item @params -Force


    $ImagePath = "\\AzSHost1\c$\ClusterStorage\S2D_vDISK1\$VMName\GUI.vhdx"

    $params = @{

        ImagePath = $ImagePath
        Index     = 1
        Path      = $MountPath.FullName

    }

    $VerbosePreference = "SilentlyContinue"
    Mount-WindowsImage @params | Out-Null
    $VerbosePreference = "Continue"

    # Create Panther Folder
    Write-Verbose "Creating Panther folder.."

    $params = @{

        Path     = (($MountPath.FullName) + ("\Windows\Panther"))
        ItemType = 'Directory'

    }


    $pathPanther = New-Item @params -Force

    # Generate Unattend.xml

    $unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
            <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
            <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$vmname</ComputerName>
            <ProductKey>$productkey</ProductKey>
        </component>
        <component name="Microsoft-Windows-TerminalServices-LocalSessionManager" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <fDenyTSConnections>false</fDenyTSConnections>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserLocale>en-us</UserLocale>
            <UILanguage>en-us</UILanguage>
            <SystemLocale>en-us</SystemLocale>
            <InputLocale>en-us</InputLocale>
        </component>
        <component name="Microsoft-Windows-IE-ESC" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <IEHardenAdmin>false</IEHardenAdmin>
            <IEHardenUser>false</IEHardenUser>
        </component>
        <component name="Microsoft-Windows-TCPIP" processorArchitecture="wow64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Interfaces>
                <Interface wcm:action="add">
                    <Identifier>Ethernet 2</Identifier>
                    <Ipv4Settings>
                        <DhcpEnabled>false</DhcpEnabled>
                    </Ipv4Settings>
                    <UnicastIpAddresses>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$sysIP</IpAddress>
                    </UnicastIpAddresses>
                    <Routes>
                        <Route wcm:action="add">
                            <Identifier>1</Identifier>
                            <NextHopAddress>$gateway</NextHopAddress>
                            <Prefix>0.0.0.0/0</Prefix>
                            <Metric>20</Metric>
                        </Route>
                    </Routes>
                </Interface>
            </Interfaces>
        </component>
        <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DNSSuffixSearchOrder>
                <DomainName wcm:action="add" wcm:keyValue="1">contoso.com</DomainName>
            </DNSSuffixSearchOrder>
            <Interfaces>
                <Interface wcm:action="add">
                    <DNSServerSearchOrder>
                        <IpAddress wcm:action="add" wcm:keyValue="1">$dnsIP</IpAddress>
                    </DNSServerSearchOrder>
                    <Identifier>Ethernet 2</Identifier>
                    <DisableDynamicUpdate>false</DisableDynamicUpdate>
                    <DNSDomain>contoso.com</DNSDomain>
                    <EnableAdapterDomainNameRegistration>true</EnableAdapterDomainNameRegistration>
                </Interface>
            </Interfaces>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>UABhAHMAcwB3AG8AcgBkADAAMQBBAGQAbQBpAG4AaQBzAHQAcgBhAHQAbwByAFAAYQBzAHMAdwBvAHIAZAA=</Value>
                    <PlainText>false</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>c:\install.bat</CommandLine>
                    <Description>Install Choco</Description>
                    <RequiresUserInput>true</RequiresUserInput>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@


    # Install.bat copied to C Drive

    $installbatch = @'

ping 192.0.2.1 -n 1 -w 12312 >nul
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
choco install wireshark -y

'@

    $params = @{

        Value = $installbatch
        Path  = $(($MountPath.FullName) + ("\Install.bat"))

    }


    Set-Content @params -Force



    # Copy Unattend.xml to Panther folder

    $params = @{

        Value = $unattend
        Path  = $(($MountPath.FullName) + ("\Windows\Panther\Unattend.xml"))

    }


    Set-Content @params -Force


    #  Install IIS Web Server

    Write-Verbose "Installing IIS Web Server on $VMName"

    $params = @{

        Path        = $MountPath.FullName
        Featurename = 'IIS-WebServerRole'

    }

    Enable-WindowsOptionalFeature @params -All -LimitAccess | Out-Null


    Write-Verbose "Creating simple Web Page on $VMName"

    # Set Simple Web-Page
    $sysinfo = [PSCustomObject]@{ComputerName = $VMName }
    $sysinfo | ConvertTo-Html | Out-File  "$($MountPath.FullName)\inetpub\wwwroot\iisstart.htm" -Force

    # Dismount Image with Commit

    Write-Verbose "Committing and Dismounting Image..."
    Dismount-WindowsImage -Path $MountPath.FullName -Save | Out-Null

}




# Add Virtual Machines

Write-Verbose "Creating Virtual Machine"

New-VM -Name Appliance -ComputerName AzSHOST1 -VHDPath C:\ClusterStorage\S2D_vDISK1\Appliance\GUI.vhdx `
    -MemoryStartupBytes 8GB -Generation 2 -Path  C:\ClusterStorage\S2D_vDISK1\Appliance\ | Out-Null

Set-VM -Name Appliance -ComputerName AzSHOST1 -ProcessorCount 4 | Out-Null




Write-Verbose "Setting Static MACs on Appliance and adding additional network adapter..."

Set-VMNetworkAdapter -VMName Appliance -ComputerName AzSHOST1 -StaticMacAddress "00-11-55-33-44-77" | Out-Null
Add-VMNetworkAdapter -VMName Appliance -ComputerName AzSHOST1 -StaticMacAddress "00-11-55-44-44-44" -DeviceNaming On -Name 'TenantVMNetwork' | Out-Null


Write-Verbose "Connecting VMswitch to the VMNetwork Adapters on the Appliance "
Get-VMNetworkAdapter -ComputerName AzSHOST1 -VMName Appliance | Connect-VMNetworkAdapter -SwitchName sdnSwitch | Out-Null


# Unblocking Ports on Virtual Machines

Invoke-Command -ComputerName AzSHOST1 -ScriptBlock {

    #Port Profile Settings
    $PortProfileFeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"
    $NcVendorId = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"
    $portProfileDefaultSetting = Get-VMSystemSwitchExtensionPortFeature -FeatureId "9940cd46-8b06-43bb-b9d5-93d50381fd56"
    $portProfileDefaultSetting.SettingData.ProfileId = "{00000000-0000-0000-0000-000000000000}"
    $portProfileDefaultSetting.SettingData.NetCfgInstanceId = "{00000000-0000-0000-0000-000000000000}"
    $portProfileDefaultSetting.SettingData.CdnLabelString = "Microsoft"
    $portProfileDefaultSetting.SettingData.CdnLabelId = 0
    $portProfileDefaultSetting.SettingData.ProfileName = "Microsoft SDN Port"
    $portProfileDefaultSetting.SettingData.VendorId = "{1fa41b39-b444-4e43-b35a-e1f7985fd548}"
    $portProfileDefaultSetting.SettingData.VendorName = "NetworkController"
    $portProfileDefaultSetting.SettingData.ProfileData = "2"


    #Get the VMNics
    $VMNics = Get-VMNetworkAdapter -VMName Appliance
    #Set the extension port feature
    Foreach ($VMNic in $VMNics) {
        Try {
            Write-Verbose "Adding VMSwitchExtensionPortFeature on $VMNic"
            Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $portProfileDefaultSetting -VMNetworkAdapter $VMNic
        }
        Catch {
            throw $_
        }
    }

}


Write-Verbose "Starting the Appliance VM"
# Start the VMs

Start-VM -Name Appliance -ComputerName AzSHOST1


Write-Verbose "Getting MAC Addresses of the NICs for the Appliance VM so we can create NC objects"
# Get the MACs
$applianceMAC = (Get-VMNetworkAdapter -VMName Appliance -ComputerName AzSHOST1 | Where-Object { $_.macaddress -match '001155444444' }).MacAddress

Write-Verbose " Adding VM to our  AzStackCluster "

$VerbosePreference = "SilentlyContinue"
Import-Module FailoverClusters
$VerbosePreference = "Continue"


Add-ClusterVirtualMachineRole -VMName Appliance -Cluster  AzStackCluster | Out-Null



# Import Network Controller Module
$VerbosePreference = "SilentlyContinue"
Import-Module NetworkController
$VerbosePreference = "Continue"

$uri = "https://NC01.$($SDNConfig.SDNDomainFQDN)"





# HNV VM network 

$VMNetworkName = "TenantNetwork1"
$VMSubnetName = "TenantSubnet1"




# Add Network Interface Object for Appliance in Nework Controller

Write-Verbose "Creating a Network Interface Object for Appliance VM in NC"

$VMSubnetRef = (Get-NetworkControllerVirtualNetwork -ResourceId $VMNetworkName -ConnectionUri $uri).Properties.Subnets.ResourceRef

$vmnicproperties = new-object Microsoft.Windows.NetworkController.NetworkInterfaceProperties
$vmnicproperties.PrivateMacAddress = $applianceMAC
$vmnicproperties.PrivateMacAllocationMethod = "Static" 
$vmnicproperties.IsPrimary = $true 

$ipconfiguration = new-object Microsoft.Windows.NetworkController.NetworkInterfaceIpConfiguration
$ipconfiguration.resourceid = "Appliance_IP1"
$ipconfiguration.properties = new-object Microsoft.Windows.NetworkController.NetworkInterfaceIpConfigurationProperties
$ipconfiguration.properties.PrivateIPAddress = '192.172.33.25'
$ipconfiguration.properties.PrivateIPAllocationMethod = "Static"


$ipconfiguration.properties.Subnet = new-object Microsoft.Windows.NetworkController.Subnet
$ipconfiguration.properties.subnet.ResourceRef = $VMSubnetRef

$vmnicproperties.IpConfigurations = @($ipconfiguration)
New-NetworkControllerNetworkInterface -ResourceID "Appliance_Ethernet1" -Properties $vmnicproperties -ConnectionUri $uri -Force -PassInnerException

$nic = Get-NetworkControllerNetworkInterface -ConnectionUri $uri -ResourceId Appliance_Ethernet1 -PassInnerException

Write-Verbose "Invoking command on the SDNHOST where Appliance resides. Command will set the VFP extension so Appliance will have access to the network."

Invoke-Command -ComputerName AzSHOST1 -ArgumentList $nic -ScriptBlock {

    $nic = $args[0]

    #The hardcoded Ids in this section are fixed values and must not change.
    $FeatureId = "9940cd46-8b06-43bb-b9d5-93d50381fd56"  # This value never changes.
 
    $vmNic = Get-VMNetworkAdapter -VMName Appliance | Where-Object { $_.macaddress -match '001155444444' }
 
    $CurrentFeature = Get-VMSwitchExtensionPortFeature -FeatureId $FeatureId -VMNetworkAdapter $vmNic
 
    if ($CurrentFeature -eq $null) {
        $Feature = Get-VMSystemSwitchExtensionPortFeature -FeatureId $FeatureId
 
        $Feature.SettingData.ProfileId = "{$($nic.InstanceId)}"
        $Feature.SettingData.NetCfgInstanceId = "{00000000-0000-0000-0000-000000000000}" # This instance ID never changes.
        $Feature.SettingData.CdnLabelString = "Microsoft"
        $Feature.SettingData.CdnLabelId = 0
        $Feature.SettingData.ProfileName = "Microsoft SDN Port"
        $Feature.SettingData.VendorId = "{1FA41B39-B444-4E43-B35A-E1F7985FD548}"  # This vendor id never changes.
        $Feature.SettingData.VendorName = "NetworkController"
        $Feature.SettingData.ProfileData = 1
 
        Add-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature  $Feature -VMNetworkAdapter $vmNic
    }
    else {
        $CurrentFeature.SettingData.ProfileId = "{$($nic.InstanceId)}"
        $CurrentFeature.SettingData.ProfileData = 1
 
        Set-VMSwitchExtensionPortFeature -VMSwitchExtensionFeature $CurrentFeature  -VMNetworkAdapter $vmNic
    }
}

Write-Verbose "All done. Run Install.bat from the command line after you verify a internet connection."

