#!/bin/bash
# Railway 启动脚本

echo "=== Railway 启动调试 ==="
echo "时间: $(date)"
echo "工作目录: $(pwd)"
echo "环境变量 PORT: $PORT"
echo "Python 版本: $(python --version)"

# 设置默认端口
export PORT=${PORT:-8000}
echo "使用端口: $PORT"

# 检查文件
echo "=== 文件检查 ==="
ls -la app/
echo "app/main.py 存在: $([ -f app/main.py ] && echo 'YES' || echo 'NO')"

# 检查导入
echo "=== 导入测试 ==="
python -c "import app.main; print('导入成功')" || exit 1

# 启动服务
echo "=== 启动服务 ==="
echo "端口: $PORT"
exec python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT --no-access-log
