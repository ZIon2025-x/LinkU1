# 如何获取自己的 IP 地址

本文档说明如何获取你的 IP 地址，用于配置管理员 IP 白名单。

## 方法 1: 使用命令行（推荐）

### macOS / Linux
```bash
# 获取公网 IP
curl ifconfig.me
# 或
curl ipinfo.io/ip
# 或
curl icanhazip.com

# 获取本地 IP
ifconfig | grep "inet " | grep -v 127.0.0.1
# 或
ipconfig getifaddr en0  # macOS 获取 Wi-Fi IP
```

### Windows
```cmd
# 获取公网 IP
curl ifconfig.me
# 或
curl ipinfo.io/ip

# 获取本地 IP
ipconfig
# 查找 "IPv4 地址"
```

## 方法 2: 使用浏览器

访问以下网站，会自动显示你的 IP 地址：

1. **https://ifconfig.me** - 显示公网 IP
2. **https://ipinfo.io** - 显示 IP 和地理位置
3. **https://whatismyipaddress.com** - 显示 IP 和详细信息
4. **https://www.whatismyip.com** - 显示 IP 地址

## 方法 3: 查看后端日志

如果你已经访问过管理后台，可以在后端日志中查找你的 IP：

```bash
# 查看管理员访问日志
grep "ADMIN_SECURITY" logs/app.log | grep "IP:"

# 或查看最近的访问记录
tail -100 logs/app.log | grep "ADMIN_SECURITY"
```

## 方法 4: 使用 Python 脚本

创建一个临时脚本获取 IP：

```python
import requests

# 获取公网 IP
response = requests.get('https://api.ipify.org?format=json')
ip = response.json()['ip']
print(f"你的公网 IP: {ip}")
```

运行：
```bash
python3 get_ip.py
```

## 注意事项

### 公网 IP vs 本地 IP

- **公网 IP**: 你的网络对外显示的 IP 地址（用于 IP 白名单）
- **本地 IP**: 你的设备在局域网内的 IP（如 192.168.x.x，不用于白名单）

### 动态 IP

如果你的网络使用动态 IP（大多数家庭网络都是），IP 地址可能会变化。建议：

1. **使用 IP 白名单时**：定期检查并更新 IP
2. **或者不启用 IP 白名单**：依赖其他安全措施（来源验证、速率限制等）

### 公司/学校网络

如果你在公司或学校网络：

- 可能使用 NAT（网络地址转换）
- 多个用户共享同一个公网 IP
- 这种情况下 IP 白名单可能不太适用

## 配置 IP 白名单

获取 IP 后，在环境变量中配置：

```bash
# 单个 IP
ADMIN_IP_WHITELIST=203.0.113.1

# 多个 IP（用逗号分隔）
ADMIN_IP_WHITELIST=203.0.113.1,203.0.113.2,198.51.100.1

# 启用白名单
ENABLE_ADMIN_IP_WHITELIST=true
```

## 快速获取命令

最简单的方法，在终端运行：

```bash
curl ifconfig.me
```

这会直接显示你的公网 IP 地址。
