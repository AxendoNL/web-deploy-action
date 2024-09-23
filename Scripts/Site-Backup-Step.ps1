﻿$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

$computerName = $args[0]
$username = $args[1]
$password = $args[2]
$websiteName = $args[3]  # Specify the website name
$localScriptPath = $args[4] # Local path of the script
$remoteScriptPath = "C:\DeploymentScripts\Site-Backup.ps1"  # Path where you want to copy the script on the remote machine
$skipPaths = $args[5] -split ','  # Get the skipPaths from args and split by comma

$computerNameArgument = $computerName + '/MsDeploy.axd?site=' + $websiteName

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
    ) +
    "-postSync:runcommand=powershell.exe -ExecutionPolicy Bypass -File ${remoteScriptPath} -websiteName ${websiteName} -skipPaths '${escapedSkipPaths}'"

# Call msdeploy to copy the script
& $msdeploy @msdeployArgumentsCopy

