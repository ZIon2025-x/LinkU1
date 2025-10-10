# Railway 运行检查脚本指南

## 🚀 方法1: 使用Railway CLI（推荐）

### 步骤1: 安装Railway CLI
```bash
# 使用npm安装
npm install -g @railway/cli

# 或使用yarn
yarn global add @railway/cli

# 或使用pnpm
pnpm add -g @railway/cli
```

### 步骤2: 登录和连接
```bash
# 登录Railway
railway login

# 链接到您的项目
railway link

# 如果不知道项目ID，可以列出所有项目
railway projects
```

### 步骤3: 运行检查脚本
```bash
# 运行完整检查
railway run python check_railway_deployment.py

# 或者运行简化检查
railway run python -c "from app.models import get_uk_time_online; print('UK Time:', get_uk_time_online())"
```

## 🌐 方法2: 通过API端点（最简单）

### 部署后访问API端点
```bash
# 完整检查
curl https://your-app.railway.app/health/time-check

# 简化检查
curl https://your-app.railway.app/health/time-check/simple
```

### 在浏览器中访问
- 完整检查: `https://your-app.railway.app/health/time-check`
- 简化检查: `https://your-app.railway.app/health/time-check/simple`

## 💻 方法3: 通过Railway控制台

### 步骤1: 访问Railway控制台
1. 登录 [railway.app](https://railway.app)
2. 选择您的项目

### 步骤2: 使用终端
1. 进入 "Deployments" 标签页
2. 点击 "View Logs" 旁边的终端图标
3. 在终端中运行：
```bash
python check_railway_deployment.py
```

## 🔍 方法4: 查看部署日志

### 在Railway控制台查看日志
1. 进入项目的 "Deployments" 标签页
2. 点击最新的部署
3. 查看 "Logs" 标签页
4. 查找类似以下的信息：
```
尝试使用 WorldTimeAPI 获取英国时间...
成功从 WorldTimeAPI 获取英国时间: 2024-01-15 14:30:25+00:00
```

## 📊 检查结果说明

### 成功示例
```json
{
  "status": "success",
  "uk_time": "2024-01-15T14:30:25+00:00",
  "timezone": "Europe/London",
  "is_dst": false,
  "message": "在线时间获取功能正常工作"
}
```

### 失败示例
```json
{
  "status": "error",
  "error": "所有在线时间API都失败，使用本地时间",
  "message": "在线时间获取功能出现问题"
}
```

## 🛠️ 故障排除

### 问题1: Railway CLI未安装
```bash
# 检查是否已安装
railway --version

# 如果未安装，重新安装
npm install -g @railway/cli
```

### 问题2: 无法链接项目
```bash
# 重新登录
railway logout
railway login

# 重新链接
railway link
```

### 问题3: 脚本运行失败
```bash
# 检查Python环境
railway run python --version

# 检查依赖
railway run pip list | grep requests

# 手动安装依赖
railway run pip install requests>=2.31.0
```

### 问题4: API端点无法访问
1. 检查应用是否正在运行
2. 检查URL是否正确
3. 查看Railway部署日志

## 📝 快速验证命令

### 一行命令检查
```bash
# 使用Railway CLI
railway run python -c "from app.models import get_uk_time_online; print('✅ UK Time:', get_uk_time_online())"

# 使用curl（部署后）
curl -s https://your-app.railway.app/health/time-check/simple | python -m json.tool
```

### 检查环境变量
```bash
railway run python -c "import os; print('ENABLE_ONLINE_TIME:', os.getenv('ENABLE_ONLINE_TIME', 'true'))"
```

## 🎯 推荐流程

1. **部署前**: 在本地测试 `python check_railway_deployment.py`
2. **部署后**: 使用API端点 `https://your-app.railway.app/health/time-check/simple`
3. **调试时**: 使用Railway CLI `railway run python check_railway_deployment.py`
4. **监控时**: 查看Railway控制台日志

---

**提示**: 最简单的方法是部署后直接访问API端点，无需安装任何额外工具！
