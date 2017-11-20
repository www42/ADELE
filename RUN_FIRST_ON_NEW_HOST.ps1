# ---------------------------------------------
# Clone ADELE repository to local path $GitPath
# ---------------------------------------------

$GitPath = "C:\Git\ADELE"

# Copy PowerShell profile template
New-Item -ItemType File -Path $profile.CurrentUserAllHosts
copy $GitPath\profile.ps1 $profile.CurrentUserAllHosts

# Install NuGet
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force

# Register PSRepository
$RepoName = "MyGet"
$SourceLocation  = 'https://www.myget.org/F/tj/api/v2'
$PublishLocation = 'https://www.myget.org/F/tj/api/v2/package/'
 
Register-PSRepository -Name $RepoName `
                      -SourceLocation $SourceLocation `
                      -PublishLocation $PublishLocation `
                      -InstallationPolicy Trusted `
                      -PackageManagementProvider "NuGet"

# Install Modules
Install-Module -Name ADELE,tjLabs,tjTools -Repository $RepoName