
#region Variables

$Lab = "SDN"

$ServerComputerName = "SVR1"
$DcComputerName     = "DC1"


# The ManagementSecurityGroup parameter specifies the name of the security group that contains users 
# that are allowed to run the management cmdlets from a remote computer. This is only applicable if 
# ClusterAuthentication is Kerberos. You must specify a domain security group and not a security group
# on the local computer.
$ManagementSecurityGroup     = "Adatum\Network Controller Admins"
$ManagementSecurityGroupName =        "Network Controller Admins"


# The ClientSecurityGroup parameter specifies the name of the Active Directory security group
# whose members are Network Controller clients. This parameter is required only if you use Kerberos
# authentication for ClientAuthentication. The security group must contain the accounts from which
# the REST APIs are accessed, and you must create the security group and add members before running 
# the "Install-NetworkController" command.
$ClientSecurityGroup     = "Adatum\Network Controller Ops"
$ClientSecurityGroupName =        "Network Controller Ops"

# You do not need to specify a value for RESTIPAddress with a single node deployment of Network Controller.
# For multiple-node deployments, the RESTIPAddress parameter specifies the IP address of the REST endpoint
#in CIDR notation. For example, 192.168.1.10/24. The Subject Name value of ServerCertificate must resolve
# to the value of the RESTIPAddress parameter. This parameter must be specified for all multiple-node
# Network Controller deployments when all of the nodes are on the same subnet. If nodes are on different subnets,
# you must use the RestName parameter instead of using RESTIPAddress.
#$RestIpAddress = "10.70.0.99/16"


$ServerVmName = ConvertTo-VmName -VmComputerName $ServerComputerName
$DcVmName     = ConvertTo-VmName -VmComputerName $DcComputerName
$DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString 'Pa55w.rd' -AsPlainText -Force)

Write-Host -ForegroundColor DarkCyan "Variables.................................... done."

#endregion

#region Create AD groups

Invoke-Command -VMName $DcVmName -Credential $DomCred {

    New-ADGroup -Name $using:ManagementSecurityGroupName `
                -SamAccountName $using:ManagementSecurityGroupName `
                -GroupCategory "Security" `
                -GroupScope "Global" `
                -Path "CN=Users,DC=Adatum,DC=com"

    New-ADGroup -Name $using:ClientSecurityGroupName `
                -SamAccountName $using:ClientSecurityGroupName `
                -GroupCategory "Security" `
                -GroupScope "Global" `
                -Path "CN=Users,DC=Adatum,DC=com"

    Add-ADPrincipalGroupMembership `
                -Identity "CN=Administrator,CN=Users,DC=Adatum,DC=com" `
                -MemberOf "CN=Network Controller Ops,CN=Users,DC=Adatum,DC=com",`
                          "CN=Network Controller Admins,CN=Users,DC=Adatum,DC=com"
}

Write-Host -ForegroundColor DarkCyan "Create AD groups............................. done."

#endregion

#region Install role NetworkController

Invoke-Command -VMName $ServerVmName -Credential $DomCred {
    
    Install-WindowsFeature -Name "NetworkController" -IncludeManagementTools | Out-Null
    Restart-Computer
}

Start-Sleep -Seconds 60

Write-Host -ForegroundColor DarkCyan "Install role NetworkController............... done."

#endregion

#region Deploy NetworkController

Invoke-Command -VMName $ServerVmName -Credential $DomCred {

    Get-Certificate -Template "Machine" -CertStoreLocation "Cert:\LocalMachine\My"
    $Certificate = Get-ChildItem Cert:\LocalMachine\My | where {$_.Subject -imatch $using:ServerComputerName }

    $node = New-NetworkControllerNodeObject `
            -Name          "Node1" `
            -Server        "SVR1.adatum.com" `
            -FaultDomain   "fd:/rack1/host1" `
            -RestInterface "Ethernet" `
            -NodeCertificate $Certificate
    
    Install-NetworkControllerCluster `
            -Node $node `
            -ClusterAuthentication Kerberos `
            -ManagementSecurityGroup $using:ManagementSecurityGroup `
            -CredentialEncryptionCertificate $Certificate | Out-Null

    Install-NetworkController `
            -Node $node `
            -ClientAuthentication Kerberos `
            -ClientSecurityGroup $using:ClientSecurityGroup `
            -ServerCertificate $Certificate | Out-Null
#            -RestIpAddress $RestIpAddress 
}

Write-Host -ForegroundColor DarkCyan "Deploy NetworkController..................... done."

#endregion

#region Validate NetworkController Deployment

$cred=New-Object -TypeName Microsoft.Windows.Networkcontroller.credentialproperties
$cred.type="usernamepassword"
$cred.username="admin"
$cred.value="abcd"
New-NetworkControllerCredential -ConnectionUri https://svr1.adatum.com -Properties $cred -ResourceId cred1 -Force
Get-NetworkControllerCredential -ConnectionUri https://svr1.adatum.com -ResourceId cred1  

