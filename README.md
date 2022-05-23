
![](media/microsoft-azure-stack-HCI-logo.png)
**Welcome to the easiest deployment of Azure Stack HCI, full stack of your life!**

With this ARM Template you will be able to deploy a working, nested Azure Stack HCI cluster with Hyper-V, Storage Spaces Direct and Software Defined Networking, all manged by Windows Admin Center. It's so simple!

The Azure Stack HCI Operator's Sandbox is a series of scripts that creates a [HyperConverged](https://docs.microsoft.com/en-us/windows-server/hyperconverged/) environment using four nested Hyper-V Virtual Machines. The purpose of the Azure Stack HCI Operator's Sandbox  is to provide operational training on Microsoft Azure Stack HCI as well as provide a development environment for DevOPs to assist in the creation and
validation of some Azure Stack HCI features without the time consuming process of setting up physical servers and network routers\switches.

>**Azure Stack HCI Operator's Sandbox is not a production solution!** The Azure Stack HCI Operator's Sandbox's scripts have been modified to work in a limited resource environment as well as in a Microsoft Azure virtual machine. Because of this, it is not fault tolerant, is not designed to be highly available, and lacks the nimble speed and resilience of a **real** Microsoft Azure Stack HCI deployment.

Want a deeper understanding of Deploying Azure Stack HCI, and ready to learn quickly about the components?

<a href="https://sway.office.com/f4UzIZqrmGgMqTfZ?ref=Link.office.com/f4UzIZqrmGgMqTfZ?ref=Link" target="_blank">Deploying Azure Stack HCI</a>


What is Azure Stack HCI?
-----------

If you've landed on this page, and you're still wondering what Azure Stack HCI 21H2 is, Azure Stack HCI 21H2 is a hyperconverged cluster solution that runs virtualized Windows and Linux workloads in a hybrid on-premises environment. Azure hybrid services enhance the cluster with capabilities such as cloud-based monitoring, site recovery, and backup, as well as a central view of all of your Azure Stack HCI 21H2 deployments in the Azure portal. You can manage the cluster with your existing tools including Windows Admin Center, System Center, and PowerShell.

Initially based on Windows Server 2019, Azure Stack HCI 21H2 is now a specialized OS, running on your hardware, delivered as an Azure service with a subscription-based licensing model and hybrid capabilities built-in. Although Azure Stack HCI 21H2 is based on the same core operating system components as Windows Server, it's an entirely new product line focused on being the best virtualization host.

If you're interested in learning more about what Azure Stack HCI 21H2 is, make sure you [check out the official documentation](https://docs.microsoft.com/en-us/azure-stack/hci/overview "What is Azure Stack HCI 21H2 documentation"), before coming back to continue your evaluation experience.  We'll refer to the docs in various places in the guide, to help you build your knowledge of Azure Stack HCI 21H2.

Why follow this guide?
-----------

This evaluation guide will walk you through standing up a sandboxed, isolated Azure Stack HCI 21H2 environment using **nested virtualization** in a **single Azure VM**. The important takeaway here is, by following this guide, you'll lay down a solid foundation on to which you can explore additional Azure Stack HCI 21H2 scenarios in the future, so keep checking back for additional scenarios over time.

Interested in AKS on Azure Stack HCI?
-----------
If you're interested in evaluating AKS on Azure Stack HCI (AKS-HCI), and you're planning to evaluate all the solutions using nested virtualization in Azure, it's certainly tempting to run AKS-HCI on top of an Azure Stack HCI 21H2 nested cluster in an Azure VM, however we **strongly discourage** this approach due to the performance impact of multiple layers of nested virtualization. The recommended approach to test AKS-HCI in an Azure VM using [the official AKS on Azure Stack HCI eval guide](https://aka.ms/aks-hci-evalonazure "AKS on Azure Stack HCI eval guide").

Evaluating in Azure
-----------

