# Harness Demo - Windows Quick Reference

## File Locations on Your Laptop

```
C:\monolith-app\                    # Application directory
├── app.py                          # Flask app
├── requirements.txt                # Python dependencies
├── start_server.ps1                # Start script
├── stop_server.ps1                 # Stop script
├── deploy_artifact.ps1             # Deploy script
├── version.txt                     # Current deployed version
└── server.pid                      # Process ID of running server

C:\artifacts\                       # Jenkins artifact storage
└── monolith-app.zip                # Build artifact

Jenkins: http://localhost:8080      # Jenkins dashboard
Harness: https://app.harness.io     # Harness console
Flask App: http://localhost:5000    # Your application
```

---

## Quick Test Commands (PowerShell)

### Test Flask App Endpoints

```powershell
# Health check
Invoke-WebRequest -Uri http://localhost:5000/health -UseBasicParsing

# App info (shows deployed version)
Invoke-WebRequest -Uri http://localhost:5000/info -UseBasicParsing

# API data
Invoke-WebRequest -Uri http://localhost:5000/api/data -UseBasicParsing

# Pretty print JSON response
$response = Invoke-WebRequest -Uri http://localhost:5000/info -UseBasicParsing
$response.Content | ConvertFrom-Json | ConvertTo-Json
```

### Test Scripts Manually

```powershell
# Start server
cd C:\monolith-app
.\start_server.ps1

# In another PowerShell window, stop server
cd C:\monolith-app
.\stop_server.ps1

# Deploy artifact
.\deploy_artifact.ps1 -ArtifactPath "C:\artifacts\monolith-app.zip" `
  -DeployPath "C:\monolith-app" `
  -NewVersion "v1.2.0-test"
```

### Test Jenkins Connectivity

```powershell
# Check if Jenkins is running
Test-NetConnection localhost -Port 8080

# Check artifact was created
Get-ChildItem C:\artifacts\

# Check artifact contents
Expand-Archive -Path C:\artifacts\monolith-app.zip -DestinationPath C:\temp-extract -Force
Get-ChildItem C:\temp-extract\
```

---

## Demo Checklist (Before Showing Client)

### Pre-Demo (30 min before)
- [ ] Start Jenkins: `http://localhost:8080` → check it's running
- [ ] Manual build: **MonolithBuild** → Click **Build Now** → Wait for success
- [ ] Check artifact: `C:\artifacts\monolith-app.zip` exists
- [ ] Start Flask: `.\start_server.ps1` → Wait for health check to pass
- [ ] Test endpoints: `curl http://localhost:5000/info` shows current version
- [ ] Stop Flask: `.\stop_server.ps1`
- [ ] Check Harness: Login → **Pipelines** → **MonolithDeployment** → Ready to run

### Demo Sequence (8-10 min)
1. Open VS Code → Show `app.py` code
2. Make a small visible change (e.g., comment or string change)
3. Show Git: `git status`, `git commit -am "demo change"`, `git push`
4. Show Jenkins: Watch webhook fire → Build auto-start
5. Show Jenkins: Build logs → Artifact published
6. Show Harness: Pipeline auto-triggered OR manually click **Run**
7. Show Harness: Watch stages execute:
   - Trigger Jenkins ✓
   - Stop server ✓
   - Fetch artifact ✓
   - Deploy ✓
   - Start server ✓
   - Health check ✓
8. Show Flask endpoint: `curl http://localhost:5000/info` → New version deployed
9. **DONE** 👏

---

## Troubleshooting

### "Flask app won't start"
```powershell
# Check if port 5000 is in use
netstat -ano | findstr :5000

# Kill if needed
taskkill /PID <PID> /F

# Verify Python is working
python --version
python -c "from flask import Flask; print('Flask OK')"
```

### "Jenkins can't find artifact"
```powershell
# Verify artifact was created
Get-ChildItem C:\artifacts\

# Check artifact is valid ZIP
Expand-Archive -Path C:\artifacts\monolith-app.zip -DestinationPath C:\temp-test

# Check Jenkins artifact folder
Get-ChildItem "$env:JENKINS_HOME\jobs\MonolithBuild\builds\*\archive\"
```

### "Harness can't connect to Jenkins"
```powershell
# Test connectivity
Test-NetConnection localhost -Port 8080

# Check firewall
netsh advfirewall firewall show rule name="Jenkins"

# Verify Jenkins credentials in Harness
# Go to: Harness → Project Settings → Connectors → LocalJenkins → Test
```

