"""
设备指纹生成工具
"""
import hashlib
import json
from typing import Optional, Dict, Any
from fastapi import Request


def generate_device_fingerprint(
    request: Optional[Request] = None,
    user_agent: Optional[str] = None,
    device_info: Optional[Dict[str, Any]] = None
) -> str:
    """
    生成设备指纹
    
    基于以下信息生成：
    - User-Agent
    - Accept-Language
    - Accept-Encoding
    - 屏幕分辨率（如果提供）
    - 时区（如果提供）
    - 其他浏览器特征（如果提供）
    """
    components = []
    
    # 从请求中获取信息
    if request:
        user_agent = user_agent or request.headers.get("User-Agent", "")
        accept_language = request.headers.get("Accept-Language", "")
        accept_encoding = request.headers.get("Accept-Encoding", "")
        
        components.append(f"ua:{user_agent}")
        components.append(f"lang:{accept_language}")
        components.append(f"enc:{accept_encoding}")
    elif user_agent:
        components.append(f"ua:{user_agent}")
    
    # 从设备信息中获取
    if device_info:
        if "screen" in device_info:
            screen = device_info["screen"]
            components.append(f"screen:{screen.get('width', '')}x{screen.get('height', '')}")
        
        if "timezone" in device_info:
            components.append(f"tz:{device_info['timezone']}")
        
        if "platform" in device_info:
            components.append(f"platform:{device_info['platform']}")
        
        if "hardwareConcurrency" in device_info:
            components.append(f"cpu:{device_info['hardwareConcurrency']}")
    
    # 生成哈希
    fingerprint_string = "|".join(sorted(components))
    fingerprint_hash = hashlib.sha256(fingerprint_string.encode()).hexdigest()[:64]
    
    return fingerprint_hash


def get_device_info_from_request(request: Request) -> Dict[str, Any]:
    """从请求中提取设备信息"""
    device_info = {
        "user_agent": request.headers.get("User-Agent", ""),
        "accept_language": request.headers.get("Accept-Language", ""),
        "accept_encoding": request.headers.get("Accept-Encoding", ""),
        "ip_address": request.client.host if request.client else None,
    }
    
    # 尝试从请求体或查询参数中获取前端传递的设备信息
    # 前端可以通过 JavaScript 获取更多设备特征
    return device_info


def get_ip_address(request: Optional[Request] = None) -> Optional[str]:
    """获取客户端IP地址"""
    if request and request.client:
        # 检查是否有代理头
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            # 取第一个IP（原始客户端IP）
            return forwarded_for.split(",")[0].strip()
        
        real_ip = request.headers.get("X-Real-IP")
        if real_ip:
            return real_ip
        
        return request.client.host
    
    return None

