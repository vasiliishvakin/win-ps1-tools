# Parse arguments
param (
    [string]$username,
    [string]$configPath = "configs/set-folders.json",
    [switch]$help
)

# Help message
$helpMessage = @"
Usage: .\set-special-folders.ps1 -username <username> [-configPath <path>] [-help]

Options:
  -username <username>   The target username for setting special folders.
  -configPath <path>     Path to the configuration file. Default is "configs/set-folders.json".
  -help                  Show this help message.
"@


# Display help message if -help flag is used
if ($help) {
    Write-Output $helpMessage
    exit
}

function SetSpecialFoldersForUser {
    param (
        [string]$username,
        [string]$basePath,
        [string[]]$specialFolders
    )

    # Get the SID of the target user
    $user = New-Object System.Security.Principal.NTAccount($username)
    $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]).Value

    foreach ($folderInfo in $specialFolders) {
        $folderPath = Join-Path -Path $basePath -ChildPath $folderInfo

        # Check if folder exists
        if (-Not (Test-Path $folderPath -PathType Container)) {
            Write-Host "Error: Folder $folderPath does not exist or you do not have permission to access it." -ForegroundColor Red
            continue
        }

        # Update the registry to set the special folder location for the specific user
        $regKeyPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        Set-ItemProperty -Path $regKeyPath -Name $folderInfo -Value $folderPath
    }
}

# Check if config file exists
if (-Not (Test-Path $configPath -PathType Leaf)) {
    Write-Host "Error: Configuration file not found: $configPath" -ForegroundColor Red
    exit
}

# Read config from JSON file
$config = Get-Content -Path $configPath | ConvertFrom-Json

# Check if username is provided
if (-not $username) {
    Write-Host "Error: Please provide a username." -ForegroundColor Red
    Write-Output $helpMessage
    exit
}

# Check if username exists
try {
    $user = New-Object System.Security.Principal.NTAccount($username)
    $sid = $user.Translate([System.Security.Principal.SecurityIdentifier]).Value
}
catch {
    Write-Host "Error: Username '$username' is not a valid user." -ForegroundColor Red
    exit
}

# Replace placeholder with username in config
$config.winfolders.path = $config.winfolders.path -replace '<< username >>', $username

# Set Windows folders location
$basePath = $config.winfolders.path
$specialFolders = $config.winfolders.folders

SetSpecialFoldersForUser -username $username -basePath $basePath -specialFolders $specialFolders
