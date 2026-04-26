"""
Simple Flask monolith for Harness deployment demo.
Endpoints show version to prove new code was deployed.

Setup:
    pip install Flask==2.3.2 Werkzeug==2.3.6
    python app.py
    
Visit:
    http://localhost:5000/health
    http://localhost:5000/info
    http://localhost:5000/api/data
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
            {'id': 1, 'name': 'Record 1', 'version': get_version()},
            {'id': 2, 'name': 'Record 2', 'version': get_version()},
            {'id': 3, 'name': 'Record 3', 'version': get_version()}
        ],
        'count': 3,
        'timestamp': datetime.now().isoformat()
    }), 200

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'endpoint not found', 'status': 404}), 404

@app.errorhandler(500)
def server_error(error):
    return jsonify({'error': 'internal server error', 'status': 500}), 500

if __name__ == '__main__':
    # Initialize version file on first run
    if not os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, 'w') as f:
            f.write("v1.0.0-initial")
    
    version = get_version()
    print(f"[INFO] Starting Flask monolith app")
    print(f"[INFO] Current version: {version}")
    print(f"[INFO] Server running at http://localhost:5000")
    print(f"[INFO] Health check: http://localhost:5000/health")
    print(f"[INFO] App info: http://localhost:5000/info")
    print(f"[INFO] Data API: http://localhost:5000/api/data")
    print(f"[INFO] Press Ctrl+C to stop")
    
    app.run(host='0.0.0.0', port=5000, debug=False, use_reloader=False)
