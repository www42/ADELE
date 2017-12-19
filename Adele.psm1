function New-AdeleDomainController {
  #region Parameters
[CmdletBinding()]Param(
[Parameter(Mandatory=$true,  Position=1)][string]$VmComputerName,
[Parameter(Mandatory=$true,  Position=2)][string]$IpAddress,
[Parameter(Mandatory=$false, Position=3)][string]$PrefixLength    = $Global:LabIpPrefixLength,
[Parameter(Mandatory=$false, Position=4)][string]$DefaultGw       = $Global:LabIpDefaultGw,
[Parameter(Mandatory=$false, Position=5)][string]$DnsServer       = $Global:LabIpDnsServer,
[Parameter(Mandatory=$false, Position=6)][string]$AdDomain        = $Global:LabAdDomain,
[Parameter(Mandatory=$false, Position=7)][string]$AdDomainNetBios = $Global:LabAdDomainNetBios,
[Parameter(Mandatory=$false, Position=8)][string]$Pw              = $Global:LabPw
)
  #endregion
  #region Variables
    $ForegroundColor = "DarkCyan"
    $IfAlias   = "Ethernet"
    $VmName    = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab
    $LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString $Pw -AsPlainText -Force)
    $DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString $Pw -AsPlainText -Force)
    
    # DNS stuff
    $NetworkId     = '10.80.0.0/16'
    $ZoneName      = "80.10.in-addr.arpa"
    $Name          = "10.0"
    $PtrDomainName = "DC1.Adatum.com."
    
    # DHCP stuff
    $DhcpStartRange = "10.80.99.1"
    $DhcpEndRange   = "10.80.99.199"
    $DhcpSubnetMask = "255.255.0.0"
    $DhcpDnsServer  = "10.80.0.10"
    $DhcpRouter     = "10.80.0.1"
    
    Write-Host -ForegroundColor $ForegroundColor "   Variables                                    " -NoNewline
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Create VM
    Write-Host -ForegroundColor $ForegroundColor "   Create VM                                    " -NoNewline
    New-LabVmDifferencing -VmComputerName $VmComputerName
    Start-LabVm -VmComputerName $VmComputerName
    
    # Wait for specialize and oobe
    Start-Sleep -Seconds 180
    
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Configure static IP address
    Write-Host -ForegroundColor $ForegroundColor "   Configure static IP address                  " -NoNewline
    Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw | Out-Null
    }
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Dcpromo New Forest
    Write-Host -ForegroundColor $ForegroundColor "   Dcpromo New Forest                           " -NoNewline
    Invoke-Command -VMName $VmName -Credential $LocalCred {
    $SecureModePW=ConvertTo-SecureString -String $using:Pw -AsPlainText -Force
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
    Import-Module ADDSDeployment 
    Install-ADDSForest `
        -DomainName $Using:AdDomain `
        -DomainNetbiosName $Using:AdDomainNetBios `
        -DomainMode "WinThreshold" `
        -ForestMode "WinThreshold" `
        -InstallDns:$true `
        -CreateDnsDelegation:$false `
        -SafeModeAdministratorPassword $SecureModePW `
        -DatabasePath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -LogPath "C:\Windows\NTDS" `
        -NoRebootOnCompletion:$false `
        -Force:$true `
        -WarningAction Ignore | Out-Null
    }
    Start-Sleep -Seconds 360
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Configure DNS Server
    Write-Host -ForegroundColor $ForegroundColor "   Configure DNS Server                         " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {   
      Add-DnsServerPrimaryZone -NetworkId $using:NetworkId -ReplicationScope Domain -DynamicUpdate Secure
      Add-DnsServerResourceRecordPtr -ZoneName $using:ZoneName -Name $using:Name -PtrDomainName $using:PtrDomainName
      Add-DnsServerForwarder -IPAddress 8.8.8.8
      Remove-DnsServerForwarder -IPAddress fec0:0:0:ffff::1,fec0:0:0:ffff::2,fec0:0:0:ffff::3 -Force
    }
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Install and configure DHCP Server
    Write-Host -ForegroundColor $ForegroundColor "   Install and configure DHCP Server            " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {

    Install-WindowsFeature -Name DHCP -IncludeManagementTools | Out-Null

    Add-DhcpServerSecurityGroup
    Restart-Service -Name DHCPServer
    Start-Sleep 60
    Add-DhcpServerInDC

    # tell server manager post-install completed
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2

    # server options
    Set-DhcpServerv4OptionValue -DnsDomain "Adatum.com"

    # new scope with scope options
    Add-DhcpServerv4Scope -Name "Deployment" `
                      -StartRange $using:DhcpStartRange `
                      -EndRange   $using:DhcpEndRange `
                      -SubnetMask $using:DhcpSubnetMask -PassThru |
        Set-DhcpServerv4OptionValue -DnsServer $using:DhcpDnsServer `
                                    -Router $using:DhcpRouter
    }
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Disable IE Enhanced Security Configuration
    Write-Host -ForegroundColor $ForegroundColor "   Disable IE Enhanced Security Configuration   " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
    $ESCAdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $ESCUserKey  = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $ESCAdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $ESCUserKey  -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer -ErrorAction SilentlyContinue
    }
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Ensure FW Domain Profile
    Write-Host -ForegroundColor $ForegroundColor "   Ensure FW Domain Profile                     " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
    Disable-NetAdapter -Name $using:IfAlias -Confirm:$false
    Enable-NetAdapter -Name $using:IfAlias
    Start-Sleep -Seconds 10
}
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #region Password never expires
    Write-Host -ForegroundColor $ForegroundColor "   Password never expires                       " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
    Set-ADUser -Identity Administrator -PasswordNeverExpires $true
}
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Install Adatum CA
    Write-Host -ForegroundColor $ForegroundColor "   Install Adatum CA                            " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
    Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools | Out-Null
    Install-AdcsCertificationAuthority -CACommonName "Adatum CA" -CAType EnterpriseRootCA -Force | Out-Null
}
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
}
function New-AdeleMemberServer {
  #region Parameters
    [CmdletBinding()]Param(
    [Parameter(Mandatory=$true,  Position=1)][string]$VmComputerName,
    [Parameter(Mandatory=$true,  Position=2)][string]$IpAddress,
    [Parameter(Mandatory=$false, Position=3)][string]$PrefixLength = $Global:LabIpPrefixLength,
    [Parameter(Mandatory=$false, Position=4)][string]$DefaultGw    = $Global:LabIpDefaultGw,
    [Parameter(Mandatory=$false, Position=5)][string]$DnsServer    = $Global:LabIpDnsServer,
    [Parameter(Mandatory=$false, Position=6)][string]$AdDomain     = $Global:LabAdDomain,
    [Parameter(Mandatory=$false, Position=7)][string]$Pw           = $Global:LabPw
    )
  #endregion
  #region Variables
    $ForegroundColor = "DarkCyan"
    $IfAlias   = "Ethernet"
    $VmName    = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab
    $LocalCred = New-Object System.Management.Automation.PSCredential        "Administrator",(ConvertTo-SecureString $Pw -AsPlainText -Force)
    $DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString $Pw -AsPlainText -Force)
    Write-Host -ForegroundColor $ForegroundColor "   Variables                                    " -NoNewline
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Create VM
    Write-Host -ForegroundColor $ForegroundColor "   Create VM                                    " -NoNewline
    New-LabVmDifferencing -VmComputerName $VmComputerName 
    Start-LabVm -VmComputerName $VmComputerName
    
    # Wait for specialize and oobe to complete
    Start-Sleep -Seconds 180
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Rename and IP configuration
    Write-Host -ForegroundColor $ForegroundColor "   Configure static IP address                  " -NoNewline
    Invoke-Command -VMName $VmName -Credential $LocalCred {
    New-NetIPAddress -InterfaceAlias $Using:IfAlias -IPAddress $Using:IpAddress -PrefixLength $Using:PrefixLength -DefaultGateway $Using:DefaultGw | Out-Null
    Set-DnsClientServerAddress -InterfaceAlias $Using:IfAlias -ServerAddresses $Using:DnsServer  | Out-Null
    } 
    # Wait for reboot
    Start-Sleep -Seconds 60
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Join Domain
    Write-Host -ForegroundColor $ForegroundColor "   Join Domain                                  " -NoNewline
    Invoke-Command -VMName $VmName -Credential $LocalCred {

    Add-Computer -DomainName $Using:AdDomain -Credential $Using:DomCred -Restart
    
    }
    Start-Sleep -Seconds 60
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
}
function New-AdeleNVHost {
  #region Parameters
  [CmdletBinding()]Param(
  [Parameter(Mandatory=$true,  Position=1)][string]$VmComputerName,
  [Parameter(Mandatory=$true,  Position=2)][string]$IpAddress,
  [Parameter(Mandatory=$false, Position=3)][string]$PrefixLength    = $Global:LabIpPrefixLength,
  [Parameter(Mandatory=$false, Position=4)][string]$DefaultGw       = $Global:LabIpDefaultGw,
  [Parameter(Mandatory=$false, Position=5)][string]$DnsServer       = $Global:LabIpDnsServer,
  [Parameter(Mandatory=$false, Position=6)][string]$AdDomain        = $Global:LabAdDomain,
  [Parameter(Mandatory=$false, Position=7)][string]$AdDomainNetBios = $Global:LabAdDomainNetBios,
  [Parameter(Mandatory=$false, Position=8)][string]$Pw              = $Global:LabPw
  )
  #endregion
  #region Variables
    $VmName    = ConvertTo-VmName -VmComputerName $VmComputerName -Lab $Lab
    $DomCred   = New-Object System.Management.Automation.PSCredential "Adatum\Administrator",(ConvertTo-SecureString $Pw -AsPlainText -Force)
    $ForegroundColor = "DarkYellow"
    Write-Host -ForegroundColor $ForegroundColor "Variables                                       " -NoNewline
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region New MemberServer
    Write-Host -ForegroundColor $ForegroundColor "New Member Server                                  "
    New-AdeleMemberServer -VmComputerName $VmComputerName `
                          -IpAddress $IpAddress `
                          -PrefixLength $PrefixLength `
                          -DefaultGw $DefaultGw `
                          -DnsServer $DnsServer `
                          -AdDomain $AdDomain `
                          -Pw $Pw
  #endregion
  #region Preparing for Nested Virtualization
    Write-Host -ForegroundColor $ForegroundColor "Preparing for Nested Virtualization             " -NoNewline
    Stop-LabVm -VmComputerName $VmComputerName
    
    Set-VMProcessor -VMName $VmName -ExposeVirtualizationExtensions:$true
    Set-VMMemory -VMName $VmName -DynamicMemoryEnabled:$false -StartupBytes 10GB
    Set-VMNetworkAdapter -VMName $VmName -MacAddressSpoofing On
    
    Start-LabVm -VmComputerName $VmComputerName
    Start-Sleep -Seconds 60
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Installing Hyper-V
    Write-Host -ForegroundColor $ForegroundColor "Installing Hyper-V                              " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
      Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart -WarningAction SilentlyContinue | Out-Null
    }
    Start-Sleep -Seconds 60
    Invoke-Command -VMName $VmName -Credential $DomCred {
       $NetAdapter = Get-NetAdapter
       New-VMSwitch -Name "External Network" -NetAdapterName $NetAdapter.Name | Out-Null
    }
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
  #region Copy Base vhdx
    Write-Host -ForegroundColor $ForegroundColor "Copy Base vhdx                                  " -NoNewline
    Invoke-Command -VMName $VmName -Credential $DomCred {
        Enable-NetFirewallRule -Name FPS-SMB-In-TCP
        New-Item -ItemType Directory -Path c:\Base | Out-Null
    }
    
    New-SmbMapping -LocalPath x: -RemotePath "\\$IpAddress\c$" -UserName "$AdDomainNetBios\administrator" -Password $Pw | Out-Null
    Start-Sleep -Seconds 30
    Copy-Item -Path $LabBaseGen2 -Destination x:\Base
    Remove-SmbMapping -LocalPath x: -Force
    Write-Host -ForegroundColor $ForegroundColor ".... done."
  #endregion
}