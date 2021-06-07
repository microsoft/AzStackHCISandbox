Configuration ASHCIHost {

    param(
    #[Parameter(Mandatory)]
    [System.Management.Automation.PSCredential]$Admincreds,
    [String]$targetDrive = "V",
    [String]$targetVMPath = "$targetDrive" + ":\VMs",
    [String]$dsc_source="https://github.com/billcurtis/AzSHCISandbox/archive/main.zip",
    #[Parameter(Mandatory)]
    [string]$customRdpPort,
    [String]$ashci_uri="https://aka.ms/AAbbhkn",
    [String]$server2019_uri="https://aka.ms/AAbclsv",
    [String]$wacUri = "https://aka.ms/wacdownload"
    )
    
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xCredSSP'
    Import-DscResource -ModuleName 'DSCR_Shortcut'

    
    Node localhost{

    LocalConfigurationManager {
    RebootNodeIfNeeded = $true
    ActionAfterReboot  = 'ContinueConfiguration'
    ConfigurationMode = 'ApplyOnly'
    }


    #Windows Features Installations
    WindowsFeature Hyper-V {
    Ensure = 'Present'
    Name = "Hyper-V"
    IncludeAllSubFeature = $true
    
    }
    
    WindowsFeature Hyper-V-PowerShell{
    Ensure = 'Present'
    Name='Hyper-V-PowerShell'
    IncludeAllSubFeature = $true
    }

    WindowsFeature Hyper-V-Manager{
    Ensure = 'Present'
    Name='Hyper-V-Tools'
    IncludeAllSubFeature = $true
    }
    
    #Required Folders for ASHCI Deployment
    


    File "VMfolder" {
        Type            = 'Directory'
        DestinationPath = "$targetVMPath"
        DependsOn       = "[Script]FormatDisk"
        
    }

    File "ASHCIBuildScripts" {
        Type            = 'Directory'
        DestinationPath = "$env:SystemDrive\AzHCIVHDs"
        DependsOn       = "[Script]FormatDisk"
    }
    
    File "ASHCI_Sandbox" {
        Type            = 'Directory'
        DestinationPath = "$env:SystemDrive\AzHCI_Sandbox"
        DependsOn       = "[Script]FormatDisk"
        
    }

    xRemoteFile "Server2019VHD"{
        uri=$server2019_uri
        DestinationPath="$env:SystemDrive\AzHCIVHDs\GUI.vhdx"
        DependsOn="[File]ASHCIBuildScripts"
    }
   
    xRemoteFile "ASHCIVHD"{
        uri=$ashci_uri
        DestinationPath="$env:SystemDrive\AzHCIVHDs\AZSHCI.vhdx"
        DependsOn="[File]ASHCIBuildScripts"
    }
   
   xRemoteFile "ASHCIBuildScripts"{
    uri=$dsc_source
    DestinationPath="$env:SystemDrive\AzHCI_Sandbox\ASHCI_Sandbox.zip"
    DependsOn="[File]ASHCI_Sandbox"
}

    Archive "ASHCIBuildScripts" {
        Path="$env:SystemDrive\AzHCI_Sandbox\ASHCI_Sandbox.zip"
        Destination="$env:SystemDrive\AzHCI_Sandbox"
        DependsOn="[xRemoteFile]ASHCIBuildScripts"

    }
    xRemoteFile "WAC_Source"{
        uri=$wacURI
        DestinationPath="$env:SystemDrive\AzHCI_Sandbox\AzSHCISandbox-main\Applications\Windows Admin Center\WindowsAdminCenter2009.msi"
        DependsOn="[Archive]ASHCIBuildScripts"
    }
    cShortcut "BuildScript" {
        Path="C:\Users\Public\Desktop\New-AzSHCISandbox.lnk"
        Target="C:\AzHCI_Sandbox\AzSHCISandbox-main\New-AzSHCISandbox.ps1"
        WorkingDirectory="C:\AzHCI_Sandbox\AzSHCISandbox-main"
        Icon='shell32.dll,277'
        DependsOn="[xRemoteFile]ASHCIBuildScripts"

    }





#Configuring Storage Pool
    Script StoragePool {
        SetScript  = {
            New-StoragePool -FriendlyName AsHciPool -StorageSubSystemFriendlyName '*storage*' -PhysicalDisks (Get-PhysicalDisk -CanPool $true)
        }
        TestScript = {
            (Get-StoragePool -ErrorAction SilentlyContinue -FriendlyName AsHciPool).OperationalStatus -eq 'OK'
        }
        GetScript  = {
            @{Ensure = if ((Get-StoragePool -FriendlyName AsHciPool).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
        }
    }
    Script VirtualDisk {
        SetScript  = {
            $disks = Get-StoragePool -FriendlyName AsHciPool -IsPrimordial $False | Get-PhysicalDisk
            $diskNum = $disks.Count
            New-VirtualDisk -StoragePoolFriendlyName AsHciPool -FriendlyName AsHciDisk -ResiliencySettingName Simple -NumberOfColumns $diskNum -UseMaximumSize
        }
        TestScript = {
            (Get-VirtualDisk -ErrorAction SilentlyContinue -FriendlyName AsHciDisk).OperationalStatus -eq 'OK'
        }
        GetScript  = {
            @{Ensure = if ((Get-VirtualDisk -FriendlyName AsHciDisk).OperationalStatus -eq 'OK') { 'Present' } Else { 'Absent' } }
        }
        DependsOn  = "[Script]StoragePool"
    }
    Script FormatDisk {
        SetScript  = {
            $vDisk = Get-VirtualDisk -FriendlyName AsHciDisk
            if ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'raw') {
                $vDisk | Get-Disk | Initialize-Disk -Passthru | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
            }
            elseif ($vDisk | Get-Disk | Where-Object PartitionStyle -eq 'GPT') {
                $vDisk | Get-Disk | New-Partition -DriveLetter $Using:targetDrive -UseMaximumSize | Format-Volume -NewFileSystemLabel AsHciData -AllocationUnitSize 64KB -FileSystem NTFS
            }
        }
        TestScript = { 
            (Get-Volume -ErrorAction SilentlyContinue -FileSystemLabel AsHciData).FileSystem -eq 'NTFS'
        }
        GetScript  = {
            @{Ensure = if ((Get-Volume -FileSystemLabel AsHciData).FileSystem -eq 'NTFS') { 'Present' } Else { 'Absent' } }
        }
        DependsOn  = "[Script]VirtualDisk"
    }

    #### STAGE- SET WINDOWS DEFENDER EXCLUSION FOR VM STORAGE ####
<#
    Script defenderExclusions {
        SetScript  = {
            $exclusionPath = "$Using:targetDrive" + ":\"
            Add-MpPreference -ExclusionPath "$exclusionPath"               
        }
        TestScript = {
            $exclusionPath = "$Using:targetDrive" + ":\"
            (Get-MpPreference).ExclusionPath -contains "$exclusionPath"
        }
        GetScript  = {
            $exclusionPath = "$Using:targetDrive" + ":\"
            @{Ensure = if ((Get-MpPreference).ExclusionPath -contains "$exclusionPath") { 'Present' } Else { 'Absent' } }
        }
        DependsOn  = "[File]VMfolder"
    }
#>
    #### STAGE 1c - REGISTRY & SCHEDULED TASK TWEAKS ####

    Registry "Disable Internet Explorer ESC for Admin" {
        Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        Ensure    = 'Present'
        ValueName = "IsInstalled"
        ValueData = "0"
        ValueType = "Dword"
    }

    Registry "Disable Internet Explorer ESC for User" {
        Key       = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Ensure    = 'Present'
        ValueName = "IsInstalled"
        ValueData = "0"
        ValueType = "Dword"
    }
    
    Registry "Disable Server Manager WAC Prompt" {
        Key       = "HKLM:\SOFTWARE\Microsoft\ServerManager"
        Ensure    = 'Present'
        ValueName = "DoNotPopWACConsoleAtSMLaunch"
        ValueData = "1"
        ValueType = "Dword"
    }

    Registry "Disable Network Profile Prompt" {
        Key       = 'HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff'
        Ensure    = 'Present'
        ValueName = ''
    }

    if ($environment -eq "Workgroup") {
        Registry "Set Network Private Profile Default" {
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\010103000F0000F0010000000F0000F0C967A3643C3AD745950DA7859209176EF5B87C875FA20DF21951640E807D7C24'
            Ensure    = 'Present'
            ValueName = "Category"
            ValueData = "1"
            ValueType = "Dword"
        }

        Registry "SetWorkgroupDomain" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Ensure    = 'Present'
            ValueName = "Domain"
            ValueData = "$DomainName"
            ValueType = "String"
        }

        Registry "SetWorkgroupNVDomain" {
            Key       = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Ensure    = 'Present'
            ValueName = "NV Domain"
            ValueData = "$DomainName"
            ValueType = "String"
        }

        Registry "NewCredSSPKey" {
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
            Ensure    = 'Present'
            ValueName = ''
        }

        Registry "NewCredSSPKey2" {
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation'
            ValueName = 'AllowFreshCredentialsWhenNTLMOnly'
            ValueData = '1'
            ValueType = "Dword"
            DependsOn = "[Registry]NewCredSSPKey"
        }

        Registry "NewCredSSPKey3" {
            Key       = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly'
            ValueName = '1'
            ValueData = "*.$DomainName"
            ValueType = "String"
            DependsOn = "[Registry]NewCredSSPKey2"
        }
    }


    #### STAGE 1d - CUSTOM FIREWALL BASED ON ARM TEMPLATE ####

    if ($customRdpPort -ne "3389") {

        Registry "Set Custom RDP Port" {
            Key       = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
            ValueName = "PortNumber"
            ValueData = "$customRdpPort"
            ValueType = 'Dword'
        }
    
        Firewall AddFirewallRule {
            Name        = 'CustomRdpRule'
            DisplayName = 'Custom Rule for RDP'
            Ensure      = 'Present'
            Enabled     = 'True'
            Profile     = 'Any'
            Direction   = 'Inbound'
            LocalPort   = "$customRdpPort"
            Protocol    = 'TCP'
            Description = 'Firewall Rule for Custom RDP Port'
        }
    }
    #### STAGE 2h - CONFIGURE CREDSSP & WinRM

    xCredSSP Server {
        Ensure         = "Present"
        Role           = "Server"
        SuppressReboot = $true
    }
    xCredSSP Client {
        Ensure            = "Present"
        Role              = "Client"
        DelegateComputers = "$env:COMPUTERNAME" + ".$DomainName"
        DependsOn         = "[xCredSSP]Server"
        SuppressReboot    = $true
    }


}
    
    





}