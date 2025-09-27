@echo off
echo LinkU 本地测试环境启动脚本
echo ================================

echo 1. 检查Python环境...
python --version
if %errorlevel% neq 0 (
    echo 错误: 请先安装Python 3.11+
    pause
    exit /b 1
)

echo 2. 进入后端目录...
cd backend

echo 3. 安装后端依赖...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo 错误: 后端依赖安装失败
    pause
    exit /b 1
)

echo 4. 启动后端服务...
echo 后端服务将在 http://localhost:8000 启动
echo 健康检查: http://localhost:8000/health
echo 按Ctrl+C停止服务
echo.

python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

pause
