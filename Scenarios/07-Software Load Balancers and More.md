# Lab 03 : Software Load Balancers (and NAT), iDNS, and other things...


## Objective

In this series of exercises, you will learn to configure software load balancing, inbound NAT, outbound NAT, as well as deploy iDNS, and guest clusters with a floating IP.

# Lab 03.01 Create a public VIP for load balancing a pool of two VMs on a virtual network

In this lab, you will deploy a solution with the following requirements:

1. Deploy two web server VMs.
2. Load balance these VMs on Ports 80 (Web) and 3389 (RDP).
3. Ensure that a health probe is enabled for the website.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-01.png "Run SDN Explorer") 

## Exercise 01: Deploy the Web Server VMs

1. In the **Console** VM, open a **PowerShell** console with Admin rights.

2. In the PowerShell console, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

3. Run ``.\03.01_Create_WebServerVMs.ps1``

4. Wait for the script to successfully complete

> This script:
     1. Creates two Windows Server (Desktop Experience) VHD files for WebServerVM1 and WebServerVM2, injects a unattend.xml
     2. Creates the WebServerVM1 and WebServerVM2 virtual machines
     3. Adds WebServerVM1 and WebServerVM2 to the SDNCluster
     4. Creates a VM Network and VM Subnet in Network Controller
     5. Creates WebServerVM1 and WebServerVM2 Network Interfaces in Network Controller
     6. Sets the port profiles on WebServerVM1 and WebServerVM2 Interfaces

## Exercise 02: Deploy the Load Balancer

In this exercise, you will run a script that will create the Load Balancer and VIP for the DIPs (WebServerVM1/VM2). The Load Balancer will forward TCP traffic for ports 80 and 3389.

1. From the desktop on the console VM, load the PowerShell ISE with Admin Rights.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-03.png "PowerShell ISE") 

1. In the PowerShell ISE, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

2. Load the file ``.\03.01_LoadBalanceWebServerVMs.ps1``

3. Examine the PowerShell Script to see how the Load Balancer is provisioned.

4. Run the script.

5. After the script completes, take note of the VIP that was assigned.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-02.png "Get the VIP") 

## Exercise 03: Test the Load Balancer

In this exercise, you will test out the load balancer.

1. From the desktop on the console VM, load the PowerShell Console with Admin Rights.

2. To test to see if the RDP Server is working, run the following command:  ``mstsc /v:<vip ipaddress>``

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-04.png "RDP Command Line Logon") 

1. You should see a password prompt. After entering the password, you should receive a certificate warning dialog. Note that you are being routed to either WebServerVM1 or WebServerVM2.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-05.png) "RDP Certificate Warning Dialog") 

4. After connecting with RDP, log out of the RDP Session.

5. Next, open up a web browser and navigate to ``http://<vip ipaddress>``.

> **Note:** Please use HTTP and not HTTPS.

6. In the browser, take a look at the server being connected to. Notice that if you hit refresh on the browser, you are redirected to the same server. In order to see load balancer switching servers, you will need to open multiple InPrivate browser tabs and connect to the VIP until you connect to the other server.

## Exercise 04: Examine Load Balancer Deployment with SDN Explorer

In this exercise, you will use SDN Explorer to view load balancer configuration in the Network Controller database.

1. Log into **Console** using RDP.
2. On the desktop, **Right-Click** on the **SDN Explorer** shortcut and select **Run with PowerShell**.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-06.png "Run SDN Explorer") 

1. SDN Explorer will now appear.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-07.png "This is SDN Explorer") 

1. In SDN Explorer, select Public IP Addresses. 

2. Next, select the WEBLB-IP button.

3. In the WEBLB-IP configuration, take note of the Public IP address and the reference to the WEBLB load balancer configuration.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-08.png "SDN Explorer Public IP") 

1. Next, go back to the SDN Explorer main menu and click Load Balancer, select the WEBLB and then view its properties. Notice the references to the Backend Servers (Network Interfaces) which are the web servers, and the load balancer rules which are located below in the configuration. 

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-09.png "SDN Explorer Load Balancer") 

If you look at the load balancer rules below, you can see the rules for ports 80 and 443. Notice the ```enableFloatingIP``` setting. We'll look at this in lab 3.04.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-10.png "SLB Rules") 

And finally, you can see the health probe that was also created:

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-11.png "SLB Health Probe") 

## Exercise 05: Examine Load Balancer Deployment and BGP

Part of the process of creating a load balancer is the creation of the VIP. In the examples in the previous exercises, my VIP was 40.40.40.2 (*your VIP may differ in your lab*). One the VIP is assigned, how are you able to type ```http://40.40.40.2``` in your browser and your network knows where to route to for that IP?  In this case, the answer is Border Gateway Protocol (BGP). 

