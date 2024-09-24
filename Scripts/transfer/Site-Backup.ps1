param(
    [Parameter(Mandatory=$true)][string]$websiteName,
    [Parameter(Mandatory=$true)][string[]]$skipPaths # Can contain both files and folders to exclude
)
# EXAMPLE: backup.ps1 -websiteName "YourWebsite" -skipPaths @("wwwroot/media", "umbraco/logs", "appsettings.development.json")

# Function to get the physical path of an IIS website using Get-IISSite
function Get-IISWebsitePath {
    param (
        [string]$websiteName
    )
    Import-Module IISAdministration
    # Get the site object
    $site = Get-IISSite | Where-Object { $_.Name -ieq $websiteName }
    
    if ($site) {
        return $site.Applications["/"].VirtualDirectories["/"].PhysicalPath
    } else {
        Write-Output "Website '$websiteName' not found in IIS"
        throw "Website '$websiteName' not found in IIS"
    }
}

# Import necessary modules
Import-Module WebAdministration
Import-Module IISAdministration

# Resolve website physical path from IIS configuration
$websitePath = Get-IISWebsitePath -websiteName $websiteName
if (-not $websitePath) {
    Write-Error "Failed to resolve website path from IIS"
    exit 1
} else {
    Write-Output $websitePath
}

# Define backup folder with timestamp (create if not exists)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$parentFolder = Split-Path -Path $websitePath -Parent
$backupFolder = Join-Path -Path $parentFolder -ChildPath "backups"
if (-not (Test-Path $backupFolder)) {
    New-Item -Path $backupFolder -ItemType Directory | Out-Null
}

# Define temporary folder for copying files
$tempBackupFolder = Join-Path -Path $backupFolder -ChildPath "temp-backup-$timestamp"
if (-not (Test-Path $tempBackupFolder)) {
    New-Item -Path $tempBackupFolder -ItemType Directory | Out-Null
}

# Prepare exclusion list using full paths
$fullExcludePaths = $skipPaths | ForEach-Object { Join-Path $websitePath $_ }

# Function to check if a path should be excluded
function Should-SkipPath {
    param (
        [string]$itemPath,
        [string[]]$excludePaths
    )

    foreach ($excludePath in $excludePaths) {
        if ($itemPath -like "$excludePath*") {
            return $true
        }
    }
    return $false
}

# Copy files to temporary backup folder, excluding specified paths
Write-Output "Copying website files to temporary folder, skipping: $skipPaths"
Get-ChildItem -Path $websitePath -Recurse -Force | ForEach-Object {
    $destination = $_.FullName.Replace($websitePath, $tempBackupFolder)

    # Check if the current item should be excluded
    if (-not (Should-SkipPath -itemPath $_.FullName -excludePaths $fullExcludePaths)) {
        if ($_.PSIsContainer) {
            if (-not (Test-Path $destination)) {
                New-Item -ItemType Directory -Path $destination | Out-Null
            }
        } else {
            Copy-Item -Path $_.FullName -Destination $destination -Force
        }
    }
}

# Backup SQL Server databases from connection strings in appsettings.json
function Backup-SQLDatabases {
    param (
        [string]$appsettingsPath,
        [string]$backupFolder
    )

    if (-not (Test-Path $appsettingsPath)) {
        Write-Output "appsettings.json not found, skipping database backup."
        return
    }

    # Load appsettings.json and parse connection strings
    $appsettings = Get-Content $appsettingsPath -Raw | ConvertFrom-Json
    $connectionStrings = $appsettings.ConnectionStrings.PSObject.Properties

    if (-not $connectionStrings) {
        Write-Output "No connection strings found in appsettings.json, skipping database backup."
        return
    }

    # Create temp folder for database backups
    $tempDbBackupFolder = Join-Path -Path $backupFolder -ChildPath "tempDbBackups"
    if (-not (Test-Path $tempDbBackupFolder)) {
        New-Item -Path $tempDbBackupFolder -ItemType Directory | Out-Null
    }

    foreach ($connStr in $connectionStrings) {
        # Replace double backslashes with single backslashes in the connection string
        $connectionString = $connStr.Value -replace '\\', '\'

        if ($connectionString.Value -match 'database=([^;]+)') {
            $databaseName = $matches[1]
            $backupFile = Join-Path $tempDbBackupFolder "$databaseName.bak"
            Write-Output "Backing up database: $databaseName"
            sqlcmd -Q "BACKUP DATABASE [$databaseName] TO DISK = N'$backupFile' WITH NOFORMAT, NOINIT, NAME = N'$databaseName-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10"
        } else {
            Write-Output "Connection string '$($connStr.Name)' does not contain a valid database name, skipping."
        }
    }
}

# Function to clean up old backups, keeping only the most recent 3
function Clean-OldBackups {
    param (
        [string]$backupFolder
    )

    # Define a filter for the backup files based on the website name
    $backupFilePattern = "$websiteName-*.zip"

    # Get all backup zip files in the backup folder that match the pattern, sorted by creation time (newest first)
    $backupFiles = Get-ChildItem -Path $backupFolder -Filter $backupFilePattern | Sort-Object LastWriteTime -Descending

    # If there are more than 3 backups, remove the older ones
    if ($backupFiles.Count -gt 3) {
        $filesToRemove = $backupFiles | Select-Object -Skip 3
        foreach ($file in $filesToRemove) {
            Write-Output "Removing old backup: $($file.FullName)"
            Remove-Item -Path $file.FullName -Force
        }
    } else {
        Write-Output "No old backups to remove. Total backups: $($backupFiles.Count)"
    }
}

# Backup databases to a temp folder
$appsettingsPath = Join-Path $websitePath "appsettings.json"
Backup-SQLDatabases -appsettingsPath $appsettingsPath -backupFolder $backupFolder

# Define backup zip file name
$backupFileName = "$($websiteName)-$timestamp.zip"
$backupFilePath = Join-Path $backupFolder $backupFileName

# Prepare for compression
$pathsToCompress = @($tempBackupFolder)

# Check if the database backup folder exists and contains files
$tempDbBackupFolder = Join-Path -Path $backupFolder -ChildPath "tempDbBackups"
$dbBackupExists = Test-Path $tempDbBackupFolder
$dbBackupHasFiles = $false

if ($dbBackupExists) {
    $dbBackupHasFiles = (Get-ChildItem -Path $tempDbBackupFolder -File | Where-Object { $_.Length -gt 0 }).Count -gt 0
}

# Add the database backup folder if it exists and contains files
if ($dbBackupExists -and $dbBackupHasFiles) {
    $pathsToCompress += $tempDbBackupFolder
}

# Compress the temporary backup folder into the backup zip if there's anything to compress
if ($pathsToCompress.Count -gt 0) {
    Write-Output "Compressing to '$backupFilePath'"
    Compress-Archive -Path $pathsToCompress -CompressionLevel Fastest -DestinationPath $backupFilePath
} else {
    Write-Output "No files to compress. Skipping compression."
}


# Cleanup temporary folders after compression
Remove-Item -Path $tempBackupFolder -Recurse -Force
if (Test-Path $tempDbBackupFolder) {
    Remove-Item -Path $tempDbBackupFolder -Recurse -Force
}

Write-Output "Website files and databases backed up successfully to '$backupFilePath'"

# Call the cleanup function after the backup process
Clean-OldBackups -backupFolder $backupFolder