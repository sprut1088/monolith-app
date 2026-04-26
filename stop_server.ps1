<#
.SYNOPSIS
    Stop the Flask monolith server for Harness demo.

.DESCRIPTION
    Gracefully stops the Flask application by reading PID from file and killing process.
    Called by Harness deployment pipeline.

.PARAMETER AppPath
    Path to application directory (default: D:\CICD_Demo\git_repo\monolith-app)

.EXAMPLE
    .\stop_server.ps1 -AppPath "D:\CICD_Demo\git_repo\monolith-app"

.NOTES
    - Reads PID from server.pid file
    - Kills process tree to ensure all child processes are stopped
    - Safe to run even if server is not running
#>

param(
    [string]$AppPath = "D:\CICD_Demo\git_repo\monolith-app"
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
    Write-Warn "Stopping Flask server..."
    
    $pidFile = "$AppPath\server.pid"
    
    # Check if PID file exists
    if (-Not (Test-Path $pidFile)) {
        Write-Warn "No server PID file found at: $pidFile"
        Write-Warn "Server may not be running"
        exit 0
    }
    
    # Read PID from file
    try {
        $pidContent = Get-Content -Path $pidFile -Raw -ErrorAction Stop
        $pid = [int]($pidContent.Trim())
    }
    catch {
        Write-ErrorCustom "Failed to read PID from file: $_"
        exit 1
    }
    
    # Verify PID is numeric and valid
    if ($pid -le 0) {
        Write-ErrorCustom "Invalid PID read from file: $pid"
        exit 1
    }
    
    Write-Info "Stopping process with PID: $pid"
    
    # Check if process exists before killing
    $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
    
    if ($null -eq $process) {
        Write-Warn "Process with PID $pid not found (may have already stopped)"
    }
    else {
        # Kill process tree (stops Python and Flask)
        Get-Process -Id $pid -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Info "Process killed successfully"
    }
    
    # Wait a moment for graceful shutdown
    Start-Sleep -Seconds 2
    
    # Clean up PID file
    try {
        Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
        Write-Info "PID file cleaned up"
    }
    catch {
        Write-Warn "Failed to remove PID file: $_"
    }
    
    # Verify server is no longer responding
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5000/health" `
            -UseBasicParsing -TimeoutSec 1 -ErrorAction SilentlyContinue
        Write-Warn "Server still responding on port 5000 after stop attempt"
    }
    catch {
        Write-Info "Server stopped successfully"
    }
    
    exit 0
}
catch {
    Write-ErrorCustom "Unexpected error: $_"
    exit 1
}