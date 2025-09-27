"""
角色管理系统
严格区分用户、客服、管理员角色，并提供基于角色的访问控制
"""

import enum
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, status
from sqlalchemy.orm import Session
from app import models, crud

class UserRole(enum.Enum):
    """用户角色枚举"""
    USER = "user"                    # 普通用户
    CUSTOMER_SERVICE = "cs"          # 客服
    ADMIN = "admin"                  # 管理员
    SUPER_ADMIN = "super_admin"      # 超级管理员

class RolePermissions:
    """角色权限定义"""
    
    # 用户权限
    USER_PERMISSIONS = {
        "tasks": ["create", "view_own", "accept", "complete", "cancel"],
        "messages": ["send", "view_own"],
        "reviews": ["create", "view_own"],
        "profile": ["view_own", "update_own"],
        "notifications": ["view_own", "mark_read"],
        "customer_service": ["request_chat", "send_message"]
    }
    
    # 客服权限
    CUSTOMER_SERVICE_PERMISSIONS = {
        "tasks": ["view_all", "moderate"],
        "messages": ["view_all", "send"],
        "users": ["view_all", "moderate"],
        "customer_service": ["manage_chats", "view_all_chats"],
        "admin_requests": ["create", "view_own"],
        "notifications": ["view_all", "send_announcements"]
    }
    
    # 管理员权限
    ADMIN_PERMISSIONS = {
        "tasks": ["view_all", "moderate", "delete"],
        "messages": ["view_all", "moderate"],
        "users": ["view_all", "ban", "suspend", "moderate"],
        "customer_service": ["manage", "view_all"],
        "admin_requests": ["view_all", "process"],
        "system": ["view_logs", "manage_settings"],
        "notifications": ["view_all", "send_announcements"]
    }
    
    # 超级管理员权限
    SUPER_ADMIN_PERMISSIONS = {
        "tasks": ["view_all", "moderate", "delete"],
        "messages": ["view_all", "moderate"],
        "users": ["view_all", "ban", "suspend", "moderate", "delete"],
        "customer_service": ["manage", "view_all", "create", "delete"],
        "admin_users": ["manage", "create", "delete"],
        "admin_requests": ["view_all", "process"],
        "system": ["view_logs", "manage_settings", "backup", "restore"],
        "notifications": ["view_all", "send_announcements"]
    }
    
    @classmethod
    def get_permissions(cls, role: UserRole) -> Dict[str, List[str]]:
        """获取角色权限"""
        if role == UserRole.USER:
            return cls.USER_PERMISSIONS
        elif role == UserRole.CUSTOMER_SERVICE:
            return cls.CUSTOMER_SERVICE_PERMISSIONS
        elif role == UserRole.ADMIN:
            return cls.ADMIN_PERMISSIONS
        elif role == UserRole.SUPER_ADMIN:
            return cls.SUPER_ADMIN_PERMISSIONS
        else:
            return {}

class RoleManager:
    """角色管理器"""
    
    @staticmethod
    def get_user_role(user: models.User) -> UserRole:
        """获取用户角色"""
        # 对于User模型，默认为普通用户
        # 管理员和客服有独立的模型
        return UserRole.USER
    
    @staticmethod
    def get_customer_service_role(cs: models.CustomerService) -> UserRole:
        """获取客服角色"""
        return UserRole.CUSTOMER_SERVICE
    
    @staticmethod
    def get_admin_role(admin: models.AdminUser) -> UserRole:
        """获取管理员角色"""
        if admin.is_super_admin:
            return UserRole.SUPER_ADMIN
        else:
            return UserRole.ADMIN
    
    @staticmethod
    def has_permission(user: Any, resource: str, action: str) -> bool:
        """检查用户是否有特定权限"""
        # 根据用户类型获取角色
        if isinstance(user, models.AdminUser):
            role = RoleManager.get_admin_role(user)
        elif isinstance(user, models.CustomerService):
            role = RoleManager.get_customer_service_role(user)
        else:
            role = RoleManager.get_user_role(user)
        
        permissions = RolePermissions.get_permissions(role)
        
        if resource not in permissions:
            return False
        
        return action in permissions[resource]
    
    @staticmethod
    def require_permission(resource: str, action: str):
        """权限检查装饰器"""
        def decorator(func):
            def wrapper(*args, **kwargs):
                # 从参数中获取当前用户
                current_user = None
                for arg in args:
                    if hasattr(arg, 'id'):  # 假设用户对象有id属性
                        current_user = arg
                        break
                
                if not current_user:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="未提供用户信息"
                    )
                
                if not RoleManager.has_permission(current_user, resource, action):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail=f"权限不足：需要 {resource}.{action} 权限"
                    )
                
                return func(*args, **kwargs)
            return wrapper
        return decorator

class RoleBasedAccessControl:
    """基于角色的访问控制"""
    
    @staticmethod
    def check_user_access(user: models.User, resource: str, action: str) -> bool:
        """检查用户访问权限"""
        return RoleManager.has_permission(user, resource, action)
    
    @staticmethod
    def check_customer_service_access(cs: models.CustomerService, resource: str, action: str) -> bool:
        """检查客服访问权限"""
        role = RoleManager.get_customer_service_role(cs)
        permissions = RolePermissions.get_permissions(role)
        
        if resource not in permissions:
            return False
        
        return action in permissions[resource]
    
    @staticmethod
    def check_admin_access(admin: models.AdminUser, resource: str, action: str) -> bool:
        """检查管理员访问权限"""
        role = RoleManager.get_admin_role(admin)
        permissions = RolePermissions.get_permissions(role)
        
        if resource not in permissions:
            return False
        
        return action in permissions[resource]
    
    @staticmethod
    def get_user_accessible_resources(user: Any) -> Dict[str, List[str]]:
        """获取用户可访问的资源列表"""
        role = RoleManager.get_user_role(user)
        return RolePermissions.get_permissions(role)
    
    @staticmethod
    def validate_role_transition(from_role: UserRole, to_role: UserRole) -> bool:
        """验证角色转换是否合法"""
        # 定义角色转换规则
        allowed_transitions = {
            UserRole.USER: [UserRole.CUSTOMER_SERVICE],  # 用户可以被提升为客服
            UserRole.CUSTOMER_SERVICE: [UserRole.ADMIN],  # 客服可以被提升为管理员
            UserRole.ADMIN: [UserRole.SUPER_ADMIN],  # 管理员可以被提升为超级管理员
            UserRole.SUPER_ADMIN: []  # 超级管理员不能转换
        }
        
        return to_role in allowed_transitions.get(from_role, [])

# 角色验证函数
def require_user_role():
    """要求普通用户角色"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 实现用户角色检查逻辑
            pass
        return wrapper
    return decorator

def require_customer_service_role():
    """要求客服角色"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 实现客服角色检查逻辑
            pass
        return wrapper
    return decorator

def require_admin_role():
    """要求管理员角色"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 实现管理员角色检查逻辑
            pass
        return wrapper
    return decorator

def require_super_admin_role():
    """要求超级管理员角色"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            # 实现超级管理员角色检查逻辑
            pass
        return wrapper
    return decorator
