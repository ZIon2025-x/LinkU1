"""
Gunicorn 配置文件
生产环境多进程部署：gunicorn -c gunicorn.conf.py app.main:app
"""

import os
import multiprocessing

# ─── 基础配置 ───
bind = f"0.0.0.0:{os.getenv('PORT', '8000')}"
worker_class = "uvicorn.workers.UvicornWorker"

# Worker 数量：优先读环境变量，默认 CPU 核数 × 2 + 1（上限 8）
# Railway 一般 1-2 核，所以默认 2-4 个 worker
_default_workers = min(multiprocessing.cpu_count() * 2 + 1, 8)
workers = int(os.getenv("WEB_CONCURRENCY", str(_default_workers)))

# ─── Worker 生命周期 ───
# 每个 worker 处理一定请求后自动重启，防内存泄漏
max_requests = int(os.getenv("GUNICORN_MAX_REQUESTS", "2000"))
max_requests_jitter = int(os.getenv("GUNICORN_MAX_REQUESTS_JITTER", "200"))

# Worker 启动/关闭超时
timeout = int(os.getenv("GUNICORN_TIMEOUT", "120"))
graceful_timeout = 30
keep_alive = 5

# ─── 日志 ───
accesslog = "-"  # stdout
errorlog = "-"   # stderr
loglevel = os.getenv("GUNICORN_LOG_LEVEL", "info")

# ─── 进程管理 ───
# 预加载应用：共享内存（省 RAM），但 worker 不能热重载代码
preload_app = os.getenv("GUNICORN_PRELOAD", "true").lower() == "true"

# 优雅重启时先 fork 新 worker 再杀旧的
forwarded_allow_ips = "*"  # Railway 在代理后面，信任 X-Forwarded-*
proxy_allow_from = "*"
