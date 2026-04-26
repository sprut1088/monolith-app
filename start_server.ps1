<#
.SYNOPSIS
    Start the Flask monolith server for Harness demo.

.DESCRIPTION
    Starts the Flask application in background, logs PID, and verifies server is healthy.
    Called by Harness deployment pipeline.

.PARAMETER AppPath
    Path to application directory (default: C:\monolith-app)

.EXAMPLE
    .\start_server.ps1 -AppPath "C:\monolith-app"

.NOTES
    - Requires Python to be installed and in PATH
    - Server runs on http://localhost:5000
    - PID saved to server.pid for later stopping
#>

param(
    [string]$AppPath = "C:\monolith-app"
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

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $Message" -ForegroundColor Red
}

try {
    Write-Warn "Starting Flask server..."
    
    # Verify app directory exists
    if (-Not (Test-Path $AppPath)) {
        Write-Error-Custom "Application directory not found: $AppPath"
        exit 1
    }
    
    # Change to app directory
    Set-Location $AppPath
    
    # Check if Python is available
    $pythonCheck = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Python not found. Please install Python 3.8+"
        exit 1
    }
    
    Write-Info "Python version: $pythonCheck"
    
    # Start Flask in background
    Write-Info "Launching Flask application..."
    $process = Start-Process -FilePath "python" -ArgumentList "app.py" -PassThru -NoNewWindow
    $pid = $process.Id
    
    # Save PID for later stopping
    $pid | Out-File -FilePath "$AppPath\server.pid" -Encoding UTF8 -Force
    
    Write-Info "Server process started (PID: $pid)"
    Write-Warn "Waiting for server to boot..."
    
    # Wait for server to initialize
    Start-Sleep -Seconds 3
    
    # Test health endpoint with retries
    $maxAttempts = 5
    $attempt = 0
    $serverHealthy = $false
    
    Write-Info "Checking server health..."
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5000/health" `
                -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            
            if ($response.StatusCode -eq 200) {
                Write-Info "✓ Server is healthy and responding"
                $serverHealthy = $true
                break
            }
        }
        catch {
            $attempt++
            if ($attempt -lt $maxAttempts) {
                Write-Warn "Waiting for server... (attempt $attempt/$maxAttempts)"
                Start-Sleep -Seconds 2
            }
        }
    }
    
    if ($serverHealthy) {
        Write-Info "✓ Deployment verified - Server is running"
        Write-Info "Health check URL: http://localhost:5000/health"
        Write-Info "Info URL: http://localhost:5000/info"
        exit 0
    }
    else {
        Write-Warn "Server started but health check failed after $maxAttempts attempts"
        Write-Warn "Server may still be initializing. Manual verification recommended."
        exit 0
    }
}
catch {
    Write-Error-Custom "Failed to start server: $_"
    exit 1
}
