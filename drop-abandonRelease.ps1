#Abandoning each release is required to prevent people from redeploying the elevation task without having to enter the password
#Abandoning can only be done after the release is finished, so we must run it in an orphaned process
#Make sure to allow this deployment group task access to the OAuth access token
$abandonreleaselogfile = "C:\azagent\abandonlog.txt"
$abondonreleasescript = "C:\azagent\abandonreleasescript.ps1"
Set-Content -Path $abondonreleasescript -Value '#we must abandon the release to prevent people from redeploying the elevation task'
Add-Content -Path $abondonreleasescript -Value ('$url = "https://vsrm.dev.azure.com/***REDACTED***/_apis/Release/releases/'+ $env:Release_ReleaseId +'?api-version=5.0"')
Add-Content -Path $abondonreleasescript -Value ('$method = "PATCH"')
Add-Content -Path $abondonreleasescript -Value ('$headers = @{ Authorization = “Bearer ' +$env:SYSTEM_ACCESSTOKEN+'” }')
Add-Content -Path $abondonreleasescript -Value ('$body = "{`"status`": `"abandoned`",`"manualEnvironments`": null,`"comment`": `"Abandon the release`"}"')
Add-Content -Path $abondonreleasescript -Value 'Start-Sleep -s 10'
Add-Content -Path $abondonreleasescript -Value ('Invoke-RestMethod $url -Method $method -Body $body -Headers $headers -ContentType "application/json" -Verbose')
Add-Content -Path $abondonreleasescript -Value 'Start-Sleep -s 2'
Add-Content -Path $abondonreleasescript -Value '#delete the script since it contains sensitive information'
Add-Content -Path $abondonreleasescript -Value ('Remove-Item -Path $MyInvocation.MyCommand.Source')

Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList "powershell.exe $abondonreleasescript"

