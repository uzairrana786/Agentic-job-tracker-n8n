@echo off
title Launching n8n with Docker & HTTPS Pipeline

:: 1. Check if Caddy is installed or in PATH
where caddy >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Caddy was not found on your system.
    echo [INFO] Attempting auto-installation via winget...
    winget install --id CaddyServer.Caddy -e --accept-source-agreements --accept-package-agreements
    
    :: Refresh PATH for current session
    set "PATH=%LOCALAPPDATA%\Microsoft\WinGet\Packages;%PATH%"
    set "PATH=C:\Program Files\Caddy;%PATH%"
) else (
    echo [OK] Caddy is already installed!
)

:: 2. Check if Docker Desktop is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    
    echo [INFO] Waiting for Docker daemon to initialize...
    :wait_for_docker
    timeout /t 3 /nobreak >nul
    docker info >nul 2>&1
    if %errorlevel% neq 0 goto wait_for_docker
    echo [OK] Docker Desktop is ready!
) else (
    echo [OK] Docker is already running!
)

:: 3. Launch or Start n8n container in background
echo [INFO] Checking n8n container status...
docker inspect n8n >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Existing n8n container found. Starting...
    docker start n8n >nul
) else (
    echo [INFO] Creating and launching new n8n container...
    docker run -d --name n8n -p 5678:5678 -e N8N_PROTOCOL=https -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true -e N8N_CORS_ENABLED=true -e N8N_CORS_ORIGIN="*" -v n8n_data:/home/node/.n8n n8nio/n8n
)

:: 4. Launch Caddy Reverse Proxy detached using PowerShell background process
echo [INFO] Starting HTTPS reverse proxy on https://localhost:8443 ...
powershell -Command "Start-Process caddy -ArgumentList 'run' -WindowStyle Hidden" >nul 2>&1

:: 5. Dynamic Health Check: Animated dots on a NEW line (3s intervals up to 60s max = 20 retries)
echo [INFO] Waiting for n8n server to finish initializing...
set "retries=0"

:wait_for_n8n
set /a retries+=1
if %retries% gtr 30 (
    echo.
    echo [ERROR] n8n failed to start within 60 seconds.
    echo Press any key to close this window.
    pause >nul
    exit /b 1
)

:: Print a dot for each 3-second check cycle
set /p "= ." <nul

timeout /t 2 /nobreak >nul
curl.exe -s http://localhost:5678 >nul 2>&1
if %errorlevel% neq 0 goto wait_for_n8n

:: 5a. Continue dot animation on the same dot line for the final 8-second buffer wait
set "buffer_count=0"

:final_buffer_loop
set /a buffer_count+=1
set /p "= ." <nul
timeout /t 2 /nobreak >nul
if %buffer_count% lss 8 goto final_buffer_loop

:: 6. Open dashboard and exit cleanly
echo.
echo [OK] n8n server is live! Opening browser...
start https://localhost:8443

echo.
echo [SUCCESS] n8n is running with local HTTPS on https://localhost:8443
echo Press any key to close this window.
pause >nul
cmd /c exit