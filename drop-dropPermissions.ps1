$password = "$(pipelineLowPrivUser_pass)" 
$username = "$env:pipelineLowPrivUser_name" 

$service = Get-WmiObject -Class Win32_Service | Where-Object {$_.DisplayName -like "*$env:wildcardPipelineName*" }
$serviceNameString = '"'+$service.Name.toString()+'"'

sc.exe config $serviceNameString obj= "$username" password= "$password"

#Restarting is required to take the new credentials
#However, restarting in-process would terminate the pipeline agent and cancel the release
#so we cancel out of process by writing a bat file and starting that asynchronously
$restartlogfile = "C:\azagent\restartlog.txt"
$restartagentscript = "C:\azagent\restartagent.ps1"
Set-Content -Path $restartagentscript -Value '#restart service and fall back to local service account if not successful'
Add-Content -Path $restartagentscript -Value ('Start-Transcript -path '+$restartlogfile)
Add-Content -Path $restartagentscript -Value 'Start-Sleep -s 5'
Add-Content -Path $restartagentscript -Value ('Stop-Service -name '+$serviceNameString)
Add-Content -Path $restartagentscript -Value 'Start-Sleep -s 5'
Add-Content -Path $restartagentscript -Value ('Start-Service -name ' + $serviceNameString)
Add-Content -Path $restartagentscript -Value 'Start-Sleep -s 10'
Add-Content -Path $restartagentscript -Value ('$agentservice = Get-Service -name '+$serviceNameString)
Add-Content -Path $restartagentscript -Value 'if ($agentservice.Status -ne "Running")'
Add-Content -Path $restartagentscript -Value '{'
Add-Content -Path $restartagentscript -Value 'Write-Host "Service not started, reverting back to local service"'
Add-Content -Path $restartagentscript -Value ('sc.exe config '+$serviceNameString+' obj= "nt authority\local service"')
Add-Content -Path $restartagentscript -Value 'Start-Sleep -s 5'
Add-Content -Path $restartagentscript -Value ('Restart-Service -name '+$serviceNameString) 
Add-Content -Path $restartagentscript -Value 'Start-Sleep -s 5'
Add-Content -Path $restartagentscript -Value '}'
Add-Content -Path $restartagentscript -Value 'else {'
Add-Content -Path $restartagentscript -Value 'Write-Host "Service elevated successfully"'
Add-Content -Path $restartagentscript -Value '}'
Add-Content -Path $restartagentscript -Value 'Stop-Transcript'

Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "powershell.exe $restartagentscript"