>In this exercise, we will log into the Top-of-Rack switch and take a look at the BGP Peering. In our simulated lab, we our using a Windows Server (*bgp-tor-router*) running Routing and Remote Access Server as our router. In a production environment, you most likely would be connecting to real physical switches.

1. Log into **Console** using RDP

2. Open the link to Windows Admin Center on the desktop

3. Select **bgp-tor-router** from the menu

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-12.png "Select bgp-tor-router") 

4. Next, select **PowerShell** and logon.

5. After logging in, run the PowerShell command ```Get-BGPPeer```

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-13.png "Get-BGPPeer") 

In the output, you will see that the one SLB VM and one RAS Gateway VM are peering with the router and show in a connected state. The RAS Gateway VM that is not connected is a standby Gateway VM.

4. Next, we will want to see the BGP routes that the bgp-tor-router has learned. Run the PowerShell command: ```Get-BGPRouteInformation```

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-14.png "Get-BGPRouteInformation") 

In the output, you will see your VIP with the next hop being the IP Address (Provider Network) of the MUX VM. So the flow will go:

    a. User enters http://40.40.40.2 in their browser.
    b. The **bgp-tor-router** then routes the request to the MUX VM.
    c. The MUX VM looks up the DIPs associated with the VIP and if the port matches up to what it can forward.
    d. The packet goes to one of the WebServerVMs.
    e. The response goes directly out through the Hyper-V Host's VMSwitch that the server is on. This is known as Direct Server Reture (DSR).

## Exercise 06: Change the Load Balancer (Remove RDP Access)

The purpose of this exercise is to show you that you can change the configuration on some Network Controller components without having to redeploy them. In this exercise, you will remove the RDP rule from the load balancer that you created earlier.

1. In the **Console** VM, open a **PowerShell** console with Admin rights.

2. In the PowerShell console, type the following command and then press enter:

```Remove-NetworkControllerLoadBalancingRule -ResourceId RDP -LoadBalancerId WEBLB -ConnectionUri $uri```

3. To test to see if the RDP Server is still working, run the following command:  ``mstsc /v:<vip ipaddress>``

You should not be able to connect to the server.


## Exercise 07: Remove the Load Balancer

The purpose of this exercise is to show you how to remove a load balancer.

1. In the **Console** VM, open a **PowerShell** console with Admin rights.

2. In the PowerShell console, type the following commands and then press enter:

```Remove-NetworkControllerLoadBalancer -ResourceId "WEBLB" -ConnectionUri $uri -Force``` 

```Remove-NetworkControllerPublicIpAddress -ResourceId WEBLB-IP -ConnectionUri $uri -Force```

3. Using SDN Explorer, verify that this load balancer no longer exists.

# Lab 03.02 Use SLB for outbound NAT

In this lab we will be configuring a SLB for OUTBOUND NAT that will be able to access the Internet. The following diagram details what you will be creating:

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-15.png) "Diagram of LAB 03.02") 

## Exercise 01: Create and configure a Load Balancer and assign it to WebServerVM1's network interface

1. From the desktop on the console VM, load the PowerShell ISE with Admin Rights.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-03.png "PowerShell ISE") 

2. In the PowerShell ISE, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

3. Load the file ``.\03.02_Create_SLB_for_Outbound_NAT.ps1``

4. Examine the PowerShell Script to see how the Load Balancer is provisioned.

5. Run the script.

## Exercise 02: Test Outbound NAT

1. In the **Console** VM, open up the **Hyper-V Manager** MMC from the desktop.

2. In Hyper-V Manager, navigate to **SDNHOST3** and then connect and logon to **WebServerVm1**

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-16.png "Hyper-V-Manager") 

3. In WebServerVM1, open a **CMD console** or **PowerShell Console**

4. In the console, run the following command: ```ping console.contoso.com```.

5. You will notice that this command will not work due not being able to resolve the FQDN.

6. Let's try pinging the IP address of the console server which is 192.168.1.10 instead...

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-17.png "Failure!") 

1. Let's try one more thing. Let's create a network share to the console VM's address. Enter the following command:

```net use z: \\192.168.1.10\c$```

8. This command should work and you should now be able to connect to the console VM through the Z drive:.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-18.png"Success!") 

In conclusion, you now know that you cannot ```ping``` the resources, you don't have any name resolution, but you can connect through TCP to systems outside of your network. It is now obvious that the only way to easily provide connections to the outside network to your tenants is to provide name resolution to your Tenant VMs.


# Lab 03.03 iDNS to the Rescue!

Hosted virtual machines (VMs) and applications require DNS to communicate within their own networks and with external resources on the Internet. With iDNS, you can provide tenants with DNS name resolution services for their isolated, local name space and for Internet resources.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-19.png "Success!")

>**Note:** Because the iDNS service is not accessible from tenant Virtual Networks, other than through the iDNS proxy, the server is not vulnerable to malicious activities on tenant networks

## Exercise 01: Deploy iDNS

