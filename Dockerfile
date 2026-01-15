# 使用Python 3.11官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件（利用Docker缓存层）
COPY backend/requirements.txt /app/requirements.txt

# 安装Python依赖（这一层可以被缓存）
# 强制重新安装依赖以确保 apns2 和 Pillow 被安装（2026-01-15 更新）
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

# 验证关键依赖是否安装（构建时验证，如果失败会中断构建）
RUN python -c "import apns2; print('✓ apns2 installed')" && \
    python -c "import PIL; print('✓ Pillow installed, version:', PIL.__version__)" || \
    (echo "ERROR: Required packages not installed!" && exit 1)

# 复制后端应用代码
COPY backend/ /app

# 复制scripts目录（包含大学数据文件）
COPY scripts/ /app/scripts/

# 创建必要的上传目录
RUN mkdir -p uploads/images \
    uploads/public/images \
    uploads/public/files \
    uploads/private/images \
    uploads/private/files

# 暴露端口
EXPOSE 8000

# 启动命令 - 应用内部会自动初始化数据库
CMD ["sh", "-c", "python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
