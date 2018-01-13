#region Install Git

Start-Process "https://git-scm.com/"
# ---------------------
# Install git manually
# ---------------------

mkdir C:\Git
cd C:\Git\

git config --global user.name "Thomas Jaekel"
git config --global user.email "Wilhelm.Wien@outlook.de"
#git config --global http.proxy http://192.168.254.5:8080 
#git config --global --unset http.proxy 
git config --list 

#endregion

#region Clone ADELE repo

git clone https://github.com/www42/ADELE.git

cd .\ADELE\
git status

#endregion

#region Create PowerShell profile

$AdelePath = "C:\Git\ADELE"

New-Item -ItemType File -Path $profile.CurrentUserAllHosts
copy $AdelePath\profile.ps1 $profile.CurrentUserAllHosts

#endregion

#region  Install PowerShell modules

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force

$RepoName = "MyGet"
$SourceLocation  = 'https://www.myget.org/F/tj/api/v2'
$PublishLocation = 'https://www.myget.org/F/tj/api/v2/package/'
 
Register-PSRepository -Name $RepoName `
                      -SourceLocation $SourceLocation `
                      -PublishLocation $PublishLocation `
                      -InstallationPolicy Trusted `
                      -PackageManagementProvider "NuGet"

Install-Module -Name ADELE,tjLabs,tjTools -Repository $RepoName

#endregion