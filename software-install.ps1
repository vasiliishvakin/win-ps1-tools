param (
    [string]$config = "configs/software-install.json",
    [string]$configUrl
)

Write-Host ("=" * 50) -ForegroundColor White
Write-Host ""

# Help message
$helpMessage = @"
Usage: .\software-install.ps1 [-config <path>] [-configUrl <url>] [-help]

Options:
  -config <path>    Path to the configuration file. Default is "configs/software-install.json".
  -configUrl <url>  URL to the configuration file.
  -help                    Show this help message.
"@

# Check for -help flag
if ($args -contains "-help") {
    Write-Output $helpMessage
    exit
}

# Check if either -config or -configUrl is provided
if (-not ($config -or $configUrl)) {
    Write-Host "Error: Please provide either a configuration file path or a configuration URL."
    Write-Output $helpMessage
    exit
}

# Check if the provided configuration file exists
if ($config) {
    if (-Not (Test-Path $config -PathType Leaf)) {
        Write-Host "Error: Configuration file not found: $config"
        Write-Output $helpMessage
        exit
    }
}

# Check if the provided configuration file exists, if not, try to retrieve from URL
if (-Not (Test-Path $config -PathType Leaf) -and $configUrl) {
    try {
        $configData = Invoke-WebRequest -Uri $configUrl | ConvertFrom-Json
    }
    catch {
        Write-Host "Error retrieving JSON from URL $configUrl. Please ensure the URL is valid."  -ForegroundColor Red
        exit
    }
}
else {
    try {
        $configData = Get-Content -Raw -Path $config | ConvertFrom-Json
    }
    catch {
        Write-Host "Error parsing JSON in $config. Please ensure the JSON is valid."  -ForegroundColor Red
        exit
    }
}

# Create an array to keep track of manual installations
$manualInstallations = @()

# Loop through the URLs and install the software
foreach ($urlConfig in $configData.urls) {
    Write-Host ("." * 30) -ForegroundColor Gray

    $base = $urlConfig.base
    $path = $urlConfig.path
    $filename = $urlConfig.filename
    $destination = ""

    # Construct the URL based on the provided information
    $url = if ($path) { "$base/$path" } else { $base }

    if ($filename) {
        # If filename is provided, use it for the destination
        $destination = Join-Path $configData.destination $filename
    }
    else {
        # If neither filename is provided, use the base URL and extract filename from URL
        $filename = [System.IO.Path]::GetFileName($url)
        $destination = Join-Path $configData.destination $filename
    }

    try {
        $useBrowser = [bool]$urlConfig.browser

        if ($useBrowser) {
            if ($urlConfig.filename) {
                $destination = Join-Path $configData.destination $filename
                if (Test-Path $destination) {
                    Write-Host "File already exists at $destination. Skipping download." -ForegroundColor Yellow

                    # Run the installer
                    Write-Host "Installing" -NoNewline -ForegroundColor Green
                    Write-Host " $destination ..."

                    Start-Process -FilePath $destination -Wait
                }
            }
            else {
                # Download the installer
                Write-Host "Open browser" -NoNewline -ForegroundColor Green
                Write-Host " $url ..."

                Start-Process $url
            }

            $manualInstallations += @{
                Filename = $urlConfig.filename
                URL      = $url
            }
        }
        else {
            if (Test-Path $destination) {
                Write-Host "File already exists at $destination. Skipping download." -ForegroundColor Yellow
            }
            else {
                # Download the installer
                Write-Host "Downloading" -NoNewline -ForegroundColor Green
                Write-Host " $url ..."

                Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
            }

            # Run the installer
            Write-Host "Installing" -NoNewline -ForegroundColor Green
            Write-Host " $destination ..."

            Start-Process -FilePath $destination -Wait
        }
    }
    catch {
        $errorMessage = "Error installing $url $_"
        Write-Output $errorMessage
    }
    finally {
        Write-Host ("." * 30) -ForegroundColor Gray
    }
}

# Display manual installations
$manualInstallationsCount = $manualInstallations.Count

if ($manualInstallationsCount -gt 0) {
    Write-Host ("-" * 50) -ForegroundColor White

    Write-Host "You must install $manualInstallationsCount software manually:`n"

    # List manual installations
    foreach ($install in $manualInstallations) {
        if ($install.Filename) {
            Write-Host "Filename: $($install.Filename)"
            Write-Host "URL: $($install.URL)`n"
        }
        else {
            Write-Host "URL: $($install.URL)`n"
        }
    }

    # Open in file explorer
    Start-Process explorer.exe $configData.destination
}

Write-Host "Done." -ForegroundColor Green
Write-Host ""
Write-Host ("=" * 50) -ForegroundColor White
