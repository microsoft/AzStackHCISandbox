# This script requires that Network Controller has been deployed
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Backs up SDN   
   

    After running this script, follow the directions in the README.md file for this scenario.
    Please note that this script needs to be run on the AdminCenter VM
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

# Set Credential Object
$domainCred = new-object -typename System.Management.Automation.PSCredential `
    -argumentlist (($SDNConfig.SDNDomainFQDN.Split(".")[0]) + "\administrator"), `
(ConvertTo-SecureString $SDNConfig.SDNAdminPassword -AsPlainText -Force)

# Create Share to backup too:

New-Item -Path 'C:\ncbackup' -ItemType Directory -Force | Out-Null

$params = @{

    Name        = 'NCBackup'
    Path        = 'c:\ncbackup'
    FullAccess  = 'Everyone'
    Description = 'Backup Share for NC Backups'

}


$Share = New-SmbShare @params -ErrorAction SilentlyContinue
# Get or Create Credential object for File share user

$ShareUserResourceId = "BackupUser"

$ShareCredential = Get-NetworkControllerCredential -ConnectionURI $URI -Credential $domainCred | Where { $_.ResourceId -eq $ShareUserResourceId }
If ($ShareCredential -eq $null) {
    $domainCredProperties = New-Object Microsoft.Windows.NetworkController.CredentialProperties
    $domainCredProperties.Type = "usernamePassword"
    $domainCredProperties.UserName = $domainCred.UserName
    $domainCredProperties.Value = $domainCred.GetNetworkCredential().password
    $ShareCredential = New-NetworkControllerCredential -ConnectionURI $URI -Credential $domainCred -Properties $domainCredProperties -ResourceId $ShareUserResourceId -Force
}

# Create backup

$BackupTime = (get-date).ToString("s").Replace(":", "_")

$BackupProperties = New-Object Microsoft.Windows.NetworkController.NetworkControllerBackupProperties
$BackupProperties.BackupPath = "\\admincenter\NCBackup\NetworkController\$BackupTime"
$BackupProperties.Credential = $ShareCredential

$Backup = New-NetworkControllerBackup -ConnectionURI $URI -Credential $domainCred -Properties $BackupProperties -ResourceId $BackupTime -Force 

$backupStatus = $null

$params = @{

    ConnectionUri = $uri
    Credential    = $domainCred
    ResourceId    = $Backup.ResourceId

}

While ($backupStatus.Properties.ProvisioningState -ne 'Succeeded') {



    $backupStatus = Get-NetworkControllerBackup  @params

    Write-Verbose $backupStatus.Properties.ProvisioningState

}

$backupStatus = Get-NetworkControllerBackup  @params
$backupStatus | ConvertTo-Json


 