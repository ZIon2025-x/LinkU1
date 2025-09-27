# 使用Python 3.11官方镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY backend/requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制后端应用代码
COPY backend/ .

# 复制启动脚本
COPY start_server.sh .

# 创建上传目录
RUN mkdir -p uploads/images

# 设置启动脚本权限
RUN chmod +x start_server.sh

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["./start_server.sh"]