#endregion

#region temp useful command to debug

$SVR1 = New-PSSession -VMName $ServerVmName -Credential $DomCred
Enter-PSSession -Session $SVR1

Get-NetworkController
Get-NetworkControllerDeploymentInfo -NetworkController SVR1

Get-NetworkControllerServer -ConnectionUri "https://SVR1.Adatum.com" -Verbose

# OVSDB
netstat –anp tcp |findstr 6640

Get-Service NCHostAgent
Get-Service SlbHostAgent


Debug-NetworkControllerConfigurationState -NetworkController svr1.adatum.com -Verbose 


Get-Module -ListAvailable -Name *fabric*
Get-Command -Module ServiceFabric

Debug-ServiceFabricNodeStatus -ServiceTypeName "VSwitchService"


#endregion 

#region Add server

# Example 1: Add a server
# -----------------------

# The first command creates a CredentialProperties object, and then stores it in the $CredentialProperties variable.
# $CredentialProperties = [Microsoft.Windows.NetworkController.CredentialProperties]@{Type="UsernamePassword";UserName="admin";Value="password"}
$CredentialProperties = [Microsoft.Windows.NetworkController.CredentialProperties]@{Type="UsernamePassword";UserName="admin";Value="password"}

# The second command creates a credential that has the properties in $CredentialProperties by using the New-NetworkControllerCredential cmdlet.
# New-NetworkControllerCredential -ResourceId "Credential01" -ConnectionUri "https://restserver" -Properties $CredentialProperties
New-NetworkControllerCredential -ResourceId "Credential01" -ConnectionUri "https://svr1.adatum.com" -Properties $CredentialProperties

# The third command gets the credential by using the Get-NetworkControllerCredential cmdlet, and then stores it in the $Credential variable.
# $Credential = Get-NetworkControllerCredential -ResourceId "Credential01" -ConnectionUri "https://restserver"
$Credential = Get-NetworkControllerCredential -ResourceId "Credential01" -ConnectionUri "https://svr1.adatum.com"

# The fourth command creates a ServerProperties object by using the New-Object cmdlet. The command stores the object in the $ServerProperties variable.
$ServerProperties = New-Object Microsoft.Windows.NetworkController.ServerProperties

# The next five commands assign values to properties of $ServerProperties.
# $ServerProperties.Connections = @([Microsoft.Windows.NetworkController.Connection]@{ManagementAddresses=@("192.168.0.12");Credential=$Credential})
$ServerProperties.Connections = @([Microsoft.Windows.NetworkController.Connection]@{ManagementAddresses=@("10.80.0.31");Credential=$Credential})
$ServerProperties.RackSlot = "1"
$ServerProperties.OS = "Windows Server 2016"
$ServerProperties.Vendor = "Dell"
$ServerProperties.Model = "PowerEdge R730"

# The final command adds a server to the Network Controller that has the resource ID Server01. The command identifies the Network Controller by URI.
# The command specifies the properties of the server by using $ServerProperties.
# New-NetworkControllerServer -ConnectionUri "https://networkcontroller" -ResourceId "Server01" -Properties $ServerProperties
New-NetworkControllerServer -ConnectionUri "https://svr1.adatum.com" -ResourceId "Server01" -Properties $ServerProperties

# Hmmmm. So weit - so gut.
# Hat das der Hyper-V Host auch gemerkt?
$NVHOST1 = New-PSSession -VMName SDN-NVHOST1 -Credential $DomCred
Enter-PSSession $NVHOST1
cd \
Get-WindowsFeature -Name *Hyper*
klist tgt
netstat –anp tcp | findstr 6640
Get-Service NCHostAgent,SlbHostAgent | ft Name,DisplayName,StartType,Status

# Nein.

#endregion

#region Create Virtual Networks

Import-Module -Name NetworkController

# Define the Virtual Network
$VirtualNetworkProperties                = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualNetworkProperties
$VirtualNetworkProperties.AddressSpace   = New-Object -TypeName Microsoft.Windows.NetworkController.AddressSpace
$VirtualNetworkProperties.LogicalNetwork = New-Object -TypeName Microsoft.Windows.NetworkController.LogicalNetwork

$VirtualNetworkProperties.LogicalNetwork.ResourceRef = "/LogicalNetworks/HNVPA"
$VirtualNetworkProperties.AddressSpace.AddressPrefixes = "192.168.0.0/16"

# Add a Virtual Subnet for Web Server Tier
$VirtualNetworkProperties.Subnets                                += New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnet
$VirtualNetworkProperties.Subnets[0].Properties                   = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnetProperties
$VirtualNetworkProperties.Subnets[0].Properties.AccessControlList = New-Object -TypeName Microsoft.Windows.NetworkController.AccessControlList