### "Harness Delegate not connecting"
```powershell
# Check Docker (if using Docker delegate)
docker ps | findstr delegate

# Check Windows Service (if installed as service)
Get-Service -Name "Harness*"

# Check Harness UI
# Go to: Project Settings → Delegates → should show "Connected"
```

### "PowerShell script execution policy error"
```powershell
# In PowerShell as Admin
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force

# Verify
Get-ExecutionPolicy -Scope CurrentUser
```

### "Version file not updating"
```powershell
# Check version file
Get-Content C:\monolith-app\version.txt

# Manually update
"v1.2.0-test" | Out-File -FilePath C:\monolith-app\version.txt -Encoding UTF8

# Verify
Get-Content C:\monolith-app\version.txt
```

---

## Useful Commands

### Get IP Address (for GitHub webhook)
```powershell
ipconfig

# Or just the IPv4 address
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -like "*Ethernet*" -or $_.InterfaceAlias -like "*Wi-Fi*"} | Select-Object IPAddress
```

### Start Jenkins Manually
```powershell
# If Jenkins is a service
Start-Service Jenkins

# If Jenkins is a WAR file
java -jar C:\path\to\jenkins.war

# Check if running
Get-Service Jenkins | Select-Object Status
```

### View Recent Logs
```powershell
# Flask app logs (if running in foreground)
# Ctrl+C to stop, then check for error messages

# Jenkins logs
Get-Content "$env:JENKINS_HOME\logs\jenkins.log" -Tail 50

# PowerShell script logs (from Harness)
# Check Harness execution logs in UI
```

---

## Important Paths (Copy Exactly)

**Don't** use these as-is; ensure they match your setup:

| Path | Purpose |
|------|---------|
| `C:\monolith-app` | App directory (changeable) |
| `C:\artifacts` | Jenkins artifact output (changeable in Jenkins config) |
| `C:\monolith-app\version.txt` | Version tracking |
| `C:\monolith-app\server.pid` | Process ID tracking |
| `http://localhost:5000` | Flask app (changeable in app.py) |
| `http://localhost:8080` | Jenkins (default) |

---

## GitHub Webhook Testing (Advanced)

If webhook isn't auto-triggering:

### Option 1: Use ngrok (local tunnel to GitHub)
```powershell
# Download ngrok from ngrok.com, then:
ngrok http 8080

# Copy the HTTPS URL provided (e.g., https://abc123.ngrok.io)
# Use in GitHub webhook: https://abc123.ngrok.io/github-webhook/
```

### Option 2: Test Webhook Manually
```powershell
# Trigger Jenkins build manually
Invoke-WebRequest -Uri "http://localhost:8080/job/MonolithBuild/build" `
    -Method POST `
    -Credential (New-Object System.Management.Automation.PSCredential `
        "admin", (ConvertTo-SecureString "YOUR_PASSWORD" -AsPlainText -Force))
```

### Option 3: Verify Webhook in GitHub
```
GitHub Repo → Settings → Webhooks → Click webhook → 
Scroll down to "Recent Deliveries" → See if requests succeeded
```

---

## Success Criteria ✓

Full demo is working when:

- [ ] `git push` → Jenkins build triggers automatically
- [ ] Jenkins build → Creates artifact in `C:\artifacts\`
- [ ] Harness pipeline → Starts automatically or on manual click
- [ ] Harness → Triggers Jenkins, gets artifact, deploys locally
- [ ] Flask server → Stops, new code deployed, restarts
- [ ] Health check → Passes, new version visible in `/info` endpoint
- [ ] Demo to client → Shows end-to-end CICD in 10 minutes

**You're ready when all above ✓**

---

## After Demo: Cleanup

```powershell
# If you want to reset for next demo
# Stop server
.\stop_server.ps1

# Reset version
"v1.0.0-initial" | Out-File -FilePath C:\monolith-app\version.txt -Encoding UTF8

# Clear artifact
Remove-Item C:\artifacts\monolith-app.zip -Force

# Clear Jenkins builds
# Go to Jenkins UI → Job → Delete builds or use REST API
```

---

## Additional Resources

- **Flask docs:** https://flask.palletsprojects.com/
- **Jenkins docs:** https://jenkins.io/doc/
- **Harness docs:** https://docs.harness.io/
- **PowerShell docs:** https://docs.microsoft.com/powershell/
- **GitHub webhooks:** https://docs.github.com/webhooks/

---

**Questions?** Message me with:
1. Your current step
2. Any error messages (paste full output)
3. Screenshot of what you're seeing
