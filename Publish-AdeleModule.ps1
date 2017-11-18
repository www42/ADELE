
$ModuleName = "Adele"
$Dir = 'C:\Git\ADELE'

$Repo = "MyGet"
$NuGetApiKey = Read-Host -Prompt "NuGetApiKey" 

Get-PSRepository -Name $Repo | fl Name,SourceLocation,PublishLocation
Publish-Module -Path $Dir -Repository $Repo -NuGetApiKey $NuGetApiKey

# for the first time install via Package Management
#Install-Module -Name $ModuleName -Repository $Repo

Update-Module -Name $ModuleName
Get-Module -Name $ModuleName -ListAvailable | fl Name,Version,ModuleBase