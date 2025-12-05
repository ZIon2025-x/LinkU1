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
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

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
