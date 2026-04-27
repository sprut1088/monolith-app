#!/usr/bin/env python3
"""
Health Check - Demo version
Verifies the Flask server is responding
"""
import sys
import requests
import json

def main():
    print("[INFO] Verifying deployment...")
    
    max_attempts = 5
    attempt = 0
    
    while attempt < max_attempts:
        try:
            response = requests.get("http://localhost:5000/health", timeout=2)
            if response.status_code == 200:
                data = response.json()
                print(f"[INFO] ✓ Health check passed")
                print(f"[INFO] Status: {data.get('status')}")
                print(f"[INFO] Version: {data.get('version')}")
                print("[SUCCESS] ✓ Deployment Verified")
                return 0
        except Exception as e:
            attempt += 1
            if attempt < max_attempts:
                print(f"[INFO] Attempt {attempt}/{max_attempts} - Retrying...")
                import time
                time.sleep(2)
    
    print("[ERROR] Health check failed after multiple attempts")
    return 1

if __name__ == "__main__":
    sys.exit(main())