# This script requires that Network Controller has been deployed
# Version 1.0

<#
.SYNOPSIS 

    This script:
    
     1. Restores Network Controller  
   

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


# Select NC backup to Restore 
$prevbackups = Get-NetworkControllerBackup  -ConnectionUri $uri -Credential $domainCred 

if ($prevbackups.resourceid) { 

    Write-Host "The following are backups located for this network controller:"  -ForegroundColor Yellow

    $prevbackups.resourceid

    $backupresid = Read-Host -Prompt "`nEnter the backup you wish to restore NC to"

    If ($backupresid) {

        # Stop the NC Host Agent and SLB Agent on all Hosts:

        $AzSHOSTs = @("AzSHOST1", "AzSHOST2")

        foreach ($AzSHOST in $AzSHOSTs) {

            Invoke-Command -ComputerName $AzSHOST  -ScriptBlock {

                $VerbosePreference = "Continue"

                # Stop the NC Host Agent

                Write-Verbose "Stopping NC Host Agent and SLB Host Agent on $env:ComputerName"
                Stop-Service NcHostAgent -Force   # Note: SLB Host Agent will be offlined as it is dependent on the NCHostAgent

              
            }


        }


        # Shutdown RAS Gateway VMs and SLBMUX VMs

        Write-Verbose "Shutting Down GW and Muxes"
        Get-VM -ComputerName azshost1, azshost2 | Where-Object { $_.Name -match 'GW0' -or $_.Name -match 'Mux0' } | Stop-VM 
        Start-Sleep -Seconds 60


        # Get SMB User credentials from the Network Controller and restore NC from backup
        $ShareUserResourceId = "BackupUser"
        $ShareCredential = Get-NetworkControllerCredential -ConnectionURI $URI -Credential $Credential | Where { $_.ResourceId -eq $ShareUserResourceId }
        $RestoreProperties = New-Object Microsoft.Windows.NetworkController.NetworkControllerRestoreProperties
        $RestoreProperties.RestorePath = (Get-NetworkControllerBackup -ResourceId $backupresid -ConnectionUri $uri -Credential $domainCred).Properties.BackupPath
        $RestoreProperties.Credential = $ShareCredential

        # Restore Network Controller

        $restoreNC = New-NetworkControllerRestore -ResourceId $backupresid -ConnectionUri $uri -Credential $domainCred -Properties $RestoreProperties  -PassInnerException 


        # Restart VMs
        Get-VM -ComputerName azshost1, azshost2 | Where-Object { $_.Name -match 'GW0' -or $_.Name -match 'Mux0' } | Start-VM

        # Restart NC Host Agent and SLB Mux

        foreach ($AzSHOST in $AzSHOSTs) {

            Invoke-Command -ComputerName $AzSHOST  -ScriptBlock {

                $VerbosePreference = "Continue"

                # Start the NC Host Agent

                Write-Verbose "Starting NC Host Agent and SLB Host Agent on $env:ComputerName"
                Start-Service NcHostAgent 
                Start-Service SLBHostAgent  

              
            }

        }


    }

    Get-VM -ComputerName azshost1, azshost2 | Where-Object { $_.Name -match 'GW0' -or $_.Name -match 'Mux0' } | Start-VM 

}


get-networkcontrollerrestore -connectionuri $uri -credential $cred -ResourceId $restoreNC.ResourceId | convertto-json -depth 10