In this exercise, we will run a script that will install and configure iDNS.

1. From the desktop on the console VM, load the PowerShell ISE with Admin Rights.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-03.png "PowerShell ISE") 

1. In the PowerShell ISE, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

2. Load the file ``.\03.03_Deploy_iDNS.ps1``

3. Examine the PowerShell Script to see how iDNS is provisioned.

4. Run the script.

## Exercise 02: Test iDNS

1. In the **Console** VM, open up the **Hyper-V Manager** MMC from the desktop.

2. In Hyper-V Manager, connect to Hyper-V Server **SDNHOST3** and then connect and logon to **WebServerVm1**

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-16.png "Hyper-V-Manager") 

1. In WebServerVM1, open a **CMD console** or **PowerShell Console** with admin rights

2. In the console, run the following command: ```ping console.contoso.com```.

3. You will notice that while ping is still not working (ICMP is blocked by default by the SLB), the FQDN resolves the correct IP using the DNS server running on Admin Center.

4. Next, open a browser and navigate to ```microsoft.com```.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-20.png "Outbound NAT working...") 

You should now see that web access is working.


## Exercise 03: Examine DNS Server

 1. From the desktop on the console VM, click on **DNS**

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-22.png "DNS Shortcut") 

1. In the **Connect to DNS Server** dialog, enter **Admincenter** for the computer that is hosting you tenant DNS.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-21.png  "Connect to DNS Server) 

1. In **DNS Manager**, expand **Forward Lookup Zones** and then expand **tenantsdn.local** you will notice that there are no records of note listed. 

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-24.png "Empty DNS") 

1. In **Hyper-V Manager** or **Windows Admin Center**, restart WebServerVM1 and WebServerVM2.

2. After the VMs have finished restarting, navigate back to to **DNS Manager** and refresh **tenantsdn.local**. You should now see records under **tenantsdn.local**.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-25.png  "We have records in DNS!")

As you can see, you now have entries in DNS. This means that you now have the ability to resolve names of other tenant VMs within your VM Network. In the next exercise you will test this out.

## Exercise 04: Examine Tenant DNS Resolution

In this exercise you will see how iDNS allows you to resolve names of other tenant VMs within you VM Network.

1. In **Hyper-V Manager** or **Windows Admin Center**, connect to and logon to the virtual machine **WebServerVM1**.

2. In **WebServerVM1**, open a **CMD** or **PowerShell** console and type the following commands:

```nslookup WebServerVM2```

```ping WebServerVM2```

You should be able to resolve the ip for **WebServerVM2** as well as ping **WebServerVM2** from **WebServerVM1**.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-26.png "We have records in DNS!")


# Lab 03.04 Use the Software Load Balancer for forwarding traffic

If you need to map a Virtual IP to a single network interface on a virtual network without defining individual ports, you can create an L3 forwarding rule. This rule forwards all traffic to and from the VM via the assigned VIP contained in a PublicIPAddress object.

>**Note:** If you defined the VIP and DIP as the same subnet, then this is equivalent to performing L3 forwarding without NAT using a RAS Gateway.

## Exercise 01: Create Forwarding VIP

In this exercise, we will run a script to create the forwarding public VIP (```40.40.40.30```) and attach that VIP to a network interface.

1. From the desktop on the console VM, load the PowerShell ISE with Admin Rights.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-03.png  "PowerShell ISE") 

1. In the PowerShell ISE, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

2. Load the file ``.\03.04_Create_Forwarding_VIP.ps1``

3. Examine the PowerShell Script to see how the public VIP is provisioned and assigned.

4. Run the script.

## Exercise 02: Test Forwarding VIP

Testing the forwarding VIP can be accomplished in many ways. Since the SLB is forwarding **ALL** traffic in both directions to the specified network interface, you can connect to this interface using UDP/TCP. 

>**Note:** You still won't be able to ping the VIP unless you configure the SLB to respond to ICMP traffic.

1. From the **console** vm, using Windows Explorer, navigate to ```\\40.40.40.30\c$```
2. From the **console** vm, RDP to ```40.40.40.30```

## Exercise 03: Remove Forwarding VIP

In this exercise, we will run a script to remove forwarding public VIP that was created in Exercise 01.

1. From the desktop on the console VM, load the PowerShell ISE with Admin Rights.

![alt text](https://github.com/microsoft/AzStackHCISandbox/blob/188ef296e33892e7ee0cdf29e5112a2e8e99998b/Scenarios/Media/Screenshots/07-res/3-03.png  "PowerShell ISE") 

1. In the PowerShell ISE, navigate to ``C:\SCRIPTS\LABS\03_Software_Load_Balancers_NAT\``

2. Load the file ``.\03.04_Delete_Forwarding_VIP.ps1``

3. Examine the PowerShell Script to see how the public VIP is removed.

4. Run the script.

