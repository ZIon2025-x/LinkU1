@echo off
echo LinkU平台部署脚本
echo ==================

echo 1. 检查Node.js...
node --version
if %errorlevel% neq 0 (
    echo 错误: 请先安装Node.js
    pause
    exit /b 1
)

echo 2. 检查Python...
python --version
if %errorlevel% neq 0 (
    echo 错误: 请先安装Python
    pause
    exit /b 1
)

echo 3. 安装前端依赖...
cd frontend
npm install
if %errorlevel% neq 0 (
    echo 错误: 前端依赖安装失败
    pause
    exit /b 1
)

echo 4. 构建前端...
npm run build
if %errorlevel% neq 0 (
    echo 错误: 前端构建失败
    pause
    exit /b 1
)

echo 5. 安装后端依赖...
cd ..\backend
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo 错误: 后端依赖安装失败
    pause
    exit /b 1
)

echo 6. 运行数据库迁移...
alembic upgrade head
if %errorlevel% neq 0 (
    echo 警告: 数据库迁移失败，请检查数据库连接
)

echo 7. 启动后端服务...
echo 后端服务将在 http://localhost:8000 启动
echo 前端服务将在 http://localhost:3000 启动
echo 按Ctrl+C停止服务

start cmd /k "cd frontend && npm start"
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

pause
