# Welcome to the Azure Stack HCI Sandbox. 

In this lab you can do all the normal operations you would expect to do with an Azure Stack HCI Cluster located in your Datacenter or Remote/Branch Office. This Lab is meant to be a nested solution that allows you to test, deploy and understand Azure Stack HCI and all of it's components, including Hyper-V, Failover Clustering, Storage Spaces Direct (S2D) and Software Defined Networking (SDN). In this lab we will focus on management of a 2-node cluster, that has been built and deployed for you, as part of this lab. You can work on the suggested  scenarios presented in this lab documentation, or try out any scenarios you can come up with, the freedom is yours! 

After the deployment is complete, we will have three Virtual Machines on your Azure host, two Azure Stack HCI Hosts named AZSHost1 & 2 and a Management VM, named AZSMGMT. The AZSMGMT VM is another nested Hyper-V Host, that contains 3 more Virtual Machines;

#### AdminCenter: A Windows 10 Workstation with Admin Center installed
#### BGP-TOR-Router: A Windows Server running Routing and Remote Access Server
#### ContosoDC: Windows Server that is our Domain Controller.

![alt text](media/Screenshots/01-res/GettingStarted_1.png "Move Screen for Live Migration")


Start by opening the RDP Connection to AdminCenter located on the Desktop. 

Log into the VM
User Name Contoso\Administrator
Password: Password01

 Make the VM Console a Full Screen to avoid any confusion.

Open Google Chrome and navigate to 
https://admincenter.contoso.com

Log In and Add the Hyper-Converged Cluster AzStackCluster to Windows Admin Center with Network Controller: https://nc01.contosoc.com, you will need to click "Validate" to validate the connection to the Network Controller. You may be prompted to install the Network Controller PowerShell Module, do that and continue.


![alt text](media/Screenshots/01-res/Getting%20Started%202.png "Move Screen for Live Migration")

Now that we have our Cluster connected to Admin Center we can start managing it, The first thing we will want to do is install the Extensions necessary for Admin Center.  

In the Admin Center windows, click the settings icon in the top-right.

	1) Open Extensions
	2) Under "available Extensions" Select the following and Install. They will allow you to install and reboot the Admin Center Session, so you will just have to do a few of the extensions at a time. 
	
	Install these Extensions:
	Active Directory
	DNS
	SDN Gateway Connections
	SDN Load Balancers
	SDN Public IP Addresses
	SDN Route Tables
	
	3) Once the extensions are installed, click "Windows Admin Center" in the top right.
	4) In the drop down menu, labeled "All Connections" switch the menu to "Cluster Manager"
	5) Now select your cluster hyperlink; AzStackCluster.Contoso.com to manage the HCI Cluster.


### Managing your Azure Stack HCI Cluster
Now we can use Windows Admin Center as a central point to manage our Azure Stack HCI cluster, from here we have the 3 fundamental resources in any cloud, public or private; Compute, Networking and Storage. In the next sections of the suggested scenarios we will be building out or cluster in these resources, starting with storage and networking and working over to compute. Take some time now to get familiar with the admin Center portal. When you are ready, we can register the cluster to your Azure Subscription, the first 30 days is free. 

Register the Cluster

In the Cluster Manager, select Settings in the bottom left corner.
	1) Under "Azure Stack HCI" select Azure Stack HCI Registration.
	2) If prompted to install Extensions, proceed with that step.
	3) Click "Register"
	4) Follow the Registration Instructions, using your own Azure Subscription. You will need 

![alt text](media/Screenshots/01-res/Getting%20Started%203.png "Move Screen for Live Migration")



## Register a cluster using PowerShell

Use the following procedure to register an Azure Stack HCI cluster with Azure using a management PC.
 Important

Only Azure users with Owner or User Access Administrator roles can register an Azure Stack HCI cluster with Azure Arc integration.

	1. Install the required cmdlets on your management PC. If you're registering a cluster deployed from the current General Availability (GA) or Public Preview image of Azure Stack HCI, simply run the following command. If your cluster was deployed prior to December 10, 2020, make sure you have applied the November 23, 2020 Preview Update (KB4586852) to each server in the cluster before attempting to register with Azure.

PowerShellCopy
```powershell
Install-Module -Name Az.StackHCI
```
 Note
		You may see a prompt such as Do you want PowerShellGet to install and import the NuGet provider now? to which you should answer Yes (Y).
		
		You may further be prompted Are you sure you want to install the modules from 'PSGallery'? to which you should answer Yes (Y).
		
	2. Perform the registration using the name of any server in the cluster. To get your Azure subscription ID, visit portal.azure.com, navigate to Subscriptions and copy/paste your ID from the list.
 
 ###### Important
If you're registering Azure Stack HCI in Azure China, run the Register-AzStackHCI cmdlet with these additional parameters:
	-EnvironmentName AzureChinaCloud -Region "ChinaEast2"
```powershell

Register-AzStackHCI  -SubscriptionId "<subscription_ID>" -ComputerName Server1
```
This syntax registers the cluster (of which Server1 is a member), as the current user, with the default Azure region and cloud environment, and using smart default names for the Azure resource and resource group. You can also add the optional -Region, -ResourceName, -TenantId, and -ResourceGroupName parameters to this command to specify these values.
 Note
After June 15, 2021, running the Register-AzStackHCI cmdlet will enable Azure Arc integration on every server in the cluster by default, and the user running it must be an Azure Owner or User Access Administrator. If you do not want the servers to be Arc enabled or do not have the proper roles, pass this additional parameter: -EnableAzureArcServer:$false
Remember that the user running the Register-AzStackHCI cmdlet must have Azure Active Directory permissions, or the registration process will not complete; instead, it will exit and leave the registration pending admin approval. Once permissions have been granted, simply re-run Register-AzStackHCI to complete registration.
Authenticate with Azure



To complete the registration process, you need to authenticate (sign in) using your Azure account. Your account needs to have access to the Azure subscription that was specified in step 2 above in order for registration to proceed. Copy the code provided, navigate to microsoft.com/devicelogin on another device (like your PC or phone), enter the code, and sign in there. The registration workflow will detect when you've logged in and proceed to completion. You should then be able to see your cluster in the Azure portal.