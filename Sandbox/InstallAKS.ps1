
write-host -ForegroundColor Green -Object "Install AKS on HCI Sandbox Cluster"


#Variables
$adcred=Get-Credential -UserName "contoso\administrator" -Message "Provide AD Account Password"

#Set Variables for Install
$aksvar= @{
    HostList="AZSHost1", "AZSHOST2"
    AKSvnetname = "vnet1"
    AKSvSwitchName = "sdnSwitch"
    AKSNodeStartIP = "192.168.200.25"
    AKSNodeEndIP = "192.168.200.100"
    AKSVIPStartIP = "192.168.200.125"
    AKSVIPEndIP = "192.168.200.200"
    AKSIPPrefix = "192.168.200.0/24"
    AKSGWIP = "192.168.200.1"
    AKSDNSIP = "192.168.1.254"
    AKSCSV="C:\ClusterStorage\S2D_vDISK1"
    AKSImagedir = "C:\ClusterStorage\S2D_vDISK1\aks\Images"
    AKSWorkingdir = "C:\ClusterStorage\S2D_vDISK1\aks\Workdir"
    AKSCloudConfigdir = "C:\ClusterStorage\S2D_vDISK1\aks\CloudConfig"
    AKSCloudSvcidr = "192.168.1.15/24"
    AKSVlanID="200"
    AKSResourceGroupName = "ASHCI-Nested-AKS"


}
## Azure AD Credentials ##

#login to Azure
        $azcred=Get-AzContext

        if (-not (Get-AzContext)){
            $azcred=Login-AzAccount -UseDeviceAuthentication
        }

    #select context
        $context=Get-AzContext -ListAvailable
        if (($context).count -gt 1){
            $context=$context | Out-GridView -OutputMode Single
            $context | Set-AzContext
        }

    #location (all locations where HostPool can be created)
        $region=(Get-AzLocation | Where-Object Providers -Contains "Microsoft.DesktopVirtualization" | Out-GridView -OutputMode Single -Title "Please select Location for AVD Host Pool metadata").Location



##Install AKS onto the Cluster ##

#Install latest versions of Nuget and PowershellGet

    
  Write-Host "Install latest versions of Nuget and PowershellGet" -ForegroundColor Green -BackgroundColor Black

    Invoke-Command -VMName $aksvar.HostList -Credential $ADCred -ScriptBlock {
        Enable-PSRemoting -Force
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        Install-PackageProvider -Name NuGet -Force 
        Install-Module -Name PowershellGet -Force -Confirm:$false
        }
 
     Write-Host -ForegroundColor Green -BackgroundColor Black "Install necessary AZ modules plus AksHCI module and initialize akshci on each node"
    #Install necessary AZ modules plus AksHCI module and initialize akshci on each node
    Invoke-Command -VMName $aksvar.HostList  -Credential $ADCred -ScriptBlock {
        Write-Host "Installing Required Modules" -ForegroundColor Green -BackgroundColor Black
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      
        $ModuleNames="Az.Resources","Az.Accounts", "AzureAD", "AKSHCI"
        foreach ($ModuleName in $ModuleNames){
            if (!(Get-InstalledModule -Name $ModuleName -ErrorAction Ignore)){
                Install-Module -Name $ModuleName -Force -AcceptLicense 
            }
        }
        Import-Module Az.Accounts
        Import-Module Az.Resources
        Import-Module AzureAD
        Import-Module AksHci
        Initialize-akshcinode
        }
    
    Write-Host "Prepping AKS Install" -ForegroundColor Green -BackgroundColor Black
    #Install AksHci - only need to perform the following on one of the nodes
    Invoke-Command -VMName $aksvar.HostList[0] -Credential $adcred -ScriptBlock  {
        $vnet = New-AksHciNetworkSetting -name $using:aksvar.AKSvnetname -vSwitchName $using:aksvar.AKSvSwitchName -k8sNodeIpPoolStart $using:aksvar.AKSNodeStartIP -k8sNodeIpPoolEnd $using:aksvar.AKSNodeEndIP -vipPoolStart $using:aksvar.AKSVIPStartIP -vipPoolEnd $using:aksvar.AKSVIPEndIP -ipAddressPrefix $using:aksvar.AKSIPPrefix -gateway $using:aksvar.AKSGWIP -dnsServers $using:aksvar.AKSDNSIP -vlanID $aksvar.vlanid        
        Set-AksHciConfig -imageDir $using:aksvar.AKSImagedir -workingDir $using:aksvar.AKSWorkingdir -cloudConfigLocation $using:aksvar.AKSCloudConfigdir -vnet $vnet -cloudservicecidr $using:aksvar.AKSCloudSvcidr 
        $azurecred=Connect-AzAccount -UseDeviceAuthentication
        $armtoken = Get-AzAccessToken
        $graphtoken = Get-AzAccessToken -ResourceTypeName AadGraph
        Set-AksHciRegistration -subscriptionId $azurecred.Context.Subscription.Id -resourceGroupName $using:aksvar.AKSResourceGroupName -AccountId $azurecred.Context.Account.Id -ArmAccessToken $armtoken.Token -GraphAccessToken $graphtoken.Token
        Write-Host -ForegroundColor Green -Object "Ready to Install AKS on HCI Cluster"
        Install-AksHci 
    }




