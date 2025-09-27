"""
速率限制模块
使用Redis实现分布式速率限制
"""

import time
import json
from typing import Optional, Dict, Any
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
import redis
import logging
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

class RateLimiter:
    """速率限制器"""
    
    def __init__(self):
        self.redis_client = None
        if settings.USE_REDIS:
            try:
                self.redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
                # 测试连接
                self.redis_client.ping()
                logger.info("速率限制器Redis连接成功")
            except Exception as e:
                logger.warning(f"速率限制器Redis连接失败: {e}")
                self.redis_client = None
    
    def _get_client_ip(self, request: Request) -> str:
        """获取客户端IP地址"""
        # 检查代理头
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        # 回退到直接连接IP
        if hasattr(request.client, 'host'):
            return request.client.host
        
        return "unknown"
    
    def _get_user_id(self, request: Request) -> Optional[str]:
        """从请求中获取用户ID（如果已认证）"""
        try:
            # 尝试从access_token中解析用户ID
            access_token = request.cookies.get("access_token")
            if access_token:
                from app.security import decode_token
                payload = decode_token(access_token)
                if payload and "sub" in payload:
                    return payload["sub"]
        except Exception:
            pass
        return None
    
    def _get_rate_limit_key(self, request: Request, rate_type: str) -> str:
        """生成速率限制键"""
        client_ip = self._get_client_ip(request)
        user_id = self._get_user_id(request)
        
        if user_id:
            # 已认证用户使用用户ID
            return f"rate_limit:{rate_type}:user:{user_id}"
        else:
            # 未认证用户使用IP地址
            return f"rate_limit:{rate_type}:ip:{client_ip}"
    
    def _is_rate_limited(self, key: str, limit: int, window: int) -> tuple[bool, Dict[str, Any]]:
        """检查是否超过速率限制"""
        if not self.redis_client:
            # 如果没有Redis，使用内存存储（单实例）
            return self._memory_rate_limit(key, limit, window)
        
        try:
            current_time = int(time.time())
            window_start = current_time - window
            
            # 使用Redis的滑动窗口
            pipe = self.redis_client.pipeline()
            
            # 移除过期的请求
            pipe.zremrangebyscore(key, 0, window_start)
            
            # 获取当前窗口内的请求数
            pipe.zcard(key)
            
            # 添加当前请求
            pipe.zadd(key, {str(current_time): current_time})
            
            # 设置过期时间
            pipe.expire(key, window)
            
            results = pipe.execute()
            current_requests = results[1]
            
            is_limited = current_requests >= limit
            
            return is_limited, {
                "limit": limit,
                "remaining": max(0, limit - current_requests - 1),
                "reset_time": current_time + window,
                "window": window
            }
            
        except Exception as e:
            logger.error(f"Redis速率限制检查失败: {e}")
            # Redis失败时回退到内存存储
            return self._memory_rate_limit(key, limit, window)
    
    def _memory_rate_limit(self, key: str, limit: int, window: int) -> tuple[bool, Dict[str, Any]]:
        """内存速率限制（单实例回退）"""
        if not hasattr(self, '_memory_store'):
            self._memory_store = {}
        
        current_time = int(time.time())
        window_start = current_time - window
        
        # 清理过期数据
        if key in self._memory_store:
            self._memory_store[key] = [
                req_time for req_time in self._memory_store[key]
                if req_time > window_start
            ]
        else:
            self._memory_store[key] = []
        
        # 检查是否超过限制
        current_requests = len(self._memory_store[key])
        is_limited = current_requests >= limit
        
        if not is_limited:
            self._memory_store[key].append(current_time)
        
        return is_limited, {
            "limit": limit,
            "remaining": max(0, limit - current_requests - 1),
            "reset_time": current_time + window,
            "window": window
        }
    
    def check_rate_limit(self, request: Request, rate_type: str, limit: int, window: int) -> Dict[str, Any]:
        """检查速率限制"""
        key = self._get_rate_limit_key(request, rate_type)
        is_limited, info = self._is_rate_limited(key, limit, window)
        
        if is_limited:
            # 记录速率限制事件到日志
            client_ip = self._get_client_ip(request)
            user_id = self._get_user_id(request)
            logger.warning(f"速率限制超出: {rate_type}, 用户: {user_id}, IP: {client_ip}, 限制: {info['limit']}/{info['window']}秒")
            
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "速率限制超出",
                    "message": f"请求过于频繁，请{window}秒后再试",
                    "retry_after": window,
                    "limit": info["limit"],
                    "window": info["window"]
                }
            )
        
        return info

# 创建全局速率限制器实例
rate_limiter = RateLimiter()

# 速率限制配置
RATE_LIMITS = {
    # 用户登录相关
    "login": {"limit": 5, "window": 300},  # 5次/5分钟
    "register": {"limit": 3, "window": 3600},  # 3次/小时
    "forgot_password": {"limit": 3, "window": 3600},  # 3次/小时
    "reset_password": {"limit": 5, "window": 3600},  # 5次/小时
    
    # 客服登录相关
    "cs_login": {"limit": 3, "window": 300},  # 3次/5分钟（更严格）
    "cs_refresh": {"limit": 10, "window": 60},  # 10次/分钟
    "cs_logout": {"limit": 5, "window": 60},  # 5次/分钟
    "cs_change_password": {"limit": 3, "window": 3600},  # 3次/小时
    
    # 管理员登录相关
    "admin_login": {"limit": 3, "window": 300},  # 3次/5分钟（最严格）
    "admin_refresh": {"limit": 10, "window": 60},  # 10次/分钟
    "admin_logout": {"limit": 5, "window": 60},  # 5次/分钟
    "admin_change_password": {"limit": 3, "window": 3600},  # 3次/小时
    "create_admin": {"limit": 1, "window": 3600},  # 1次/小时（超级管理员功能）
    
    # API调用
    "api_general": {"limit": 100, "window": 60},  # 100次/分钟
    "api_auth": {"limit": 20, "window": 60},  # 20次/分钟
    "api_write": {"limit": 30, "window": 60},  # 30次/分钟
    
    # 消息相关
    "send_message": {"limit": 10, "window": 60},  # 10次/分钟
    "upload_file": {"limit": 5, "window": 60},  # 5次/分钟
    
    # 任务相关
    "create_task": {"limit": 5, "window": 300},  # 5次/5分钟
    "accept_task": {"limit": 10, "window": 60},  # 10次/分钟
    
    # 客服相关
    "customer_service": {"limit": 20, "window": 60},  # 20次/分钟
    
    # 管理员操作
    "admin_operation": {"limit": 50, "window": 60},  # 50次/分钟
}

