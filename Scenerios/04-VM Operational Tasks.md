# Lab 04 Operational Tasks

## Objective

In these scenarios, we will perform daily maintenance tasks that any HCI Fabric Administrator should be familiar with , these include tasks like:

1. Live Migration
2. Storage Migration
3. VM Hardware Changes
4. Re-Size Cluster Shared Volumes


### Exercise 01: Live Migration

In this exercise you need to perform Live Migrations on your Virtual Machines to ensure High Availability in your cluster. This will ensure you can perform Host Maintenance tasks, with no interruption to the Virtual Machines, load balance the VMs for optimal performance and more. Live Migration is a cornerstone feature of any virtualization platform, and the process should be seamless.

1) In Windows Admin Center, navigate to cluster manager for the AZStackCluster, from there you will need to select the Virtual Machines section under Compute. In the 2103+ release of Windows Admin Center, the Inventory is place front and center, in previous versions you will need to visit the Inventory.

2) Select one of the Virtual Machines we created in the previous steps, either TenantVM1 or TenantVM2, or if you decided to create you own Virtual Machine, select it with the checkbox on the left. 

3) Use the drop down Menu for Manage and then select Move.

4) Select a VM and Storage Migration, with a destination type of  Failover Cluster. You can then choose to select the Member Server (Destination) node that you would like, or allow the cluster to automatically select the node with the most resources available to it. 

![alt text](media/Screenshots/04-res/04-0101.png "Move Screen for Live Migration")

### Exercise 02: Storage Migration

In this exercise we need to move our Virtual Machines to another Cluster Shared Volume, this could be done for a variety of reasons, including the CSV is filling up, for migration purposes, Storage QOS reasons and more. The process is very simple, and similar to a live migration, where the storage is migrated in the background.

**If you only have one Cluster Shared Volume, please visit the Creating an S2D Volume and create an additional volume, this will be needed to move your Virtual Machine to another Volume**
 
1) In Windows Admin Center, navigate to cluster manager for the AZStackCluster, from there you will need to select the Virtual Machines section under Compute. In the 2103+ release of Windows Admin Center, the Inventory is place front and center, in previous versions you will need to visit the Inventory.

2) Select one of the Virtual Machines we created in the previous steps, either TenantVM1 or TenantVM2, or if you decided to create you own Virtual Machine, select it with the checkbox on the left. 

3) Use the drop down Menu for Manage and then select Move.

4) Select a Storage Migration and for the Destination, keep the default of; "Move all the VM's files to the same path," then select the path for the cluster shared volume you want to move the VM to. 

![alt text](media/Screenshots/04-res/04-0202.png "Move Screen for Storage Migration")

5) Select the Move button in the Wizard, in the bottom right corner and monitor the job in the Notifications of Windows Admin Center.
6) You can achieve the same result in powershell, using the following commands:

```Powershell
Get-VM -Name TenantVM2 -ComputerName AZSHOST2 | Move-VMStorage -DestinationStoragePath '\\azshost2\c$\ClusterStorage\Demo\VMs' 
```

### Excercise 03: Resize-CSV 

In this exercise we will be re-sizing a Cluster Shared Volume, this is a very common task that can be done rather quickly via Admin Center, or PowerShell. 

1) In Windows Admin Center, navigate to the cluster manager for the AZStackCluster, from there, select Volumes under the Storage Section. Here you will see the summary page of the volumes, and you can identify quickly the health, performance and alerts on your volumes. 

2) Select the Inventory tab, then select one of your volumes, that you would like to expand.

3) Select the Expand button, then fill in the desired size, notice the tool is dynamic and updates you on the estimated additional footprint needed, the total storage available and the new footprint total. 

![alt text](media/Screenshots/04-res/04-0303.png "Expand Volume Screen-WAC")

4) Select Expand and Monitor the Notifications in Admin Center to ensure the job completed.
   
5) To complete the same task in PowerShell, use the following command:

##### If the disk is **NOT** using Storage Tiers:

```PowerShell
Get-VirtualDisk S2D_vDisk1 | Resize-VirtualDisk -Size 300GB
```

##### If the disk **IS** using StorageTiers

```PowerShell
Get-VirtualDisk [friendly_name] | Get-StorageTier | Select FriendlyName
Get-StorageTier [friendly_name] | Resize-StorageTier -Size [size]
```
After you have resized the Disk, you will need to Resize the partition:

**Choose virtual disk**
```Powershell
$VirtualDisk = Get-VirtualDisk S2D_vDisk1
```
**Get its partition**
```PowerShell
$Partition = $VirtualDisk | Get-Disk | Get-Partition | Where PartitionNumber -Eq 2
```

**Resize to its maximum supported size**
```PowerShell
$Partition | Resize-Partition -Size ($Partition | Get-PartitionSupportedSize).SizeMax
```

*Please note, a Nested 2 Way Mirror Volume can not be Expanded using Admin Center at this time, it is a known issue and is being corrected, until then please use PowerShell to expand nested mirror volumes.* 
