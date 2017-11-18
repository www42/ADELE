
$ModuleName = "Adele"
$Dir = 'C:\Git\ADELE'

$Repo = "MyGet"
$NuGetApiKey = Read-Host -Prompt "NuGetApiKey" 

Get-PSRepository -Name $Repo | fl Name,SourceLocation,PublishLocation
Publish-Module -Path $Dir -Repository $Repo -NuGetApiKey $NuGetApiKey

# for the first time install via Package Management
#Install-Module -Name $ModuleName -Repository $Repo

Update-Module -Name $ModuleName
Import-Module -Name $ModuleName -Force
Get-Module -Name $ModuleName | fl Name,Version,ModuleBase