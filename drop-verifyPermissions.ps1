# get pipeline user
whoami
#we check if the pipeline service runs as our elevated user)
$pipelineUser = whoami
$pos= $pipelineUser.IndexOf("\")
$pipelineUserName = $pipelineUser.Substring($pos+1)

#get elevated user
$elevatedUser = $env:pipelineElevatedUser_name
$posel= $elevatedUser.IndexOf("\")
$elevatedUserName= $elevatedUser.Substring($posel+1)

If ($pipelineUserName -eq $elevatedUserName ) {write-error "user is still elevated"} else {write-host "user has is not elevated anymore"}
