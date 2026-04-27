#!/usr/bin/env python3
"""
Deploy artifact - Demo version
Extracts ZIP and updates version file
"""
import os
import shutil
import sys
import zipfile
from pathlib import Path

def main():
    artifact_path = r"D:\CICD_Demo\artifacts\monolith-app.zip"
    deploy_path = r"D:\CICD_Demo\git_repo\monolith-app"
    new_version = "v1.1.0-deployed"
    
    print("[INFO] Deploying artifact...")
    print(f"[INFO] Artifact: {artifact_path}")
    
    # Validate artifact exists
    if not os.path.exists(artifact_path):
        print(f"[ERROR] Artifact not found: {artifact_path}")
        return 1
    
    # Preserve PID file
    pid_file = os.path.join(deploy_path, "server.pid")
    pid_backup = None
    
    if os.path.exists(pid_file):
        with open(pid_file, 'r') as f:
            pid_backup = f.read()
        print("[INFO] Preserving server.pid")
    
    # Extract artifact
    print("[INFO] Extracting artifact...")
    try:
        with zipfile.ZipFile(artifact_path, 'r') as zip_ref:
            zip_ref.extractall(deploy_path)
        print("[INFO] ✓ Artifact extracted")
    except Exception as e:
        print(f"[ERROR] Failed to extract artifact: {e}")
        return 1
    
    # Restore PID file
    if pid_backup:
        with open(pid_file, 'w') as f:
            f.write(pid_backup)
        print("[INFO] Restored server.pid")
    
    # Update version file
    try:
        version_file = os.path.join(deploy_path, "version.txt")
        with open(version_file, 'w') as f:
            f.write(new_version)
        print(f"[INFO] ✓ Version updated: {new_version}")
    except Exception as e:
        print(f"[WARN] Failed to update version file: {e}")
    
    print("[SUCCESS] ✓ Deployment Complete")
    return 0

if __name__ == "__main__":
    sys.exit(main())