As with any infrastructure technology, in order to test, validate and evaluate the technology, there's typically a requirement for hardware. If you're fortunate enough to have multiple server-class pieces of hardware going spare (ideally hardware validated for Azure Stack HCI 21H2, found on our [Azure Stack HCI 21H2 Catalog](https://aka.ms/azurestackhcicatalog "Azure Stack HCI 21H2 Catalog")), you can certainly perform a more real-world evaluation of Azure Stack HCI 21H2.

For the purpose of this evaluation guide however, we'll be relying on **nested virtualization** to allow us to consolidate a full lab infrastructure, down **onto a single Hyper-V host inside an Azure VM**.

*************************

### Important Note - Production Deployments ###
The use of nested virtualization in this evaluation guide is aimed at providing flexibility for evaluating Azure Stack HCI 21H2. For **production** use, **Azure Stack HCI 21H2 should be deployed on validated physical hardware**, of which you can find a vast array of choices on the [Azure Stack HCI 21H2 Catalog](https://aka.ms/azurestackhcicatalog "Azure Stack HCI 21H2 Catalog").

*************************

Nested Virtualization
-----------
If you're not familiar with Nested Virtualization, at a high level, it allows a virtualization platform, such as Hyper-V, or VMware ESXi, to run virtual machines that, within those virtual machines, run a virtualization platform. It may be easier to think about this in an architectural view.

![Nested virtualization architecture](/media/nested_virt.png "Nested virtualization architecture")

As you can see from the graphic, at the base layer, you have your physical hardware, onto which you install a hypervisor. In this case, for our example, we're using Windows Server 2019 with the Hyper-V role enabled.  The hypervisor on the lowest level is considered L0 or the level 0 hypervisor.  On that physical host, you create a virtual machine, and into that virtual machine, you deploy an OS that itself, has a hypervisor enabled.  In this example, that 1st Virtualized Layer is running a **nested** Azure Stack HCI 21H2 operating system. This would be an L1 or level 1 hypervisor.  Finally, in our example, inside the Azure Stack HCI 21H2 OS, you create a virtual machine to run a workload.  This could in fact also contain a hypervisor, which would be known as the L2 or level 2 hypervisor, and so the process continues, with multiple levels of nested virtualization possible.

The use of nested virtualization opens up amazing opportunities for building complex scenarios on significantly reduced hardware footprints, however it shouldn't be seen as a substitute for real-world deployments, performance and scale testing etc.

Deployment of Azure Stack HCI 21H2 nested in Azure
-----------
For those of you who don't have multiple server-class pieces of hardware to test a full hyperconverged solution, this evaluation guide will detail using **nested virtualization** in Azure to evaluate Azure Stack HCI.

![Architecture diagram for Azure Stack HCI 21H2 nested in Azure](/media/nested_virt_arch_ga_oct21.png "Architecture diagram for Azure Stack HCI 21H2 nested in Azure")

In this configuration, you'll take advantage of the nested virtualization support provided within certain Azure VM sizes.  You'll deploy a single Azure VM running Windows Server 2019 to act as your main Hyper-V host - and through PowerShell DSC, this will be automatically configured with the relevant roles and features needed for this guide. It will also download all required binaries, and deploy 2 Azure Stack HCI 21H2 nodes, ready for clustering.

To reiterate, the whole configuration will run **inside the single Azure VM**.

## Deploy to Azure ##

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmicrosoft%2FAzStackHCISandbox%2Fmain%2Fjson%2Fazuredeploy.json)

<!--
## old ##  
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmgodfre3%2FAzSHCI-AZNested%2Fmain%2Fjson%2Fazuredeploy.json)
-->
### Prefer a video, no problem! Watch this Getting Started video to well...Get Started with the Azure Stack HCI Sandbox, and within about 2 hours you will be ready to test out Azure Stack HCI ###

[![AzStackHCISandbox-Getting Started](https://res.cloudinary.com/marcomontalbano/image/upload/v1624560307/video_to_markdown/images/youtube--nmQ12Ma1pD4-c05b58ac6eb4c4700831b2b3070cd403.jpg)](https://youtu.be/nmQ12Ma1pD4 "AzStackHCISandbox-Getting Started")

# Custom Deployment- Azure Portal #

For your first step, you will want to click "Edit Parameters"


You will need to supply the Resource Group and the Admin Password still, but this is a fairly easy process.

Hit Review+Create and jump to the "After Deployment Section"
![](./media/Readme%20Content/CustomDeployment_Step3.png)

#

# Custom Deployment - AZ PowerShell #

If you are more familiar with PowerShell and would rather do the deployment in Command Line, well Awesome, that is how you should be doing this. The instructions are below:

First, you will need to login to your Azure Account in your Terminal Session.

```{Powershell}
Connect-AZAccount
```

Then you will need to select your Subscription

```{Powershell}
Select-AZSubscription -Subscription $subscriptionid
```

Following that, you will want to create a Resource Group Name Variable, something like:

```{Powershell}
$rgname="ASHCI-Sandbox"
$resourcegroup=Get-AZResourceGroup -ResourceGroupName $rgname
```

then you need a password, stored as a variable, don't forget it, you will need it to login to the VM we create.

```{Powershell}
$securepw=ConvertTo-SecureString -String "Password01" -AsPlainText -Force
```

Now store the template files as variables. Try something like

```{Powershell}
$template=".\json\azuredeploy.json"
$param=".\json\azuredeploy.parameters.json"
```

Phew, we are ready to deploy. Ready, here we go.

```{Powershell}
New-AzResourceGroupDeployment -ResourceGroupName $rgname -Name "ASHCISandbox-Deploy" -TemplateFile $template -TemplateParameterFile $param -AdminPassword $securepw
```

Give this a couple of minutes, and you will see your new VM, ASHCIHost001 if you kept the default name, in your Resource group. You can RDP to the Public IP address and then begin the deployment of the cluster, this first step was only to deploy the Host, the real fun begins next but don't worry it really is very easy.

#

### Warning ###

The deployment may error out, with a warning about the DSC extension not completing due to a system shutdown. Don't worry though. That's the beauty of DSC, the configuration will run every 15 minutes.

![](media/Deploy_error_1.jpg)

#

Go grab a coffee or lunch, the components need a few minutes to download, but once you see the shortcut on the desktop, named New-AZSHCI-Sandbox, you are ready to go.

# Deployment-Post Azure #

Now that the Azure Resource is completed, you are ready to begin deploying the HCI cluster. The Azure VM that you just deployed is only a Nested Host, to contain all the components neccesary for this 2 node HCI cluster.

#
### Important ###
The HCI Sandbox was meant to help you understand Software Defined Networking in Azure Stack HCI, but if you DO NOT want to deploy SDN or you WANT to DEPLOY AKS on HCI, you will need to EDIT the Config file BEFORE deployment. This can be done by using notepad or ISE to edit line 47 of the Config file. 
You will need to UPDATE the line "Configure NC= $True" to "ConfigureNC=$false" 

This is the neccesary step to be able to Install AKS on the HCI Sandbox.

#

You have 2 main options for deploying the HCI cluster:

1) Build Script located on the Desktop of the Azure Virtual Machine- simply run this script and 1-2 hours later cluster should be deployed.
2) Run the script from powershell and monitor the progress. The code is available here:

   ```powershell
   & C:\AzHCI_Sandbox\AzSHCISandbox-main\New-AzSHCISandbox.ps1
   ```



### Important ###
If you find during the installation that something went wrong, please run the Installation Script in a PowerShell window, as this is the only way to understand the issue. If you have an issue during installation, file an Issue in GitHub for this Repo, and provide the Error Details from this process. 
#


Once the build is complete, you will see the shortcut to RDP the Admin Center Server. You can use this to RDP your Windows 10 Workstation and begin using the HCI Sandbox.

# Post Deployment - HCI Cluster Registration #

One of the first steps when deploying Azure Stack HCI is registraiton of the Cluster to your Azure Subscription. You can register the cluster in a number of ways including with Windows Admin Center, instructions are available here.

For your convience a script has been added to automate that registration process.  Run the code below in Powershell, you will be prompted for three additional items:

1) Login for the Contoso Domain Admin Account  ( Default is "Password01)
2) Login to Azure with Device Credentials, you will see this in yellow text with a code to input to "Microsoft.com/devicelogin.
3) Select an Azure Region to deploy the cluster into from the list.



