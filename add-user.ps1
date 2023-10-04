param (
    [string]$username,
    [string[]]$groupsFromArgs,
    [switch]$help
)

# Function to display help message
function Show-Help {
    Write-Output "Usage: PowerShellScript.ps1 -username <username> [-groupsFromArgs <group1>, <group2>, ...]"
}

# Show help if -help parameter is provided
if ($help) {
    Show-Help
    return
}

# Show help if username is not provided
if (-not $username) {
    Show-Help
    return
}

# Function to create folders
function CreateFolder {
    param (
        [string]$username,
        [string]$basePath,
        [string]$folder = "",
        [bool]$isAclInheritance = $true,
        [string[]]$directoriesAccess = @()
    )

    try {
        if (-not $folder) {
            $folderPath = $basePath
        }
        else {
            $folderPath = Join-Path -Path $basePath -ChildPath $folder
        }

        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath -Force

            # Set owner and permissions for folder
            $acl = Get-Acl -Path $folderPath
            $acl.SetOwner([System.Security.Principal.NTAccount]$username)

            if ($isAclInheritance) {
                $acl.SetAccessRuleProtection($false, $true)
            }
            else {
                $acl.SetAccessRuleProtection($true, $false)
                $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) }

                # Add permissions for Administrators and System
                $administratorsSID = New-Object System.Security.Principal.SecurityIdentifier ([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null)
                $systemSID = New-Object System.Security.Principal.SecurityIdentifier ([System.Security.Principal.WellKnownSidType]::LocalSystemSid, $null)

                $administratorsRule = New-Object System.Security.AccessControl.FileSystemAccessRule($administratorsSID, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
                $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule($systemSID, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')

                $userIdentity = New-Object System.Security.Principal.NTAccount($username)
                $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule($userIdentity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')

                $acl.AddAccessRule($administratorsRule)
                $acl.AddAccessRule($systemRule)
                $acl.AddAccessRule($userRule)


                # Add full access for groups specified in directories-access
                foreach ($group in $directoriesAccess) {
                    $groupSID = New-Object System.Security.Principal.NTAccount($group)
                    $groupRule = New-Object System.Security.AccessControl.FileSystemAccessRule($groupSID, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
                    $acl.AddAccessRule($groupRule)
                }
            }

            $acl | Set-Acl -Path $folderPath
        }
        else {
            Write-Output "Folder already exists: $folderPath"
        }
    }
    catch {
        Write-Output "Error creating folder: $_"
    }
}

# Read config from JSON file
$config = Get-Content -Path "configs/add-user.json" | ConvertFrom-Json

# Merge groups from config and arguments
$groups = $config.groups + $groupsFromArgs

$existingUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue

if (-not $existingUser) {
    # Import the module with the -SkipEditionCheck flag
    Import-Module -Name Microsoft.Powershell.LocalAccounts -UseWindowsPowerShell -ErrorAction Stop
    New-LocalUser -Name $username
}

# Add the user to each group
foreach ($group in $groups) {
    try {
        Add-LocalGroupMember -Group $group -Member $username
    }
    catch {
        $errorMessage = "Error adding $username to $group"
        Write-Output $errorMessage
    }
}

# Create directories
foreach ($entry in $config.directories) {
    $dirPath = $entry.PSObject.Properties.Name
    $subfolders = $entry.$dirPath

    # Replace {{ username }} with the actual username
    $dirPath = $dirPath -replace '<<username>>', $username

    try {
        # Create the directory
        Write-Output "Creating $dirPath"
        CreateFolder -username $username -basePath $dirPath -isAclInheritance $false -directoriesAccess $config.'directories-access'

        # Create subfolders
        foreach ($subfolder in $subfolders) {
            Write-Output "Creating $subfolder in $dirPath"
            CreateFolder -username $username -basePath $dirPath -folder $subfolder -isAclInheritance $true
        }
    }
    catch {
        $errorMessage = "Error creating $dirPath"
        Write-Output $errorMessage
    }
}

# Output a message indicating completion
Write-Output "Setup completed successfully."
