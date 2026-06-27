@echo off
setlocal
title Campus Secondhand Market - Launcher
cd /d "%~dp0"

echo ========================================
echo Campus Secondhand Market - Launcher
echo ========================================
echo.

echo [1/4] Checking Python...
if not exist ".venv\Scripts\python.exe" (
    where python >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Python command was not found. Please install Python or add it to PATH.
        echo.
        pause
        exit /b 1
    )
    echo Creating project virtual environment...
    python -m venv .venv
    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to create virtual environment.
        echo.
        pause
        exit /b 1
    )
)
if not exist ".venv\Scripts\python.exe" (
    echo [ERROR] Python command was not found. Please install Python or add it to PATH.
    echo.
    pause
    exit /b 1
)
set "PYTHON=.venv\Scripts\python.exe"
"%PYTHON%" --version
echo.

echo [2/4] Checking Python packages...
"%PYTHON%" -c "import flask, pymysql, werkzeug" >nul 2>nul
if errorlevel 1 (
    echo Required packages are missing. Running: "%PYTHON%" -m pip install -r requirements.txt
    "%PYTHON%" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo.
        echo [ERROR] Package installation failed. Please check the network or run this manually:
        echo "%PYTHON%" -m pip install -r requirements.txt
        echo.
        pause
        exit /b 1
    )
) else (
    echo Required packages are installed.
)
echo.

echo [3/4] Checking database connection...
"%PYTHON%" -c "from db import query_one; query_one('SELECT 1 AS ok')" >nul 2>nul
if errorlevel 1 (
    echo Database is not ready. Trying to start bundled MySQL...
    set "MYSQL_EXE=D:\BtSoft\mysql\MySQL5.6\bin\mysqld.exe"
    set "MYSQL_INI=D:\BtSoft\mysql\MySQL5.6\my.ini"
    if not exist "%MYSQL_EXE%" (
        echo.
        echo [ERROR] MySQL executable was not found:
        echo %MYSQL_EXE%
        echo.
        pause
        exit /b 1
    )
    if not exist "%MYSQL_INI%" (
        echo.
        echo [ERROR] MySQL config file was not found:
        echo %MYSQL_INI%
        echo.
        pause
        exit /b 1
    )
    tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | find /I "mysqld.exe" >nul
    if errorlevel 1 (
        start "" /min "%MYSQL_EXE%" --defaults-file="%MYSQL_INI%"
        timeout /t 5 /nobreak >nul
    )
    "%PYTHON%" -c "from db import query_one; query_one('SELECT 1 AS ok')" >nul 2>nul
    if errorlevel 1 (
        echo.
        echo [ERROR] Cannot connect to MySQL or database secondhand does not exist.
        echo.
        echo Please check:
        echo 1. MySQL service is running or D:\BtSoft\mysql\MySQL5.6 can start normally.
        echo 2. Database account and password in config.py are correct.
        echo 3. For first-time setup, run: "%PYTHON%" init_db.py
        echo.
        echo Note: init_db.py resets the demo database. Do not run it repeatedly unless needed.
        echo.
        pause
        exit /b 1
    )
    echo.
)
echo Database connection is OK.
echo.

echo [4/4] Starting website...
echo Browser will open: http://127.0.0.1:5000
echo Press Ctrl+C in this window to stop the website.
echo.

start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process 'http://127.0.0.1:5000'"
"%PYTHON%" app.py

echo.
echo Website stopped.
pause
