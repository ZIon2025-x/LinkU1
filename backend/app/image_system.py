"""
全新的私密图片系统
确保图片永久可见但完全私密，外人无法通过URL访问
"""

import os
import uuid
import hashlib
import hmac
import time
from pathlib import Path
from typing import Optional, List, Dict, Any
from fastapi import HTTPException, Depends
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.models import User, Message
from app.database import get_db
import logging

logger = logging.getLogger(__name__)

class PrivateImageSystem:
    """私密图片系统"""
    
    def __init__(self):
        # 检测部署环境
        self.railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        
        # 图片存储目录
        if self.railway_env:
            self.base_dir = Path("/data/uploads/private_images")
        else:
            self.base_dir = Path("uploads/private_images")
        
        # 确保目录存在
        self.base_dir.mkdir(parents=True, exist_ok=True)
        
        # 支持的图片格式
        self.allowed_extensions = {".jpg", ".jpeg", ".png", ".gif", ".webp"}
        self.max_file_size = 5 * 1024 * 1024  # 5MB
        
        # 图片访问密钥（用于生成访问令牌）
        self.access_secret = os.getenv("IMAGE_ACCESS_SECRET", "your-image-secret-key-change-in-production")
    
    def generate_image_id(self, user_id: str, original_filename: str) -> str:
        """生成唯一的图片ID"""
        timestamp = str(int(time.time()))
        random_part = str(uuid.uuid4())[:8]
        return f"{user_id}_{timestamp}_{random_part}"
    
    def get_file_extension(self, filename: str) -> str:
        """获取文件扩展名"""
        return Path(filename).suffix.lower()
    
    def validate_image(self, content: bytes, filename: str) -> None:
        """验证图片文件"""
        # 检查文件扩展名
        ext = self.get_file_extension(filename)
        if ext not in self.allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"不支持的文件类型。支持的格式: {', '.join(self.allowed_extensions)}"
            )
        
        # 检查文件大小
        if len(content) > self.max_file_size:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大。最大允许大小: {self.max_file_size // (1024*1024)}MB"
            )
        
        # 检查文件头（简单的图片格式验证）
        if not self._is_valid_image_content(content):
            raise HTTPException(
                status_code=400,
                detail="文件内容不是有效的图片格式"
            )
    
    def _is_valid_image_content(self, content: bytes) -> bool:
        """检查文件内容是否为有效图片"""
        if len(content) < 10:
            return False
        
        # 检查常见图片格式的文件头
        image_signatures = [
            b'\xff\xd8\xff',  # JPEG
            b'\x89PNG\r\n\x1a\n',  # PNG
            b'GIF87a',  # GIF87a
            b'GIF89a',  # GIF89a
            b'RIFF',  # WebP (需要进一步检查)
        ]
        
        for signature in image_signatures:
            if content.startswith(signature):
                return True
        
        # 检查WebP格式
        if content.startswith(b'RIFF') and b'WEBP' in content[:12]:
            return True
        
        return False
    
    def save_image(self, content: bytes, image_id: str, extension: str) -> Path:
        """保存图片到私有目录"""
        filename = f"{image_id}{extension}"
        file_path = self.base_dir / filename
        
        with open(file_path, "wb") as f:
            f.write(content)
        
        return file_path
    
    def generate_access_token(self, image_id: str, user_id: str, chat_participants: List[str]) -> str:
        """生成图片访问令牌"""
        # 创建令牌数据
        token_data = {
            "image_id": image_id,
            "user_id": user_id,
            "participants": sorted(chat_participants),  # 排序确保一致性
            "timestamp": int(time.time())
        }
        
        # 生成签名
        data_string = f"{image_id}:{user_id}:{':'.join(sorted(chat_participants))}:{token_data['timestamp']}"
        signature = hmac.new(
            self.access_secret.encode('utf-8'),
            data_string.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        
        return f"{data_string}:{signature}"
    
    def verify_access_token(self, token: str, image_id: str, user_id: str) -> bool:
        """验证访问令牌"""
        try:
            parts = token.split(':')
            if len(parts) < 5:
                return False
            
            token_image_id = parts[0]
            token_user_id = parts[1]
            token_participants = parts[2:-1]  # 参与者列表
            timestamp = int(parts[-2])
            signature = parts[-1]
            
            # 检查基本参数
            if token_image_id != image_id or token_user_id != user_id:
                return False
            
            # 检查用户是否在参与者列表中
            if user_id not in token_participants:
                return False
            
            # 检查时间戳（令牌有效期24小时）
            if time.time() - timestamp > 24 * 60 * 60:
                return False
            
            # 验证签名
            data_string = f"{token_image_id}:{token_user_id}:{':'.join(sorted(token_participants))}:{timestamp}"
            expected_signature = hmac.new(
                self.access_secret.encode('utf-8'),
                data_string.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
            
            return hmac.compare_digest(signature, expected_signature)
            
        except Exception as e:
            logger.error(f"令牌验证失败: {e}")
            return False
    
    def get_chat_participants(self, db: Session, message_id: int) -> List[str]:
        """获取消息的聊天参与者"""
        message = db.query(Message).filter(Message.id == message_id).first()
        if not message:
            return []
        
        return [message.sender_id, message.receiver_id]
    
    def upload_image(self, content: bytes, filename: str, user_id: str, db: Session) -> Dict[str, Any]:
        """上传图片"""
        try:
            # 验证图片
            self.validate_image(content, filename)
            
            # 生成图片ID
            image_id = self.generate_image_id(user_id, filename)
            extension = self.get_file_extension(filename)
            
            # 保存图片
            file_path = self.save_image(content, image_id, extension)
            
            logger.info(f"用户 {user_id} 上传图片: {image_id}")
            
            return {
                "success": True,
                "image_id": image_id,
                "filename": f"{image_id}{extension}",
                "size": len(content),
                "message": "图片上传成功"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"图片上传失败: {e}")
            raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")
    
    def get_image(self, image_id: str, user_id: str, access_token: str, db: Session) -> FileResponse:
        """获取图片（需要验证访问权限）"""
        try:
            # 验证访问令牌
            if not self.verify_access_token(access_token, image_id, user_id):
                raise HTTPException(status_code=403, detail="无权访问此图片")
            
            # 查找图片文件
            image_files = list(self.base_dir.glob(f"{image_id}.*"))
            if not image_files:
                raise HTTPException(status_code=404, detail="图片不存在")
            
            file_path = image_files[0]
            
            # 确定MIME类型
            extension = file_path.suffix.lower()
            mime_types = {
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.png': 'image/png',
                '.gif': 'image/gif',
                '.webp': 'image/webp'
            }
            media_type = mime_types.get(extension, 'image/jpeg')
            
            return FileResponse(
                path=file_path,
                media_type=media_type,
                filename=file_path.name
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"获取图片失败: {e}")
            raise HTTPException(status_code=500, detail=f"获取图片失败: {str(e)}")
    
    def generate_image_url(self, image_id: str, user_id: str, chat_participants: List[str]) -> str:
        """生成图片访问URL"""
        access_token = self.generate_access_token(image_id, user_id, chat_participants)
        from app.config import Config
        base_url = Config.BASE_URL
        return f"{base_url}/api/private-image/{image_id}?user={user_id}&token={access_token}"

# 全局实例
private_image_system = PrivateImageSystem()
