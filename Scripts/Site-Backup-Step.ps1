$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

$computerName = $args[0]
$username = $args[1]
$password = $args[2]
$websiteName = $args[3]  # Specify the website name
$localScriptPath = $args[4] # Local path of the script
$remoteScriptPath = "C:\DeploymentScripts"  # Path where you want to copy the script on the remote machine
$skipPaths = $args[5] -split ','  # Get the skipPaths from args and split by comma

$computerNameArgument = $computerName + '/MsDeploy.axd?site=' + $websiteName

# Replace placeholders in Init-Backup.cmd while preserving whitespace
$cmdFilePath = Join-Path $localScriptPath "Init-Backup.cmd"

# Read the entire file content as a single string
$fileContent = Get-Content $cmdFilePath -Raw

# Perform replacements
$fileContent = $fileContent -replace '{{SCRIPT_PATH_PLACEHOLDER}}', 'C:\DeploymentScripts\Site-Backup.ps1'
$fileContent = $fileContent -replace '{{WEBSITE_NAME_PLACEHOLDER}}', $websiteName

# Format the skipPaths as a string suitable for CMD syntax
$formattedSkipPaths = @()
foreach ($path in $skipPaths) {
    # Escape quotes for CMD
    $formattedSkipPaths += "`"$path`""  
}

# Join the formatted paths into a single string
$skipPathsString = $formattedSkipPaths -join ','

# Replace the skip paths placeholder with the formatted string
$fileContent = $fileContent -replace '{{SKIP_PATHS_PLACEHOLDER}}', $skipPathsString

# Write the modified content back to the file
Set-Content $cmdFilePath -Value $fileContent


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
$commandToRun = "${remoteScriptPath}\Init-Backup.cmd"

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


