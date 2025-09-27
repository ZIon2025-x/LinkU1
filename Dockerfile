# 使用 Node.js 18 官方镜像
FROM node:18-alpine

# 设置工作目录
WORKDIR /app

# 复制 package 文件
COPY package*.json ./

# 安装依赖
RUN npm ci

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 安装 serve 来提供静态文件
RUN npm install -g serve

# 设置环境变量
ENV NODE_ENV=production
ENV RAILWAY_ENVIRONMENT=production
ENV PORT=3000

# 暴露端口
EXPOSE $PORT

# 启动命令 - 使用 Railway 的 PORT 环境变量
CMD sh -c "echo 'Starting frontend on port:' $PORT && serve -s build -l $PORT"