def rate_limit(rate_type: str, limit: Optional[int] = None, window: Optional[int] = None):
    """速率限制装饰器"""
    def decorator(func):
        import functools
        import asyncio
        
        # 检查函数是否为异步函数
        if asyncio.iscoroutinefunction(func):
            @functools.wraps(func)
            async def async_wrapper(*args, **kwargs):
                # 获取request对象
                request = None
                for arg in args:
                    if isinstance(arg, Request):
                        request = arg
                        break
                
                if not request:
                    # 如果没有找到request，跳过速率限制
                    return await func(*args, **kwargs)
                
                # 获取速率限制配置
                config = RATE_LIMITS.get(rate_type, {"limit": 100, "window": 60})
                actual_limit = limit or config["limit"]
                actual_window = window or config["window"]
                
                # 检查速率限制
                try:
                    rate_info = rate_limiter.check_rate_limit(request, rate_type, actual_limit, actual_window)
                    
                    # 在响应头中添加速率限制信息
                    response = await func(*args, **kwargs)
                    if hasattr(response, 'headers'):
                        response.headers["X-RateLimit-Limit"] = str(actual_limit)
                        response.headers["X-RateLimit-Remaining"] = str(rate_info["remaining"])
                        response.headers["X-RateLimit-Reset"] = str(rate_info["reset_time"])
                    
                    return response
                    
                except HTTPException as e:
                    if e.status_code == 429:
                        # 返回速率限制错误响应
                        return JSONResponse(
                            status_code=429,
                            content=e.detail,
                            headers={
                                "Retry-After": str(actual_window),
                                "X-RateLimit-Limit": str(actual_limit),
                                "X-RateLimit-Remaining": "0",
                                "X-RateLimit-Reset": str(int(time.time()) + actual_window)
                            }
                        )
                    else:
                        raise e
            
            return async_wrapper
        else:
            @functools.wraps(func)
            def sync_wrapper(*args, **kwargs):
                # 获取request对象
                request = None
                for arg in args:
                    if isinstance(arg, Request):
                        request = arg
                        break
                
                if not request:
                    # 如果没有找到request，跳过速率限制
                    return func(*args, **kwargs)
                
                # 获取速率限制配置
                config = RATE_LIMITS.get(rate_type, {"limit": 100, "window": 60})
                actual_limit = limit or config["limit"]
                actual_window = window or config["window"]
                
                # 检查速率限制
                try:
                    rate_info = rate_limiter.check_rate_limit(request, rate_type, actual_limit, actual_window)
                    
                    # 在响应头中添加速率限制信息
                    response = func(*args, **kwargs)
                    if hasattr(response, 'headers'):
                        response.headers["X-RateLimit-Limit"] = str(actual_limit)
                        response.headers["X-RateLimit-Remaining"] = str(rate_info["remaining"])
                        response.headers["X-RateLimit-Reset"] = str(rate_info["reset_time"])
                    
                    return response
                    
                except HTTPException as e:
                    if e.status_code == 429:
                        # 返回速率限制错误响应
                        return JSONResponse(
                            status_code=429,
                            content=e.detail,
                            headers={
                                "Retry-After": str(actual_window),
                                "X-RateLimit-Limit": str(actual_limit),
                                "X-RateLimit-Remaining": "0",
                                "X-RateLimit-Reset": str(int(time.time()) + actual_window)
                            }
                        )
                    else:
                        raise e
            
            return sync_wrapper
    return decorator

def get_rate_limit_info(request: Request, rate_type: str) -> Dict[str, Any]:
    """获取速率限制信息（不触发限制）"""
    config = RATE_LIMITS.get(rate_type, {"limit": 100, "window": 60})
    key = rate_limiter._get_rate_limit_key(request, rate_type)
    
    if not rate_limiter.redis_client:
        # 内存存储
        if not hasattr(rate_limiter, '_memory_store'):
            rate_limiter._memory_store = {}
        
        current_time = int(time.time())
        window_start = current_time - config["window"]
        
        if key in rate_limiter._memory_store:
            current_requests = len([
                req_time for req_time in rate_limiter._memory_store[key]
                if req_time > window_start
            ])
        else:
            current_requests = 0
    else:
        # Redis存储
        try:
            current_time = int(time.time())
            window_start = current_time - config["window"]
            rate_limiter.redis_client.zremrangebyscore(key, 0, window_start)
            current_requests = rate_limiter.redis_client.zcard(key)
        except Exception:
            current_requests = 0
    
    return {
        "rate_type": rate_type,
        "limit": config["limit"],
        "remaining": max(0, config["limit"] - current_requests),
        "reset_time": int(time.time()) + config["window"],
        "window": config["window"]
    }
