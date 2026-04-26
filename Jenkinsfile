/**
 * Jenkinsfile for Harness Demo - Monolith Build Pipeline
 * 
 * This pipeline:
 * 1. Checks out code from GitHub
 * 2. Builds a ZIP artifact of the application
 * 3. Publishes artifact to local C:\artifacts\ folder
 * 
 * Triggered by: GitHub webhook on push or manual build
 * Artifact location: C:\artifacts\monolith-app.zip
 */

pipeline {
    agent any
    
    // Define environment variables
    environment {
        ARTIFACT_DIR = 'C:\\artifacts'
        ARTIFACT_NAME = 'monolith-app'
        BUILD_TIMESTAMP = sh(returnStdout: true, script: 'date +%Y%m%d_%H%M%S').trim()
    }
    
    // Pipeline options
    options {
        timestamps()
        timeout(time: 10, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '========================================='
                echo 'Stage: Checkout Code from GitHub'
                echo '========================================='
                
                deleteDir()
                
                checkout scm
                
                echo "✓ Code checked out from: ${GIT_URL}"
                echo "✓ Branch: ${GIT_BRANCH}"
                echo "✓ Commit: ${GIT_COMMIT}"
            }
        }
        
        stage('Build') {
            steps {
                echo '========================================='
                echo 'Stage: Build Application'
                echo '========================================='
                
                bat '''
                    echo [INFO] Current working directory:
                    cd
                    
                    echo [INFO] Listing files:
                    dir
                    
                    echo [INFO] Python version:
                    python --version
                    
                    echo [INFO] Installing dependencies:
                    pip install -r requirements.txt
                    
                    echo [SUCCESS] Build completed
                '''
            }
        }
        
        stage('Create Artifact') {
            steps {
                echo '========================================='
                echo 'Stage: Create Deployment Artifact'
                echo '========================================='
                
                bat '''
                    setlocal enabledelayedexpansion
                    
                    REM Ensure artifact directory exists
                    if not exist "%ARTIFACT_DIR%" mkdir "%ARTIFACT_DIR%"
                    
                    echo [INFO] Creating ZIP artifact...
                    echo [INFO] Source: %CD%
                    echo [INFO] Destination: %ARTIFACT_DIR%\\%ARTIFACT_NAME%.zip
                    
                    REM Remove old artifact if it exists
                    if exist "%ARTIFACT_DIR%\\%ARTIFACT_NAME%.zip" (
                        echo [INFO] Removing old artifact...
                        del /f /q "%ARTIFACT_DIR%\\%ARTIFACT_NAME%.zip"
                    )
                    
                    REM Create ZIP using PowerShell (more reliable than external tools)
                    powershell -Command "Compress-Archive -Path '*' -DestinationPath '%ARTIFACT_DIR%\\%ARTIFACT_NAME%.zip' -Force"
                    
                    if errorlevel 1 (
                        echo [ERROR] Failed to create artifact
                        exit /b 1
                    )
                    
                    echo [SUCCESS] Artifact created
                    echo [INFO] Artifact size:
                    dir "%ARTIFACT_DIR%\\%ARTIFACT_NAME%.zip"
                '''
            }
        }
        
        stage('Archive Artifacts') {
            steps {
                echo '========================================='
                echo 'Stage: Archive Artifacts (Jenkins Internal)'
                echo '========================================='
                
                archiveArtifacts artifacts: '*.py,*.txt,*.ps1', 
                                  allowEmptyArchive: false
                
                echo '✓ Artifacts archived in Jenkins'
            }
        }
    }
    
    post {
        success {
            echo '========================================='
            echo 'BUILD SUCCESSFUL'
            echo '========================================='
            echo "✓ Artifact ready at: C:\\artifacts\\monolith-app.zip"
            echo "✓ Harness can now trigger deployment pipeline"
        }
        
        failure {
            echo '========================================='
            echo 'BUILD FAILED'
            echo '========================================='
            echo "Check logs above for details"
        }
        
        always {
            echo "Build completed at: ${BUILD_TIMESTAMP}"
        }
    }
}
