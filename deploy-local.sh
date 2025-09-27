#!/bin/bash
echo "LinkU平台部署脚本"
echo "=================="

echo "1. 检查Node.js..."
if ! command -v node &> /dev/null; then
    echo "错误: 请先安装Node.js"
    exit 1
fi

echo "2. 检查Python..."
if ! command -v python &> /dev/null; then
    echo "错误: 请先安装Python"
    exit 1
fi

echo "3. 安装前端依赖..."
cd frontend
npm install
if [ $? -ne 0 ]; then
    echo "错误: 前端依赖安装失败"
    exit 1
fi

echo "4. 构建前端..."
npm run build
if [ $? -ne 0 ]; then
    echo "错误: 前端构建失败"
    exit 1
fi

echo "5. 安装后端依赖..."
cd ../backend
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "错误: 后端依赖安装失败"
    exit 1
fi

echo "6. 运行数据库迁移..."
alembic upgrade head
if [ $? -ne 0 ]; then
    echo "警告: 数据库迁移失败，请检查数据库连接"
fi

echo "7. 启动服务..."
echo "后端服务将在 http://localhost:8000 启动"
echo "前端服务将在 http://localhost:3000 启动"
echo "按Ctrl+C停止服务"

# 在后台启动前端
cd ../frontend
npm start &
FRONTEND_PID=$!

# 启动后端
cd ../backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
BACKEND_PID=$!

# 等待用户中断
trap "kill $FRONTEND_PID $BACKEND_PID; exit" INT
wait
