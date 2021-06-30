# Version 1.0

<#
.SYNOPSIS 

    This script will provision a RRAS Router and Web Server to simulate a GRE Site for Microsoft
    SDN RAS Gateways to connect to.

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

# Set Credential Objects

$localCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist "administrator", (ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)

# Set Variables 

$greIP = $SDNConfig.GRETARGETIP_BE 


# Add Network Adapter to Router VM for GRE Network

$getNetadapter = Invoke-Command -ComputerName SDNMGMT -Credential $localCred  -ScriptBlock {

    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"


    Write-Verbose "Adding a GRE Network Adapter to VM: BGP-ToR-Router"

    $getNetAdapter = Get-VMNetworkAdapter -VMName 'bgp-tor-router' | Where-Object { $_.Name -eq 'GRE' }

    if (!$getNetAdapter) {

        $params = @{

            VMName       = 'bgp-tor-router'
            Name         = 'GRE'
            SwitchName   = 'vSwitch-Fabric'
            DeviceNaming = 'On'

        }

        Add-VMNetworkAdapter @params 

    }

    return $getNetAdapter

}

##### Configure BGP-ToR-Router for GRE Connections

Write-Verbose "Configuring BGP-ToR-Router for GRE Connections"

if (!$getNetadapter) {

    Invoke-Command -ComputerName bgp-tor-router -Credential $localCred -ScriptBlock {

        $VerbosePreference = "SilentlyContinue"
        Import-Module NetAdapter
        Import-Module NetTCPIP
        $VerbosePreference = "Continue"

        # Configure GRE NIC

        Write-Verbose "Configuring GRE NIC"

        $greIP = $using:greIP
        $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "GRE" }
        Rename-NetAdapter -name $NIC.name -newname "GRE" | Out-Null
        New-NetIPAddress -InterfaceAlias "GRE" -IPAddress ($greIP.Split("/")[0]) -PrefixLength ($greIP.Split("/")[1]) | Out-Null

    }

}

Write-Verbose "Starting VM Build..."

