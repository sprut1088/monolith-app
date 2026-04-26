<#
.SYNOPSIS
    Deploy artifact from Jenkins to local application directory.

.DESCRIPTION
    Extracts ZIP artifact and updates version file to mark deployment.
    Called by Harness deployment pipeline.

.PARAMETER ArtifactPath
    Full path to ZIP artifact from Jenkins (required)

.PARAMETER DeployPath
    Where to deploy the application (default: D:\CICD_Demo\git_repo\monolith-app)

.PARAMETER NewVersion
    Version string to write to version.txt (default: unknown)

.EXAMPLE
    .\deploy_artifact.ps1 -ArtifactPath "D:\CICD_Demo\artifacts\monolith-app.zip" `
        -DeployPath "D:\CICD_Demo\git_repo\monolith-app" -NewVersion "v1.1.0-deployed"

.NOTES
    - Extracts artifact to deployment directory
    - Updates version.txt with new version number
    - Preserves server.pid file if it exists
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ArtifactPath,
    
    [string]$DeployPath = "D:\CICD_Demo\git_repo\monolith-app",
    
    [string]$NewVersion = "unknown"
)

# Color output functions
function Write-Info {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Yellow
}

function Write-ErrorCustom {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $Message" -ForegroundColor Red
}

try {
    Write-Warn "Deploying artifact..."
    Write-Info "Artifact path: $ArtifactPath"
    Write-Info "Deploy path: $DeployPath"
    Write-Info "New version: $NewVersion"
    
    # Validate artifact exists
    if (-Not (Test-Path $ArtifactPath)) {
        Write-ErrorCustom "Artifact file not found: $ArtifactPath"
        exit 1
    }
    
    # Validate artifact is a ZIP file
    if (-Not ($ArtifactPath -like "*.zip")) {
        Write-Warn "Artifact does not have .zip extension, proceeding anyway..."
    }
    
    # Check if deployment path exists, create if needed
    if (-Not (Test-Path $DeployPath)) {
        Write-Info "Creating deployment directory: $DeployPath"
        New-Item -ItemType Directory -Path $DeployPath -Force | Out-Null
    }
    
    # Preserve critical files (PID, version if needed)
    $pidFile = "$DeployPath\server.pid"
    $pidBackup = $null
    
    if (Test-Path $pidFile) {
        $pidBackup = Get-Content -Path $pidFile -Raw
        Write-Info "Preserving server.pid"
    }
    
    # Extract artifact
    Write-Info "Extracting artifact..."
    try {
        Expand-Archive -Path $ArtifactPath -DestinationPath $DeployPath -Force
        Write-Info "Artifact extracted successfully"
    }
    catch {
        Write-ErrorCustom "Failed to extract artifact: $_"
        exit 1
    }
    
    # Restore PID file if it existed
    if ($null -ne $pidBackup) {
        $pidBackup | Out-File -Path $pidFile -Encoding UTF8 -Force
        Write-Info "Restored server.pid"
    }
    
    # Update version file
    try {
        $versionFile = "$DeployPath\version.txt"
        Set-Content -Path $versionFile -Value $NewVersion -Encoding UTF8 -Force
        Write-Info "Version file updated: $NewVersion"
    }
    catch {
        Write-Warn "Failed to update version file: $_"
    }
    
    Write-Info "Deployment completed successfully"
    Write-Info "Ready for server restart"
    
    exit 0
}
catch {
    Write-ErrorCustom "Unexpected error during deployment: $_"
    exit 1
}