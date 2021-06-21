Now that we have the cluster Registered and you have some familiarity with the Admin Center Cluster Manager toolset, we can begin setting up our HCI Cluster. The first step is to ensure we are getting performance information on our Storage Spaces Direct Volumes and Disks. Then we can create a Volume, where we will take advantage of the different topologies available to us. We will ensure we have performance and security enabled features on our volumes as well as understand every day maintenance activities. 


Enable Cluster Storage Performance
Navigate to one of the cluster nodes, you can do this in one of 2 ways.
	1) Switch Admin Center over to Server Manager and select one of the ASZHost nodes. 
	2) In Cluster Manager, Select Servers under the compute Menu, then select Inventory. Click the hyperlink for one of the Host nodes, then select the Manage button. 
	3) Once you are managing a HCI Node, select the PowerShell extension, and log in to your remote PowerShell session.
	4) Run the command "Start-ClusterPerformanceHistory" 
	5) This will create a new volume



Creating Volumes
Now we are ready to create some volumes in Admin Center. First we will create a Two-Way Mirrored volume, directly in Admin Center, then because we are running a 2 node cluster, we will want to build a Nested-Resiliancy Volume in both a Mirrored and Parity configuration, which we will do in PowerShell. Lastly we will want to turn on Data-Deduplication for these nodes.

Lets start in Cluster Manager, start by selecting Volumes.
	
	1) Select Inventory
   
	2) Select the Create button.
   
	3) In the Create Volume wizard, fill in the values. You can use the sample values below, or provide your own.
		Name: MirroredVolume1
		Resiliency: Two-Way Mirror
		Size on HDD: 100 GB
		More Options: Use Integrity Checksums

	4) Click Create
	
	![alt text](media/Screenshots/02-res/02-res-01-01.png "Create Volume Wizard-WAC")
	
	Notice the size of the footprint is dynamic, as you choose a larger size, the footprint shows that. In the case of a two way mirror, the 100GB volume, uses 200Gb of space on the Storage Pool.
	
	A two way mirror, as you may recall from the class, means the blocks are written across each server. This means we can loose one of your server nodes, and the volumes will remain operational. This is great, except what would happen, if in the server that is still online a single hard drive went offline, your volumes will go offline, and so will your virtual machines. So we can solve this with Nested Resiliancy, or creating a 2 way mirror across the cluster, then a 2 way mirror in each node. We can only do this in PowerShell and will need to use Storage Tiers to do so.
	
	
	Storage Spaces Direct in Windows Server 2019 offers two new resiliency options implemented in software, without the need for specialized RAID hardware:
		• Nested two-way mirror. Within each server, local resiliency is provided by two-way mirroring, and then further resiliency is provided by two-way mirroring between the two servers. It's essentially a four-way mirror, with two copies in each server. Nested two-way mirroring provides uncompromising performance: writes go to all copies, and reads come from any copy.
		• Nested mirror-accelerated parity. Combine nested two-way mirroring, from above, with nested parity. Within each server, local resiliency for most data is provided by single bitwise parity arithmetic, except new recent writes which use two-way mirroring. Then, further resiliency for all data is provided by two-way mirroring between the servers. For more information about how mirror-accelerated parity works, see Mirror-accelerated parity.
		
	
	
	Open up PowerShell on the Node in admin Center you can do this in one of 2 ways.
		1) Switch Admin Center over to Server Manager and select one of the ASZHost nodes. 
		2) In Cluster Manager, Select Servers under the compute Menu, then select Inventory. Click the hyperlink for one of the Host nodes, then select the Manage button. 
		3) In PowerShell we will create 2 Storage Tiers, one for Nested Mirror and one for Nested Parity.
		4) Run the following PowerShell Commands:
			
			# For mirror
			$storagetier=New-StorageTier -StoragePoolFriendlyName SDN* -FriendlyName NestedMirrorDemo -MediaType SSD -ResiliencySettingName mirror -NumberOfDataCopies 4 
			
			
		5) To create the Nested Mirror, run this command:
			i. New-Volume -FriendlyName Demo -StoragePoolFriendlyName SDN* -FileSystem CSVFS_ReFS -StorageTierFriendlyNames $storagetier.FriendlyName -StorageTierSizes 100gb -Verbose
	
			
			
	Install Data Deduplication
	
	To enable Deduplication on our Volumes, we will need to install the feature on both nodes in the cluster. In the Server Manager on one of the nodes, select the Roles & Features extension in Admin Center. 
		1) Find the feature named Data Duplication under the File and Storage Services section.
		2) Select Install and wait for that to complete. No reboot is necessary.
		3) Repeat these steps on the other node in the cluster
		4) Optionally instead run the following command in PowerShell:
			i. Install-WindowsFeature -Name FS-Data-Deduplication 
	
	
	Now we can enable deduplication features on our volumes. Navigate back to the Cluster Manager for your HCI cluster, and go to Volumes-Inventory.
		1) Select one of the volumes, and click the hyperlink.
		2) In the Volume options, under Optional Features enable the Deduplication and Compression
		3) In the Deduplication Mode change the setting to Hyper-V, but you can visit this link, to see the options fully explained.
		4) Enable Deduplication
		5) After some time, all duplicated files will be removed and consolidated down to save you space, and you will see that savings grow as we load more virtual machines on to this Cluster Shared Volume, for now we don’t expect any savings.
	
	
		
		
