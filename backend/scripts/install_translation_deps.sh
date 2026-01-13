#!/bin/bash
# 翻译服务依赖安装脚本
# 自动检测并安装缺失的翻译服务依赖

echo "=========================================="
echo "翻译服务依赖安装脚本"
echo "=========================================="
echo ""

# 检查Python环境
if ! command -v python3 &> /dev/null; then
    echo "❌ 错误: 未找到 python3"
    exit 1
fi

echo "✓ Python环境检测通过"
echo ""

# 检查pip
if ! command -v pip3 &> /dev/null && ! command -v pip &> /dev/null; then
    echo "❌ 错误: 未找到 pip"
    exit 1
fi

PIP_CMD="pip3"
if ! command -v pip3 &> /dev/null; then
    PIP_CMD="pip"
fi

echo "✓ pip检测通过"
echo ""

# 检查当前目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "项目根目录: $PROJECT_ROOT"
echo ""

# 检查缺失的依赖
MISSING_DEPS=()

echo "检查依赖..."
echo ""

# 检查 deep-translator
python3 -c "import deep_translator" 2>/dev/null
if [ $? -ne 0 ]; then
    MISSING_DEPS+=("deep-translator")
    echo "❌ deep-translator 未安装"
else
    echo "✓ deep-translator 已安装"
fi

# 检查 google-cloud-translate
python3 -c "import google.cloud.translate_v2" 2>/dev/null
if [ $? -ne 0 ]; then
    MISSING_DEPS+=("google-cloud-translate")
    echo "❌ google-cloud-translate 未安装"
else
    echo "✓ google-cloud-translate 已安装"
fi

echo ""

# 如果没有缺失的依赖
if [ ${#MISSING_DEPS[@]} -eq 0 ]; then
    echo "✅ 所有翻译服务依赖已安装！"
    exit 0
fi

# 询问是否安装
echo "发现以下缺失的依赖:"
for dep in "${MISSING_DEPS[@]}"; do
    echo "  - $dep"
done
echo ""

read -p "是否自动安装这些依赖? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消安装"
    echo ""
    echo "手动安装命令:"
    for dep in "${MISSING_DEPS[@]}"; do
        echo "  $PIP_CMD install $dep"
    done
    exit 0
fi

# 安装缺失的依赖
echo "开始安装..."
echo ""

for dep in "${MISSING_DEPS[@]}"; do
    echo "正在安装 $dep..."
    $PIP_CMD install "$dep"
    if [ $? -eq 0 ]; then
        echo "✓ $dep 安装成功"
    else
        echo "❌ $dep 安装失败"
        exit 1
    fi
    echo ""
done

echo "=========================================="
echo "✅ 所有依赖安装完成！"
echo "=========================================="
