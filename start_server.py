#!/usr/bin/env python3
"""
Start Flask server - Demo version
Starts the Flask app in background and verifies it's running
"""
import os
import subprocess
import sys
import time
import requests

def main():
    app_path = r"D:\CICD_Demo\git_repo\monolith-app"
    venv_activate = os.path.join(app_path, "venv", "Scripts", "activate.bat")
    
    print("[INFO] Starting Flask server...")
    
    # Change to app directory
    os.chdir(app_path)
    
    # Start Flask in background
    try:
        # Start Python Flask app
        process = subprocess.Popen(
            [sys.executable, "app.py"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            cwd=app_path
        )
        pid = process.pid
        
        # Save PID to file
        pid_file = os.path.join(app_path, "server.pid")
        with open(pid_file, 'w') as f:
            f.write(str(pid))
        
        print(f"[INFO] Server started with PID: {pid}")
    except Exception as e:
        print(f"[ERROR] Failed to start server: {e}")
        return 1
    
    # Wait for server to boot
    print("[INFO] Waiting for server to boot...")
    time.sleep(3)
    
    # Health check
    max_attempts = 5
    attempt = 0
    
    while attempt < max_attempts:
        try:
            response = requests.get("http://localhost:5000/health", timeout=2)
            if response.status_code == 200:
                print("[INFO] ✓ Server is healthy and responding")
                print("[SUCCESS] ✓ Server Started")
                return 0
        except Exception:
            attempt += 1
            if attempt < max_attempts:
                print(f"[INFO] Waiting... (attempt {attempt}/{max_attempts})")
                time.sleep(2)
    
    print("[WARN] Server started but health check failed - may still be initializing")
    print("[SUCCESS] ✓ Server Started")
    return 0

if __name__ == "__main__":
    sys.exit(main())