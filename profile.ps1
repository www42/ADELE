#  $profile.CurrentUserAllHosts

[string]$Lab                = "PWS"
[string]$LabDir             = "C:\Labs\PWS"
[string]$LabSwitch          = "PWS"
[string]$LabBaseGen1        = "C:\Base\vyos-999.201703132237-amd64.vhd"
[string]$LabBaseGen2        = "C:\Base\Base-WS2016_DesktopExperience_withUpdates1710_en-US.vhdx"
[long]  $LabVmMem           = 2GB
[long]  $LabVmCpuCount      = 2
[string]$LabVmVersion       = "8.0"
[string]$LabIpSubnet        = "10.80.0.0"
[string]$LabIpPrefixLength  = "16"
[string]$LabIpDefaultGw     = "10.80.0.1"
[string]$LabIpDnsServer     = "10.80.0.10"
[string]$LabAdDomain        = "Adatum.com"
[string]$LabAdDomainNetBios = "ADATUM"
[string]$LabPw              = 'Pa55w.rd'


# [string]$Lab                = "10961C"
# [string]$LabDir             = "C:\Program Files\Microsoft Learning\10961\Drives"
# [string]$LabSwitch          = "Private Network"
# [string]$LabIpSubnet        = "172.16.0.0"
# [string]$LabIpPrefixLength  = "16"
# [string]$LabIpDefaultGw     = "172.16.0.1"
# [string]$LabIpDnsServer     = "172.16.0.10"

function prompt {"$Lab> "}

Import-Module -Name "ADELE"
Import-Module -Name "tjLabs" -WarningAction SilentlyContinue
Import-Module -Name "tjTools" -WarningAction SilentlyContinue

Write-Output "Loading Modules ..."
Get-Module    -Name ADELE,tjLabs,tjTools | ft Name,Version

$DomCred = New-Object -TypeName System.Management.Automation.PSCredential 'Adatum\Administrator',(ConvertTo-SecureString $LabPw -AsPlainText -Force)
$LocalCred = New-Object -TypeName System.Management.Automation.PSCredential 'Administrator',(ConvertTo-SecureString $LabPw -AsPlainText -Force)

if (Test-Path $LabDir) {cd $LabDir}
Write-Output "Current Lab is $Lab."
Show-Lab