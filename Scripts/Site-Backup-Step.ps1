$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

$computerName = $args[0]
$username = $args[1]
$password = $args[2]
$websiteName = $args[3]  # Specify the website name
$localScriptPath = $args[4] # Local path of the script
$remoteScriptPath = "C:\DeploymentScripts"  # Path where you want to copy the script on the remote machine
$skipPaths = $args[5] -split ','  # Get the skipPaths from args and split by comma

$computerNameArgument = $computerName + '/MsDeploy.axd?site=' + $websiteName

# Replace placeholders in Init-Backup.cmd
$cmdFilePath = Join-Path $localScriptPath "Init-Backup.cmd"

(Get-Content $cmdFilePath) -replace '{{SCRIPT_PATH_PLACEHOLDER}}', 'C:\DeploymentScripts\Site-Backup.ps1' |
Set-Content $cmdFilePath

(Get-Content $cmdFilePath) -replace '{{WEBSITE_NAME_PLACEHOLDER}}', $websiteName |
Set-Content $cmdFilePath

(Get-Content $cmdFilePath) -replace '{{SKIP_PATHS_PLACEHOLDER}}', $skipPaths -join ',' |
Set-Content $cmdFilePath


# Copy the PowerShell script to the remote machine    
$msdeployArgumentsCopy = 
    "-verb:sync",
    "-allowUntrusted",
    "-source:contentPath=${localScriptPath}",  # Local script to copy
    ("-dest:" + 
        "contentPath=${remoteScriptPath}," +
        "computerName=${computerNameArgument}," + 
        "username=${username}," +
        "password=${password}," +
        "AuthType='Basic'"
    )

# Call msdeploy to copy the script
& $msdeploy @msdeployArgumentsCopy


# Construct the command to be run on the remote machine
#$commandToRun = "${remoteScriptPath}\Init-Backup.cmd ${remoteScriptPath}\Site-Backup.ps1 $websiteName $escapedSkipPaths"
$commandToRun = "${remoteScriptPath}\Init-Backup.cmd ${remoteScriptPath}\Site-Backup.ps1 $websiteName $escapedSkipPaths"
#$commandToRun = "powershell.exe -ExecutionPolicy Bypass -File ${remoteScriptPath}\Site-Backup.ps1 $websiteName $escapedSkipPaths"
#$commandToRun = "powershell.exe ${remoteScriptPath}\Site-Backup.ps1"

### Adding priveliges to the web management service requires running follwong command on the VPS in an elavated command prompt:
#sc privs wmsvc SeChangeNotifyPrivilege/SeImpersonatePrivilege/SeAssignPrimaryTokenPrivilege/SeIncreaseQuotaPrivilege

$msdeployArgumentsRun = 
    "-verb:sync",
    "-allowUntrusted",
    "-source:runCommand=$commandToRun",  # Pass the command without extra quotes
    ("-dest:auto," +
        "computerName=${computerNameArgument}," + 
        "username=${username}," +
        "password=${password}," +
        "AuthType='Basic'"
    )

# Call msdeploy to run the script
& $msdeploy @msdeployArgumentsRun


