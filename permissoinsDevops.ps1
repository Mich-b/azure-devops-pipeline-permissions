#call as .\permissionsDevops.ps1 -username devopsagent -taskuser "domain\taskuser"

param (
[string]$domain = "localpc",
[string]$username = "devopsagent",
[string]$azagentpath = "C:\azagent",
[string]$wildcardPipelineName = "Pipelines",
[string]$taskuser
)

####setting the domain to local host####
if ($domain -eq "localpc")
{$domain = [System.Net.Dns]::GetHostName()}

####add logon as a batch right####
.\ntrights.exe +r SeBatchLogonRight -u $taskuser

####Create pipeline user#####
write-host "Creating local user"
$Password = Read-Host -AsSecureString "Please enter the password for this user"
New-LocalUser "$username" -Password $Password -FullName "Devops Elevated Agent" -Description "This agent is used during release."

####add logon as a service right 
.\ntrights +r SeServiceLogonRight -u $username

####Preparing the ACL rules#######
$file_read_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule "$domain\$username", 'Read', 'None', 'None', 'Allow'
$file_full_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule "$domain\$username", 'FullControl', 'None', 'None', 'Allow'
$read_access_registry = New-Object System.Security.AccessControl.RegistryAccessRule "$domain\$username","FullControl","Allow"
$folder_read_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule "$domain\$username", 'Read', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
$folder_full_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule "$domain\$username", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'
$lowpriv_folder_full_access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule "NT Authority\LocalService", 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'

#####Give localservice and higher priv account rights to stop start Pipelines service####
#added start stop rights for LS (localservice)
write-host "Setting service restart rights on Pipeline service"
$service = Get-WmiObject -Class Win32_Service | Where-Object {$_.DisplayName -like "*$wildcardPipelineName*" }
sc.exe sdset $service.Name "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;LS)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
#added start stop righst for devopsagent
$sid = Get-WmiObject win32_useraccount | Select name,sid | Where-Object Name -like $username
$sidvalue = $sid.sid
$serviceAcl = "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;LS)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;" + $sidvalue + ")S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
sc.exe sdset $service.Name $serviceAcl

####Generic####
write-host "Creating azagent folder and assigning permissions"
New-Item -ItemType Directory -Force -Path $azagentpath
$permissionsFolder = Get-Acl -Path $azagentpath
#set lowpriv user
$permissionsFolder.AddAccessRule($lowpriv_folder_full_access_rule)
$permissionsFolder.AddAccessRule($folder_full_access_rule)
Set-Acl -Path $azagentpath -AclObject $permissionsFolder

####Environment variables permissions####
write-host "Allowing write access to environment variables"
$permissionsRegistry = Get-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$permissionsRegistry.AddAccessRule($read_access_registry)
Set-Acl -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -AclObject $permissionsRegistry

####IIS permissions####
write-host "Setting permissions on IIS folders"
$permissionsInetsrv = Get-Acl -Path C:\Windows\System32\inetsrv\Config
$permissionsInetsrv.AddAccessRule($folder_full_access_rule)
Set-Acl -Path C:\Windows\System32\inetsrv\Config -AclObject $permissionsInetsrv

$permissionsInetpub = Get-Acl -Path C:\inetpub
$permissionsInetpub.AddAccessRule($folder_full_access_rule)
Set-Acl -Path C:\inetpub -AclObject $permissionsInetpub

####Task scheduler permissions####
write-host "Setting permissions on task scheduler folders"
$permissionsTasksched = Get-Acl -Path C:\Windows\Tasks
$permissionsTasksched.SetAccessRuleProtection($false,$false)
$permissionsTasksched.AddAccessRule($folder_full_access_rule)
Set-Acl -Path C:\Windows\Tasks -AclObject $permissionsTasksched

####IIS keys####
write-host "Setting permissions on IIS keys"
$pathKey1 = Get-ChildItem -Path C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\6de9cb26d2b98c01ec4e9e8b34824aa2* 
$pathKey2 = Get-ChildItem -Path C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\d6d986f09a1ee04e24c949879fdb506c*
$pathKey3 = Get-ChildItem -Path C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\76944fb33636aeddb9590521c2e8815a*
$pathKey4 = Get-ChildItem -Path C:\ProgramData\Microsoft\Crypto\Keys\597367cc37b886d7ee6c493e3befb421*
$pathKey5 = Get-ChildItem -Path C:\ProgramData\Microsoft\Crypto\Keys\f0e91f6485ac2d09485e4ec18135601e*

$permissionsKey1 = Get-Acl -Path $pathKey1
$permissionsKey1.AddAccessRule($file_read_access_rule)
Set-Acl -Path $pathKey1 -AclObject $permissionsKey1

$permissionsKey2 = Get-Acl -Path $pathKey2
$permissionsKey2.AddAccessRule($file_read_access_rule)
Set-Acl -Path $pathKey2 -AclObject $permissionsKey2

$permissionsKey3 = Get-Acl -Path $pathKey3
$permissionsKey3.AddAccessRule($file_read_access_rule)
Set-Acl -Path $pathKey3 -AclObject $permissionsKey3

$permissionsKey4 = Get-Acl -Path $pathKey4
$permissionsKey4.AddAccessRule($file_read_access_rule)
Set-Acl -Path $pathKey4 -AclObject $permissionsKey4

$permissionsKey5 = Get-Acl -Path $pathKey5
$permissionsKey5.AddAccessRule($file_read_access_rule)
Set-Acl -Path $pathKey5 -AclObject $permissionsKey5
