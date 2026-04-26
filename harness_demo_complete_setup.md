# Harness Demo: Complete Windows Setup Guide
**Time to Demo-Ready: 1.5-2 hours**

---

## Architecture Overview

```
Your Laptop (Windows)
├── GitHub Repo (code + Jenkinsfile)
├── Jenkins (localhost:8080) - triggered on GitHub push
│   └── Builds app, zips artifact → C:\artifacts\
├── Flask Monolith App (Python)
└── Harness (cloud, free tier)
    └── Pipeline: Trigger Jenkins → Deploy → Verify
    └── Delegate (agent) runs on your laptop
```

**Flow:**
```
GitHub push → Jenkins webhook → Jenkins builds & publishes artifact
→ Harness pipeline auto-starts → Stop old server → Deploy new
→ Start new server → Health check passes ✓
```

---

## Prerequisites (10 min)

- [ ] Jenkins installed on Windows (in progress - you're doing this now)
- [ ] Python 3.8+ installed (download from python.org)
- [ ] Git installed (for GitHub integration)
- [ ] GitHub account with a repo (create one if needed)
- [ ] Harness account created (you've done this)
- [ ] VS Code or PyCharm open (for editing files)

---

## Part 1: Flask Monolith App (10 min)

### 1.1 Create Project Directory

On your Windows laptop:
```powershell
# PowerShell
mkdir C:\monolith-app
cd C:\monolith-app
```

### 1.2 Create Flask App

File: `C:\monolith-app\app.py`

```python
"""
Simple Flask monolith for Harness deployment demo.
Endpoints show version to prove new code was deployed.
"""
import os
import json
from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)

# Version file - written during deployment
VERSION_FILE = "C:\\monolith-app\\version.txt"

def get_version():
    """Read current deployed version from file."""
    try:
        with open(VERSION_FILE, 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return "v1.0.0-initial"

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint for deployment verification."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': get_version()
    }), 200

@app.route('/info', methods=['GET'])
def info():
    """App info endpoint - shows what version is deployed."""
    return jsonify({
        'app': 'MonolithDemo',
        'build': get_version(),
        'deployed_at': datetime.now().isoformat(),
        'environment': 'development'
    }), 200

@app.route('/api/data', methods=['GET'])
def data():
    """Sample API endpoint returning mock data."""
    return jsonify({
        'data': [
            {'id': 1, 'name': 'Record 1'},
            {'id': 2, 'name': 'Record 2'},
            {'id': 3, 'name': 'Record 3'}
        ],
        'version': get_version()
    }), 200

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'endpoint not found'}), 404

if __name__ == '__main__':
    # Initialize version file on first run
    if not os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, 'w') as f:
            f.write("v1.0.0-initial")
    
    print(f"[INFO] Starting Flask app - Current version: {get_version()}")
    print(f"[INFO] Server running at http://localhost:5000")
    print(f"[INFO] Health check: http://localhost:5000/health")
    print(f"[INFO] Info: http://localhost:5000/info")
    
    app.run(host='0.0.0.0', port=5000, debug=False)
```

### 1.3 Create Requirements File

File: `C:\monolith-app\requirements.txt`

```
Flask==2.3.2
Werkzeug==2.3.6
```

### 1.4 Test App Locally

```powershell
cd C:\monolith-app
pip install -r requirements.txt
python app.py
```

Then in browser: `http://localhost:5000/health`

Expected output:
```json
{
  "status": "healthy",
  "timestamp": "2026-04-26T10:30:45.123456",
  "version": "v1.0.0-initial"
}
```

✓ If you see this, Flask is working. **Stop the server** (Ctrl+C).

---

## Part 2: PowerShell Deployment Scripts (5 min)

### 2.1 Server Control Scripts

**File: `C:\monolith-app\start_server.ps1`**

```powershell
<#
.DESCRIPTION
    Start the Flask monolith server and log the PID for later stopping.
.NOTES
    Called by Harness deployment pipeline.
#>

param(
    [string]$AppPath = "C:\monolith-app"
)

try {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Starting Flask server..." -ForegroundColor Green
    
    # Change to app directory
    Set-Location $AppPath
    
    # Start Flask in background and capture PID
    $process = Start-Process -FilePath "python" -ArgumentList "app.py" -PassThru -WindowStyle Minimized
    $pid = $process.Id
    
    # Save PID to file for stop script
    $pid | Out-File -FilePath "$AppPath\server.pid" -Encoding UTF8
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Server started with PID: $pid" -ForegroundColor Green
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Waiting for server to boot..." -ForegroundColor Yellow
    
    # Wait for server to be ready
    Start-Sleep -Seconds 3
    
    # Test health check
    $maxAttempts = 5
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Server is healthy and responding" -ForegroundColor Green
                exit 0
            }
        }
        catch {
            $attempt++
            if ($attempt -lt $maxAttempts) {
                Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Waiting for server... (attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            }
        }
    }
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Server started but health check failed. Manual verification needed." -ForegroundColor Yellow
    exit 0
}
catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: Failed to start server: $_" -ForegroundColor Red
    exit 1
}
```

**File: `C:\monolith-app\stop_server.ps1`**

```powershell
<#
.DESCRIPTION
    Stop the Flask monolith server gracefully.
.NOTES
    Called by Harness deployment pipeline.
#>

param(
    [string]$AppPath = "C:\monolith-app"
)

try {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Stopping Flask server..." -ForegroundColor Yellow
    
    $pidFile = "$AppPath\server.pid"
    
    # Check if PID file exists
    if (-Not (Test-Path $pidFile)) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] No server PID file found. Server may not be running." -ForegroundColor Yellow
        exit 0
    }
    
    # Read PID and stop process
    $pid = Get-Content -Path $pidFile -Raw
    $pid = [int]($pid.Trim())
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Killing process PID: $pid" -ForegroundColor Yellow
    
    # Kill process tree (ensures child processes are killed)
    Get-Process -Id $pid -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Wait a bit for graceful shutdown
    Start-Sleep -Seconds 2
    
    # Clean up PID file
    Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Server stopped" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: Failed to stop server: $_" -ForegroundColor Red
    exit 1
}
```

**File: `C:\monolith-app\deploy_artifact.ps1`**

```powershell
<#
.DESCRIPTION
    Deploy artifact from Jenkins to local application directory.
    Extracts artifact and updates version file.
.NOTES
    Called by Harness deployment pipeline.
#>

param(
    [string]$ArtifactPath,      # Path to Jenkins artifact (ZIP file)
    [string]$DeployPath = "C:\monolith-app",  # Where to deploy
    [string]$NewVersion = "unknown"  # Version to write to version.txt
)

try {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Deploying artifact from: $ArtifactPath" -ForegroundColor Cyan
    
    # Validate artifact exists
    if (-Not (Test-Path $ArtifactPath)) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: Artifact file not found: $ArtifactPath" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Extracting artifact..." -ForegroundColor Cyan
    
    # Remove old app files (keep only essential configs if needed)
    $filesToRemove = @("*.py", "*.txt", "*.md") # Add patterns for files to replace
    
    foreach ($pattern in $filesToRemove) {
        Get-ChildItem -Path $DeployPath -Filter $pattern -File | Where-Object { $_.Name -ne "server.pid" } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    
    # Extract artifact to deploy path
    Expand-Archive -Path $ArtifactPath -DestinationPath $DeployPath -Force
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Artifact extracted" -ForegroundColor Green
    
    # Update version file
    $versionFile = "$DeployPath\version.txt"
    Set-Content -Path $versionFile -Value $NewVersion -Encoding UTF8
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Version file updated: $NewVersion" -ForegroundColor Green
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Deployment complete" -ForegroundColor Green
    
    exit 0
}
catch {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: Deployment failed: $_" -ForegroundColor Red
    exit 1
}
```

### 2.2 Test Scripts Locally

```powershell
# In PowerShell (as Admin)
cd C:\monolith-app

# Start server
.\start_server.ps1
# Should see: "✓ Server is healthy and responding"

# In another PowerShell window, test endpoints
Invoke-WebRequest -Uri http://localhost:5000/health -UseBasicParsing

# Stop server
.\stop_server.ps1
# Should see: "✓ Server stopped"
```

---

## Part 3: Jenkins Setup (20 min)

### 3.1 Jenkins Initial Setup

1. **Jenkins should be running** (you're installing now)
2. Visit `http://localhost:8080`
3. Unlock Jenkins with initial password (shown in console/log)
4. Install suggested plugins
5. Create first admin user

### 3.2 Install Required Jenkins Plugins

After Jenkins is running:

1. Go to **Manage Jenkins** → **Plugin Manager**
2. Search for and install:
   - `GitHub Integration Plugin`
   - `Pipeline` (might be pre-installed)
   - `Git plugin`

3. Click **Install without restart** or restart Jenkins

### 3.3 Create GitHub Credentials in Jenkins

1. **Manage Jenkins** → **Manage Credentials** → **System** → **Global credentials**
2. Click **Add Credentials**
3. Select **Kind: Username with password**
   - Username: (your GitHub username)
   - Password: (your GitHub personal access token - create at github.com/settings/tokens)
   - ID: `github-credentials`
4. Click **Create**

### 3.4 Create Jenkins Job for Building Artifact

**Job Name:** `MonolithBuild`

1. **New Item** → **Freestyle job** → Name: `MonolithBuild`

2. **Source Code Management** → **Git**
   - Repository URL: `https://github.com/YOUR-USERNAME/YOUR-REPO.git`
   - Credentials: `github-credentials`
   - Branch: `*/main` (or `*/master`)

3. **Build Triggers** → Check: **GitHub hook trigger for GITScm polling**

4. **Build Steps** → **Add build step** → **Windows Batch Command**
   
   Paste this:
   ```batch
   @echo off
   REM Build and package the monolith app
   echo [INFO] Creating artifact...
   cd %WORKSPACE%
   
   REM Create artifacts directory if it doesn't exist
   if not exist "C:\artifacts" mkdir C:\artifacts
   
   REM Remove old artifact
   if exist "C:\artifacts\monolith-app.zip" del "C:\artifacts\monolith-app.zip"
   
   REM Create ZIP of application
   powershell -Command "Compress-Archive -Path '*' -DestinationPath 'C:\artifacts\monolith-app.zip' -Force"
   
   if exist "C:\artifacts\monolith-app.zip" (
       echo [SUCCESS] Artifact published to C:\artifacts\monolith-app.zip
       exit /b 0
   ) else (
       echo [ERROR] Failed to create artifact
       exit /b 1
   )
   ```

5. **Post-build Actions** → **Archive the artifacts**
   - Files to archive: `**/*.zip`
   - Destination: `artifacts`

6. Click **Save**

### 3.5 Test Jenkins Build Manually

1. Go to **MonolithBuild** job
2. Click **Build Now**
3. Check **Console Output** — should see `[SUCCESS] Artifact published...`
4. Verify artifact exists: `C:\artifacts\monolith-app.zip`

✓ If successful, Jenkins is ready.

---

## Part 4: GitHub Webhook Setup (10 min)

### 4.1 Create GitHub Repository

If you don't have one:
1. Go to `github.com/new`
2. Create repo `monolith-app` (public or private)
3. Clone it locally:
   ```powershell
   git clone https://github.com/YOUR-USERNAME/monolith-app.git
   cd monolith-app
   ```

### 4.2 Push Flask App to GitHub

```powershell
# Copy files to your git repo
copy C:\monolith-app\app.py .
copy C:\monolith-app\requirements.txt .
copy C:\monolith-app\*.ps1 .

# Add to git
git add .
git commit -m "Initial monolith app"
git push origin main
```

### 4.3 Add Webhook to GitHub Repo

1. Go to your GitHub repo → **Settings** → **Webhooks**
2. Click **Add webhook**
3. Fill in:
   - **Payload URL:** `http://YOUR-LOCAL-IP:8080/github-webhook/`
     (Find your IP: `ipconfig` in PowerShell, use something like `192.168.x.x`)
   - **Content type:** `application/json`
   - **Events:** Just the push event
   - **Active:** ✓ Checked

4. Click **Add webhook**

**Note:** GitHub won't be able to reach `localhost`, so use your actual machine IP or use **ngrok** for testing (optional).

---

## Part 5: Harness Pipeline Setup (30-45 min)

### 5.1 Install Harness Delegate

The Delegate is an agent that runs on your laptop and lets Harness talk to Jenkins.

1. In Harness UI → **Project Settings** → **Delegates**
2. Click **New Delegate**
3. Select **Kubernetes** → Actually, scroll down to **Docker** or **Windows**
4. For Windows, download and run the installer

**Simplified: Use Docker Delegate (if you have Docker installed)**

```powershell
docker run --cpus=1 --memory=2g -d -e DELEGATE_NAME=local-delegate -e NEXT_GEN=true -e DELEGATE_TYPE=DOCKER -p 3050:3050 harness/delegate:latest
```

If Docker is too much, use the **Windows executable** (Harness will provide download link).

After delegate is running, you should see it in **Harness UI** → **Project Settings** → **Delegates** as "Connected".

### 5.2 Create Jenkins Connector in Harness

1. **Project Settings** → **Connectors** → **New Connector**
2. Select **Jenkins**
3. Fill in:
   - **Name:** `Local Jenkins`
   - **Jenkins URL:** `http://localhost:8080`
   - **Auth:** Username/password (admin / your Jenkins password)
   - **Delegate:** Select the delegate you just installed
4. Click **Test** → should say "Success"
5. Click **Finish**

### 5.3 Create GitHub Connector in Harness

1. **Connectors** → **New Connector** → **GitHub**
2. Fill in:
   - **Name:** `GitHub Monolith`
   - **GitHub URL:** `https://github.com/YOUR-USERNAME/monolith-app`
   - **Auth:** Personal access token (from your GitHub settings)
   - **Delegate:** Select your delegate
3. Click **Test** → "Success"
4. Click **Finish**

### 5.4 Create Service

1. **Services** → **New Service** → Name: `MonolithApp`
2. In **Deployment Type** section → Select **Deployment** (or keep default)
3. Click **Save**

### 5.5 Create Environment

1. **Environments** → **New Environment** → Name: `LocalDev`
2. **Environment Type:** Non-Production
3. **Infrastructure Definition:**
   - Name: `LocalMachine`
   - **Deployment Type:** Shell Script (this is key for local Windows deployment)
   - **Infrastructure:** Select or create
4. Click **Save**

### 5.6 Create Deployment Pipeline

1. **Pipelines** → **New Pipeline** → Name: `MonolithDeployment`

2. **Add Stage** → Type: **Deployment**

3. **Deployment Configuration:**
   - **Service:** `MonolithApp`
   - **Environment:** `LocalDev`
   - **Execution Strategies:** Rolling (default is fine)

4. **Add Execution Step** → **Trigger Jenkins Job**
   - **Connector:** `Local Jenkins`
   - **Job Name:** `MonolithBuild`
   - **Downstream Steps:** Enabled
   
5. **Add Execution Step** → **Shell Script**
   - **Name:** `Stop Old Server`
   - **Script:**
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\monolith-app\stop_server.ps1" -AppPath "C:\monolith-app"
     ```

6. **Add Execution Step** → **Fetch Files from Jenkins**
   - **Connector:** `Local Jenkins`
   - **Job Name:** `MonolithBuild`
   - **Artifact Path:** `artifacts/monolith-app.zip`
   - **Target Path:** `C:\artifacts\`

7. **Add Execution Step** → **Shell Script**
   - **Name:** `Deploy Artifact`
   - **Script:**
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\monolith-app\deploy_artifact.ps1" -ArtifactPath "C:\artifacts\monolith-app.zip" -DeployPath "C:\monolith-app" -NewVersion "v1.1.0-deployed"
     ```

8. **Add Execution Step** → **Shell Script**
   - **Name:** `Start New Server`
   - **Script:**
     ```powershell
     powershell -ExecutionPolicy Bypass -File "C:\monolith-app\start_server.ps1" -AppPath "C:\monolith-app"
     ```

9. **Add Execution Step** → **Shell Script**
   - **Name:** `Health Check`
   - **Script:**
     ```powershell
     $maxAttempts = 5
     $attempt = 0
     while ($attempt -lt $maxAttempts) {
         try {
             $response = Invoke-WebRequest -Uri "http://localhost:5000/health" -UseBasicParsing -TimeoutSec 2
             if ($response.StatusCode -eq 200) {
                 Write-Host "✓ Deployment verified - Server is healthy"
                 exit 0
             }
         }
         catch {
             $attempt++
             Start-Sleep -Seconds 2
         }
     }
     Write-Host "✗ Health check failed"
     exit 1
     ```

10. Click **Save**

---

## Part 6: Test the Full Flow (20 min)

### 6.1 Manual Pipeline Execution

1. In Harness → **Pipelines** → **MonolithDeployment**
2. Click **Run** → **Run Pipeline**
3. **Watch execution:**
   - Trigger Jenkins → Build artifact ✓
   - Stop old server ✓
   - Fetch artifact ✓
   - Deploy ✓
   - Start new server ✓
   - Health check ✓

4. **Verify in browser:**
   ```
   http://localhost:5000/health
   http://localhost:5000/info
   ```

Should show new version deployed.

### 6.2 Test GitHub Push Trigger (Optional)

1. Modify `app.py` — change version in code
2. `git commit -am "v1.2.0"`
3. `git push origin main`
4. Watch Jenkins **→** Harness auto-trigger (if webhook is connected)

---

## Part 7: Demo Script for Client (5 min)

### Demo Sequence

```
1. "Here's the Flask monolith running locally"
   → Show: curl http://localhost:5000/info
   → Current version: v1.0.0-initial

2. "I make a code change and push to GitHub"
   → Edit app.py (change a string or version)
   → git commit && git push

3. "Jenkins webhook fires and builds artifact"
   → Show: Jenkins dashboard - new build running
   → Artifact published to C:\artifacts\

4. "Harness orchestrates the deployment"
   → Show: Harness pipeline executing
   → Stages: Trigger Jenkins → Stop → Deploy → Start → Verify

5. "Old server is stopped, new code deployed, new server started"
   → Show: Log output in real-time
   → "✓ Server is healthy and responding"

6. "Verify new version is live"
   → Curl again: http://localhost:5000/info
   → Version now shows: v1.1.0-deployed ✓

TOTAL DEMO TIME: 8-10 minutes
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Jenkins can't find PowerShell scripts** | Use full path: `C:\monolith-app\start_server.ps1` |
| **Delegate won't connect to Jenkins** | Check firewall allows `localhost:8080`. Test with: `Test-NetConnection localhost -Port 8080` |
| **Health check fails** | Ensure Flask app is responding: `Invoke-WebRequest http://localhost:5000/health` |
| **Artifact not found** | Check `C:\artifacts\` exists and has `.zip` file |
| **PowerShell execution policy error** | Run PowerShell as Admin: `Set-ExecutionPolicy Bypass` |
| **GitHub webhook not firing** | Use **ngrok** to expose local Jenkins, or test manually with `Build Now` |

---

## Timeline Summary

| Step | Time |
|------|------|
| Flask app + scripts | 15 min |
| Jenkins setup | 20 min |
| Harness pipeline | 30-45 min |
| Integration testing | 15-20 min |
| **TOTAL** | **1.5-2 hours** |

---

## What You've Built

✅ **End-to-end CI/CD pipeline**  
✅ **Real code repo (GitHub)**  
✅ **Automated build (Jenkins)**  
✅ **Orchestrated deployment (Harness)**  
✅ **Local server automation (PowerShell)**  
✅ **Health verification**  

**This is production-grade thinking applied to a simple demo.** You can extend this to Kubernetes, multi-environment, approvals, rollbacks—but you've got the foundation.

---

## Next: Ready?

Copy all sections to your laptop, follow step-by-step, and message me with:
1. Any errors in the process
2. Screenshots of successful stages
3. Confirmation when full flow works

You've got this! 🚀