$VirtualNetworkProperties.Subnets[0].ResourceId = "Subnet1"
$VirtualNetworkProperties.Subnets[0].Properties.AddressPrefix = "192.168.1.0/24"
$VirtualNetworkProperties.Subnets[0].Properties.AccessControlList.ResourceRef = "/accessControlList/AllowAll"

# Add a Virtual Subnet for File Server Tier
$VirtualNetworkProperties.Subnets                                += New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnet
$VirtualNetworkProperties.Subnets[1].Properties                   = New-Object -TypeName Microsoft.Windows.NetworkController.VirtualSubnetProperties
$VirtualNetworkProperties.Subnets[1].Properties.AccessControlList = New-Object -TypeName Microsoft.Windows.NetworkController.AccessControlList

$VirtualNetworkProperties.Subnets[1].ResourceId = "Subnet2"
$VirtualNetworkProperties.Subnets[1].Properties.AddressPrefix = "192.168.2.0/24"
$VirtualNetworkProperties.Subnets[1].Properties.AccessControlList.ResourceRef = "/accessControlList/AllowAll"

# Apply the settings
$Uri = "https://svr1.adatum.com"

New-NetworkControllerVirtualNetwork -ResourceId "MyNetwork" -Properties $VirtualNetworkProperties -ConnectionUri $Uri -Verbose -Force

#endregion

#region Create Virtual Network - zweiter Versuch

# erstmal ein Logical Network
$NetworkProperties = New-Object Microsoft.Windows.NetworkController.LogicalNetworkProperties
$NetworkProperties.NetworkVirtualizationEnabled = $False
#New-NetworkControllerLogicalNetwork -ConnectionUri "https://networkcontroller" -ResourceId "Network13" -Properties $NetworkProperties
New-NetworkControllerLogicalNetwork -ConnectionUri $Uri -ResourceId "Network13" -Properties $NetworkProperties -Force

$NetworkProperties = New-Object Microsoft.Windows.NetworkController.LogicalNetworkProperties
$NetworkProperties.NetworkVirtualizationEnabled = $true
New-NetworkControllerLogicalNetwork -ConnectionUri $Uri -ResourceId "LogicalNetwork1" -Properties $NetworkProperties -Force

$LogicalNetwork1 =  Get-NetworkControllerLogicalNetwork -ResourceId "LogicalNetwork1" -ConnectionUri $Uri



$vsubnet = new-object Microsoft.Windows.NetworkController.VirtualSubnet  
$vsubnet.ResourceId = "Contoso_WebTier"  
$vsubnet.Properties = new-object Microsoft.Windows.NetworkController.VirtualSubnetProperties  
$vsubnet.Properties.AddressPrefix = "24.30.1.0/24"  

#Create the Virtual Network  

# Typo!!
#$vnetproperties = new-object Microsoft.Windows.NetworkController.NbVirtualNetworkProperties
$vnetproperties = new-object Microsoft.Windows.NetworkController.VirtualNetworkProperties  

$vnetproperties.AddressSpace = new-object Microsoft.Windows.NetworkController.AddressSpace  
$vnetproperties.AddressSpace.AddressPrefixes = @("24.30.1.0/24")  

# Object angeben, nicht Name
$vnetproperties.LogicalNetwork = "LogicalNetwork1"
$vnetproperties.LogicalNetwork = $LogicalNetwork1

$vnetproperties.Subnets = @($vsubnet)  
#New-NetworkControllerVirtualNetwork -ResourceId "Contoso_VNet1" -ConnectionUri https://networkcontroller -Properties $vnetproperties
New-NetworkControllerVirtualNetwork -ResourceId "Contoso_VNet1" -ConnectionUri $Uri -Properties $vnetproperties -Force -Verbose


#endregion



#--------------------
Enter-PSSession $SVR1

$Uri = "https://SVR1.adatum.com"

$Server = "Server01"
$ServerObj = Get-NetworkControllerServer -ConnectionUri $Uri -ResourceId $Server 
$ServerInstanceId = $ServerObj.InstanceId.ToString()
$ServerInstanceId

Exit-PSSession
#--------------------
$NV1 = New-PSSession -VMName SDN-NVHOST1 -Credential $DomCred
Enter-PSSession $NV1

$Key = "HKLM:\SYSTEM\CurrentControlSet\Services\NcHostAgent\Parameters"
Get-ItemProperty -Path $Key

$ServerInstanceId = "a276608c-9168-4528-8774-efb8a8b8a781"
New-ItemProperty -Path $Key -Name "HostId" -Value $ServerInstanceId -PropertyType String

Get-Service NcHostAgent | ft name,DisplayName,StartType,Status
Set-Service NcHostAgent -StartupType Automatic
Start-Service NcHostAgent
netstat –anp tcp | findstr 6640
Restart-Service NcHostAgent

# Neujahr ------------------------
#
# Certs für ovsdb communication
#    HostAgentCertificate            wo?
#    NetworkControllerCertificate    dassele wie für REST?