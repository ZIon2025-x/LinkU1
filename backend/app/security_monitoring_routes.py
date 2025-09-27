"""
安全监控相关的API路由
"""

from fastapi import APIRouter, Request, Depends, HTTPException, status
from app.security_monitoring import security_monitor, get_client_ip
from app.deps import get_current_user_secure_sync
from typing import Dict, Any

router = APIRouter(prefix="/api/security", tags=["安全监控"])

@router.get("/stats")
async def get_security_stats(
    current_user = Depends(get_current_user_secure_sync)
):
    """
    获取安全统计信息（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        stats = security_monitor.get_security_stats()
        
        return {
            "security_stats": stats,
            "message": "安全统计信息获取成功"
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取安全统计信息失败: {str(e)}"
        )

@router.post("/block-ip")
async def block_ip_address(
    ip_address: str,
    reason: str,
    current_user = Depends(get_current_user_secure_sync)
):
    """
    阻止IP地址（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        security_monitor.block_ip(ip_address, reason)
        
        return {
            "message": f"IP地址 {ip_address} 已被阻止",
            "reason": reason
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"阻止IP地址失败: {str(e)}"
        )

@router.post("/unblock-ip")
async def unblock_ip_address(
    ip_address: str,
    reason: str,
    current_user = Depends(get_current_user_secure_sync)
):
    """
    解除IP阻止（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        security_monitor.unblock_ip(ip_address, reason)
        
        return {
            "message": f"IP地址 {ip_address} 已解除阻止",
            "reason": reason
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"解除IP阻止失败: {str(e)}"
        )

@router.get("/my-ip")
async def get_my_ip_address(
    request: Request,
    current_user = Depends(get_current_user_secure_sync)
):
    """
    获取当前用户的IP地址信息
    """
    try:
        client_ip = get_client_ip(request)
        
        # 检查IP状态
        is_blocked = security_monitor.is_ip_blocked(client_ip)
        is_suspicious = client_ip in security_monitor.suspicious_ips
        
        return {
            "ip_address": client_ip,
            "is_blocked": is_blocked,
            "is_suspicious": is_suspicious,
            "user_agent": request.headers.get("User-Agent"),
            "message": "IP地址信息获取成功"
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取IP地址信息失败: {str(e)}"
        )

@router.get("/logs")
async def get_security_logs(
    limit: int = 100,
    current_user = Depends(get_current_user_secure_sync)
):
    """
    获取安全日志（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        # 读取安全日志文件
        try:
            with open("security.log", "r", encoding="utf-8") as f:
                lines = f.readlines()
                # 获取最后N行
                recent_lines = lines[-limit:] if len(lines) > limit else lines
                
                logs = []
                for line in recent_lines:
                    if line.strip():
                        # 解析日志行
                        parts = line.split(" - ", 3)
                        if len(parts) >= 4:
                            logs.append({
                                "timestamp": parts[0],
                                "logger": parts[1],
                                "level": parts[2],
                                "message": parts[3].strip()
                            })
                
                return {
                    "logs": logs,
                    "total_count": len(lines),
                    "returned_count": len(logs),
                    "message": "安全日志获取成功"
                }
                
        except FileNotFoundError:
            return {
                "logs": [],
                "total_count": 0,
                "returned_count": 0,
                "message": "安全日志文件不存在"
            }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取安全日志失败: {str(e)}"
        )

@router.post("/test-security-event")
async def test_security_event(
    event_type: str,
    details: str,
    request: Request,
    current_user = Depends(get_current_user_secure_sync)
):
    """
    测试安全事件记录（管理员功能）
    """
    try:
        # 这里可以添加管理员权限检查
        # if not current_user.is_admin:
        #     raise HTTPException(status_code=403, detail="需要管理员权限")
        
        from app.security_monitoring import log_suspicious_activity
        
        client_ip = get_client_ip(request)
        log_suspicious_activity(
            f"TEST_{event_type}",
            current_user.id,
            client_ip,
            f"测试安全事件: {details}",
            request,
            "INFO"
        )
        
        return {
            "message": f"测试安全事件 {event_type} 已记录",
            "details": details,
            "ip_address": client_ip
        }
    
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"测试安全事件失败: {str(e)}"
        )