### Run this from the Azure VM ###

```Powershell
& C:\AzHCI_Sandbox\AzSHCISandbox-main\Register-Cluster.ps1
```



# After Azure Deployment #

## Connecting to Admin Center to Manage the Cluster ##

Using RDP, log into the 'Admincenter' virtual machine with your creds: User: Contoso\Administrator Password: Password01

Launch the link to Windows Admin Center

Add the Hyper-Converged Cluster *AzStackCluster* to *Windows Admin Center* with *Network Controller*: [https://nc01.contoso.com](https://nc01.contoso.com) and you're off and ready to go!

    

![Add Hyper-Converged Cluster Connection](media/AddHCCluster.png)

**Azure Stack HCI Sandbox (2/7/2021)**

![Photo of Fully Deplopyed ASHCI-Sandbox](media/AzSHCISandbox.png)

The Azure Stack HCI Sandbox is a series of scripts that creates a [HyperConverged](https://docs.microsoft.com/en-us/windows-server/hyperconverged/) environment using four nested Hyper-V Virtual Machines. The purpose of the SDN Sandbox is to provide operational training on Microsoft SDN as well as provide a development environment for DevOPs to assist in the creation and
validation of SDN features without the time consuming process of setting up physical servers and network routers\switches.

>**SDN Sandbox is not a production solution!** SDN Sandbox's scripts have been modified to work in a limited resource environment. Because of this, it is not fault tolerant, is not designed to be highly available, and lacks the nimble speed of a **real** Microsoft SDN deployment.

## History

SDN Sandbox is a *really* fast refactoring of scripts that I wrote for myself to rapidly create online labs for SDN. The  scripts have been stream-lined to a version that uses Windows Admin Center for the management of Microsoft SDN.

## Scenarios

The ``SCRIPTS\Scenarios`` folder in this solution will be updated quite frequently with full solutions\examples of popular SDN scenarios. Please keep checking for updates!


## Removing HCI Sandbox
Not that you would ever want to do this, but if you want to start over with the HCI Sandbox deployment at anytime, the Delete Command has been built into the Installation Script. Simply run the following command on your Azure VM to restore the Azure VM to pre-deployment:

 ```powershell
   & C:\AzHCI_Sandbox\AzSHCISandbox-main\New-AzSHCISandbox.ps1 -Delet $True
   ```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit <https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.


Contributions & Legal
Contributing
This project welcomes contributions and suggestions. Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the Microsoft Open Source Code of Conduct. For more information see the Code of Conduct FAQ or contact opencode@microsoft.com with any additional questions or comments.

Legal Notices
Microsoft and any contributors grant you a license to the Microsoft documentation and other content in this repository under the Creative Commons Attribution 4.0 International Public License, see the LICENSE file, and grant you a license to any code in the repository under the MIT License, see the LICENSE-CODE file.

Microsoft, Windows, Microsoft Azure and/or other Microsoft products and services referenced in the documentation may be either trademarks or registered trademarks of Microsoft in the United States and/or other countries. The licenses for this project do not grant you rights to use any Microsoft names, logos, or trademarks. Microsoft's general trademark guidelines can be found at http://go.microsoft.com/fwlink/?LinkID=254653.

Privacy information can be found at https://privacy.microsoft.com/en-us/

Microsoft and any contributors reserve all other rights, whether under their respective copyrights, patents, or trademarks, whether by implication, estoppel or otherwise.
