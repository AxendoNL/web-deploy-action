$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

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
    ),
    "-postSync:runCommand='powershell.exe -ExecutionPolicy Bypass -File ${remoteScriptPath} -websiteName ${websiteName} -skipPaths wwwroot/media'"

# Call msdeploy to copy the script
& $msdeploy @msdeployArgumentsCopy

# Define session options to skip certificate checks
$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

# Create credentials for remote connection
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object PSCredential($username, $securePassword)

# Execute the PowerShell script on the target machine using WinRM
$remoteCommand = "powershell.exe -ExecutionPolicy Bypass -File $remoteScriptPath -websiteName $websiteName -skipPaths $($skipPaths -join ',')"

Invoke-Command -ComputerName $computerName -Credential $credential -ScriptBlock {
    param($command)
    Invoke-Expression $command
} -ArgumentList $remoteCommand

