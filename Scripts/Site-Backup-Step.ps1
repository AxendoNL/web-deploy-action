$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

$computerName = $args[0]
$username = $args[1]
$password = $args[2]
$websiteName = $args[3]  # Specify the website name
$localScriptPath = $args[4] # Local path of the script
$remoteScriptPath = "C:\DeploymentScripts\Site-Backup.ps1"  # Path where you want to copy the script on the remote machine
$skipPaths = $args[5] -split ','  # Get the skipPaths from args and split by comma

$computerNameArgument = $computerName + '/MsDeploy.axd'

# Copy the PowerShell script to the remote machine
$msdeployArgumentsCopy = 
    "-verb:sync",
    "-allowUntrusted",
    "-source:content='$localScriptPath'",  # Local script to copy
    "-dest:content='$remoteScriptPath'," +
    "computerName=${computerNameArgument}," +
    "username=${username}," +
    "password=${password}," +
    "AuthType='Basic'"

# Call msdeploy to copy the script
& $msdeploy @msdeployArgumentsCopy

# Execute the PowerShell script on the target machine
Invoke-Command -ComputerName $computerName -ScriptBlock {
    param($scriptPath, $websiteName, $skipPaths)
    & $scriptPath -websiteName $websiteName -skipPaths $skipPaths
} -ArgumentList $remoteScriptPath, $websiteName, $skipPaths
