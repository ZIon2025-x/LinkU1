#!/bin/bash

echo "安装后端依赖..."

# 检查是否在虚拟环境中
if [[ "$VIRTUAL_ENV" != "" ]]; then
    echo "✅ 检测到虚拟环境: $VIRTUAL_ENV"
else
    echo "⚠️  建议在虚拟环境中运行此脚本"
fi

# 安装新依赖
echo "安装 requests 库..."
pip install requests>=2.31.0

# 安装所有依赖
echo "安装所有依赖..."
pip install -r requirements.txt

echo "✅ 依赖安装完成！"
echo ""
echo "测试在线时间获取功能："
echo "python test_online_time.py"
