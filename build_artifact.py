#!/usr/bin/env python
"""
Simple build script - creates ZIP artifact
Run from Jenkins as: python build_artifact.py
"""
import os
import shutil
import sys
from pathlib import Path

def main():
    # Paths
    workspace = os.getcwd()
    artifact_dir = r"D:\CICD_Demo\artifacts"
    artifact_file = os.path.join(artifact_dir, "monolith-app.zip")
    
    print(f"[INFO] Workspace: {workspace}")
    print(f"[INFO] Listing files:")
    
    # List current files
    for item in os.listdir(workspace):
        print(f"  - {item}")
    
    # Create artifact directory
    print(f"\n[INFO] Creating artifact directory: {artifact_dir}")
    os.makedirs(artifact_dir, exist_ok=True)
    
    # Remove old artifact
    if os.path.exists(artifact_file):
        print(f"[INFO] Removing old artifact...")
        os.remove(artifact_file)
    
    # Create ZIP
    print(f"\n[INFO] Creating artifact ZIP...")
    try:
        shutil.make_archive(
            os.path.join(artifact_dir, "monolith-app"),
            'zip',
            workspace,
            "."
        )
        print(f"[SUCCESS] Artifact created")
    except Exception as e:
        print(f"[ERROR] Failed to create artifact: {e}")
        sys.exit(1)
    
    # Verify
    if os.path.exists(artifact_file):
        size = os.path.getsize(artifact_file)
        print(f"\n[SUCCESS] Artifact ready: {artifact_file}")
        print(f"[INFO] Size: {size} bytes")
        sys.exit(0)
    else:
        print(f"[ERROR] Artifact file not found after creation")
        sys.exit(1)

if __name__ == "__main__":
    main()