Invoke-Command -ComputerName SDNMGMT -Credential $localCred -ArgumentList $SDNConfig -ScriptBlock {

    # Set Variables
    $SDNConfig = $using:SDNConfig
    $localCred = $using:localCred
    $ParentDiskPath = 'C:\VMs\Base'
    $vmPath = 'D:\VMs\'
    $OSVHDX = 'CORE.VHDX'
    $VMName = "gre-target"
    $adapterGREname = 'GRE'
    
    $ProgressPreference = "SilentlyContinue"
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"
    $WarningPreference = "SilentlyContinue"

    # Create Private vSwitch

    Write-Verbose "Creating Private Switch for VM: $VMName"

    $switch = Get-VMSwitch | ? { $_.name -eq "vSwitch-$VMName" }
    if (!$switch) { New-VMSwitch "vSwitch-$VMName" -SwitchType Private | Out-Null }

    # Create Host OS Disk
    Write-Verbose "Creating $VMName differencing disks"

    $params = @{

        ParentPath = ($ParentDiskPath + $OSVHDX)
        Path       = ($vmpath + $VMName + '\' + $VMName + '.vhdx')

    }

    New-VHD @params -Differencing | Out-Null


    # Create Virtual Machine

    Write-Verbose "Creating Virtual Machine $VMName"

    $params = @{

        Name       = $VMName
        VHDPath    = ($vmpath + $VMName + '\' + $VMName + '.vhdx')
        Path       = ($vmpath + $VMName) 
        Generation = 2

    }

    New-VM @params | Out-Null

    # Set VM Memory

    Write-Verbose "Setting $VMName Memory"

    $params = @{

        VMName               = $VMName
        DynamicMemoryEnabled = $true
        StartupBytes         = $SDNConfig.MEM_GRE
        MaximumBytes         = $SDNConfig.MEM_GRE
        MinimumBytes         = 500MB

    }

    Set-VMMemory @params | Out-Null

    # Set Processor Core Count

    Write-Verbose "Creating $VMName Processor"
    Set-VMProcessor -VMName $VMName -Count 2 | Out-Null

    # Set VM Automatic Stop Action

    Set-VM -Name $VMName -AutomaticStopAction TurnOff | Out-Null

    # Remove the VM Network Adapter

    Write-Verbose "Removing $VMName Netadapter"
    Remove-VMNetworkAdapter -VMName $VMName -Name "Network Adapter" | Out-Null 

    # Configure VM Networking

    Write-Verbose "Adding Network Adapters to $VMName"

    $params = @{

        VMName       = $VMName 
        Name         = $VMName
        SwitchName   = "vSwitch-$VMName" 
        DeviceNaming = 'On'

    }

    Add-VMNetworkAdapter @params | Out-Null

    $params = @{

        VMName       = $VMName 
        Name         = $adapterGREname
        SwitchName   = "vSwitch-Fabric" 
        DeviceNaming = 'On'

    }

    Add-VMNetworkAdapter @params | Out-Null

    #Set-VMNetworkAdapterVlan -VMName $VMName -VMNetworkAdapterName GRE -Access -VlanId 0 | Out-Null


    ### Inject Answer File

    # MountVHDXFile

    Write-Verbose "Mounting $VMName VHDX file" 
    New-Item -Path "C:\TempMount" -ItemType Directory | Out-Null

    $params = @{

        Path      = "C:\TempMount"
        Index     = 1
        ImagePath = ($vmpath + $VMName + '\' + $VMName + '.vhdx') 

    }

    Mount-WindowsImage @params | Out-Null

    # Apply Unattend File

    Write-Verbose "Applying unattend file to $VMName"

    $Password = $SDNConfig.SDNAdminPassword
    $ProductKey = $SDNConfig.COREProductKey

    $Unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing>
        <package action="configure">
            <assemblyIdentity name="Microsoft-Windows-Foundation-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="" />
            <selection name="RemoteAccess" state="true" />
            <selection name="RemoteAccessServer" state="true" />
            <selection name="RasRoutingProtocols" state="true" />
        </package>
    </servicing>
    <settings pass="specialize">
        <component name="Networking-MPSSVC-Svc" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DomainProfile_EnableFirewall>false</DomainProfile_EnableFirewall>
            <PrivateProfile_EnableFirewall>false</PrivateProfile_EnableFirewall>
            <PublicProfile_EnableFirewall>false</PublicProfile_EnableFirewall>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>$VMName</ComputerName>
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
                    <Value>$Password</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="" xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
"@

    $params = @{

        Path     = 'C:\TempMount\windows'
        ItemType = 'Directory'
        Name     = 'Panther'

    }

    New-Item @params -Force | Out-Null

    $params = @{

        Value = $Unattend
        Path  = "C:\TempMount\Windows\Panther\Unattend.xml" 

    }
    Set-Content @params -Force
    # Copy-Item -Path "$Assetspath\$VMName.png" "C:\TempMount\"
  
    Write-Verbose "Enabling Remote Access"
    Enable-WindowsOptionalFeature -Path C:\TempMount -FeatureName RasRoutingProtocols -All -LimitAccess | Out-Null
    Enable-WindowsOptionalFeature -Path C:\TempMount -FeatureName RemoteAccessPowerShell -All -LimitAccess | Out-Null
    Dismount-WindowsImage -Path "C:\TempMount" -Save | Out-Null
    Remove-Item "C:\TempMount" | Out-Null

    #Start the VM
    Write-Verbose "Starting VM: $VMName"
    Start-VM -Name $VMName 


    while ((Invoke-Command -VMName $VMName -Credential $localcred { "Test" } -ea SilentlyContinue) -ne "Test") { Sleep -Seconds 1 }

    Write-Verbose "Configuring $VMName" 

    Invoke-Command -VMName $VMName -Credential $localCred -ScriptBlock {

        $VerbosePreference = "Continue"
        $WarningPreference = "SilentlyContinue"

        $SDNConfig = $using:SDNConfig
        $BackEndIP = $SDNConfig.GRETARGETIP_BE.Split("/")[0]
        $BackEndPFX = $SDNConfig.GRETARGETIP_BE.Split("/")[1]
        $FrontEndIP = $SDNConfig.GRETARGETIP_FE.Split("/")[0]
        $FrontEndPFX = $SDNConfig.GRETARGETIP_FE.Split("/")[1]

        Write-Verbose "Configuring Network Interfaces..." 
        $VerbosePreference = "SilentlyContinue"
        $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq $env:COMPUTERNAME }
        Rename-NetAdapter -name $NIC.name -newname $env:COMPUTERNAME | Out-Null
        New-NetIPAddress -InterfaceAlias $env:COMPUTERNAME -IPAddress $BackEndIP -PrefixLength $BackEndPFX | Out-Null
        $NIC = Get-NetAdapterAdvancedProperty -RegistryKeyWord "HyperVNetworkAdapterName" | Where-Object { $_.RegistryValue -eq "Internet" }
        Rename-NetAdapter -name $NIC.name -newname "Internet" | Out-Null
        New-NetIPAddress -InterfaceAlias "Internet" -IPAddress $FrontEndIP -PrefixLength $FrontEndPFX | Out-Null
        $VerbosePreference = "Continue"

        Write-Verbose "Installing and configuring Internet Information Services..." 
        $VerbosePreference = "SilentlyContinue"
        Enable-WindowsOptionalFeature -online -featurename IIS-WebServer -All -LimitAccess | Out-Null 
        # Copy-Item -Path "c:\$env:COMPUTERNAME.png" -Destination C:\inetpub\wwwroot\iisstart.png -Force  | Out-Null

        $VerbosePreference = "Continue"
        Write-Verbose "Installing Remote Access..." 

        $VerbosePreference = "SilentlyContinue"
        Install-RemoteAccess -VpnType VpnS2S | Out-Null
        $VerbosePreference = "Continue"

        Write-Verbose "Adding Network Routes for GRE Subnet on Internet Adapter"
        $MGMTGW = $SDNConfig.BGPRouterIP_Internet.Split("/")[0]

        $params = @{

            DestinationPrefix = $SDNConfig.GRESubnet
            NextHop           = $MGMTGW
            InterfaceAlias    = 'Internet'

        }

        New-NetRoute @params | Out-Null

        #Enable Large MTU
        Write-Verbose "Configuring MTU on all Adapters"
        Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Set-NetAdapterAdvancedProperty -RegistryValue $SDNConfig.SDNLABMTU -RegistryKeyword "*JumboPacket"

    } 


}


