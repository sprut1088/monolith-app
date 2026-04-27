#!/usr/bin/env python3
"""
Stop Flask server - Demo version
Reads PID from file and stops the process
"""
import os
import signal
import sys
from pathlib import Path

def main():
    app_path = r"D:\CICD_Demo\git_repo\monolith-app"
    pid_file = os.path.join(app_path, "server.pid")
    
    print("[INFO] Stopping Flask server...")
    
    # Check if PID file exists
    if not os.path.exists(pid_file):
        print("[WARN] No server PID file found - server may not be running")
        print("[INFO] ✓ Server stopped (or was not running)")
        return 0
    
    # Read PID
    try:
        with open(pid_file, 'r') as f:
            pid = int(f.read().strip())
    except Exception as e:
        print(f"[ERROR] Failed to read PID file: {e}")
        return 1
    
    # Kill process
    try:
        print(f"[INFO] Killing process PID: {pid}")
        os.kill(pid, signal.SIGTERM)
        print("[INFO] ✓ Process terminated")
    except ProcessLookupError:
        print(f"[WARN] Process {pid} not found")
    except Exception as e:
        print(f"[ERROR] Failed to kill process: {e}")
        return 1
    
    # Clean up PID file
    try:
        os.remove(pid_file)
        print("[INFO] PID file cleaned up")
    except Exception as e:
        print(f"[WARN] Failed to remove PID file: {e}")
    
    print("[SUCCESS] ✓ Server Stopped")
    return 0

if __name__ == "__main__":
    sys.exit(main())