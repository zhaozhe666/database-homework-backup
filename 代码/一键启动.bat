@echo off
chcp 65001 >nul
title 校园二手交易平台 - 一键启动

cd /d "%~dp0"

echo ========================================
echo 校园二手交易平台 - 一键启动
echo ========================================
echo.

echo [1/4] 检查 Python 环境...
where python >nul 2>nul
if errorlevel 1 (
    echo [错误] 没有找到 python 命令，请先安装 Python，或把 Python 加入系统 PATH。
    echo.
    pause
    exit /b 1
)
python --version
echo.

echo [2/4] 检查依赖包...
python -c "import flask, pymysql, werkzeug" >nul 2>nul
if errorlevel 1 (
    echo 检测到依赖不完整，正在执行：python -m pip install -r requirements.txt
    python -m pip install -r requirements.txt
    if errorlevel 1 (
        echo.
        echo [错误] 依赖安装失败，请检查网络或手动执行：
        echo python -m pip install -r requirements.txt
        echo.
        pause
        exit /b 1
    )
) else (
    echo 依赖已安装。
)
echo.

echo [3/4] 检查数据库连接...
python -c "from db import query_one; query_one('SELECT 1 AS ok')" >nul 2>nul
if errorlevel 1 (
    echo [错误] 无法连接 MySQL 或数据库 secondhand 不存在。
    echo.
    echo 请先确认：
    echo 1. MySQL 服务已经启动。
    echo 2. config.py 里的数据库账号和密码正确。
    echo 3. 首次运行时，先手动执行：python init_db.py
    echo.
    echo 注意：init_db.py 会清空并重建演示数据库，平时不要重复执行。
    echo.
    pause
    exit /b 1
)
echo 数据库连接正常。
echo.

echo [4/4] 启动网站...
echo 浏览器将自动打开：http://127.0.0.1:5000
echo 关闭网站时，请在本窗口按 Ctrl + C。
echo.

start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "Start-Sleep -Seconds 2; Start-Process 'http://127.0.0.1:5000'"
python app.py

echo.
echo 网站已停止。
pause
