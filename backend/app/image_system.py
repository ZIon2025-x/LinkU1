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
    
    def get_file_extension(self, filename: str, content_type: Optional[str] = None, content: Optional[bytes] = None) -> str:
        """获取文件扩展名（支持从 filename、Content-Type 或 magic bytes 检测）"""
        from app.file_utils import detect_file_extension
        ext = detect_file_extension(filename=filename, content_type=content_type, content=content)
        return ext
    
    def validate_image(self, content: bytes, filename: str, content_type: Optional[str] = None) -> None:
        """验证图片文件"""
        # 检查文件扩展名（支持从 Content-Type 或 magic bytes 检测）
        ext = self.get_file_extension(filename, content_type=content_type, content=content)
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
    
    def save_image(self, content: bytes, image_id: str, extension: str, task_id: Optional[int] = None, chat_id: Optional[str] = None) -> Path:
        """保存图片到私有目录，按任务ID或聊天ID分类"""
        filename = f"{image_id}{extension}"
        
        # 根据是否有task_id或chat_id创建子文件夹
        if task_id:
            # 任务聊天：按任务ID分类
            task_dir = self.base_dir / "tasks" / str(task_id)
            task_dir.mkdir(parents=True, exist_ok=True)
            file_path = task_dir / filename
        elif chat_id:
            # 客服聊天：按聊天ID分类
            chat_dir = self.base_dir / "chats" / chat_id
            chat_dir.mkdir(parents=True, exist_ok=True)
            file_path = chat_dir / filename
        else:
            # 没有分类信息，保存在根目录（向后兼容）
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
    
    def verify_access_token(self, token: str, image_id: str, user_id: str, db: Session = None) -> bool:
        """验证访问令牌
        
        Args:
            token: 访问令牌
            image_id: 图片ID
            user_id: 用户ID
            db: 数据库会话（可选，用于任务聊天场景下的扩展验证）
        
        Returns:
            bool: 是否验证通过
        """
        try:
            parts = token.split(':')
            if len(parts) < 5:
                logger.error(f"令牌格式错误，部分数量不足: {len(parts)}")
                return False
            
            token_image_id = parts[0]
            token_user_id = parts[1]
            
            # 找到时间戳和签名的位置
            # 格式: image_id:user_id:participant1:participant2:...:timestamp:signature
            timestamp = None
            signature = None
            participants = []
            
            # 从后往前找时间戳和签名
            for i in range(len(parts) - 1, 1, -1):
                try:
                    # 尝试解析为时间戳
                    timestamp = int(parts[i])
                    # 如果成功，那么前面的都是参与者，后面的是签名
                    participants = parts[2:i]
                    signature = parts[i + 1]
                    break
                except ValueError:
                    continue
            
            if timestamp is None or signature is None:
                logger.error(f"无法解析令牌时间戳和签名: {token}")
                return False
            
            logger.info(f"令牌解析: image_id={token_image_id}, user_id={token_user_id}, participants={participants}, timestamp={timestamp}")
            
            # 检查基本参数
            if token_image_id != image_id or token_user_id != user_id:
                logger.error(f"令牌参数不匹配: token_image_id={token_image_id}, image_id={image_id}, token_user_id={token_user_id}, user_id={user_id}")
                return False
            
            # 检查用户是否在参与者列表中
            if user_id not in participants:
                logger.error(f"用户不在参与者列表中: user_id={user_id}, participants={participants}")
                return False
            
            # 检查时间戳（令牌有效期24小时）
            current_time = time.time()
            token_age = current_time - timestamp
            is_token_expired = token_age > 24 * 60 * 60
            
            # 如果token过期，但提供了数据库会话，尝试扩展验证（任务聊天场景）
            if is_token_expired and db is not None:
                # 检查是否是任务聊天中的图片，且任务还在进行中
                from app.models import Message
                task_message = db.query(Message).filter(Message.image_id == image_id).first()
                if task_message and task_message.task_id:
                    from app import crud
                    task = crud.get_task(db, task_message.task_id)
                    if task:
                        # 任务状态：open, in_progress, pending_payment, pending_confirmation 都视为进行中
                        active_statuses = ["open", "in_progress", "pending_payment", "pending_confirmation"]
                        if task.status in active_statuses:
                            # 验证用户是否是任务的参与者
                            is_poster = task.poster_id == user_id
                            is_taker = task.taker_id == user_id
                            if is_poster or is_taker:
                                logger.info(f"Token已过期但任务仍在进行中，允许访问: task_id={task.id}, status={task.status}, user_id={user_id}")
                                # 即使token过期，只要用户是任务参与者且任务在进行中，也允许访问
                                # 但仍需验证签名以确保token未被篡改
                                data_string = f"{token_image_id}:{token_user_id}:{':'.join(sorted(participants))}:{timestamp}"
                                expected_signature = hmac.new(
                                    self.access_secret.encode('utf-8'),
                                    data_string.encode('utf-8'),
                                    hashlib.sha256
                                ).hexdigest()
                                
                                is_valid = hmac.compare_digest(signature, expected_signature)
                                if is_valid:
                                    return True
                                else:
                                    logger.error(f"签名验证失败（任务聊天场景）: expected={expected_signature}, actual={signature}")
                                    return False
            
            # 如果token过期且不是任务聊天场景，拒绝访问
            if is_token_expired:
                logger.error(f"令牌已过期: current_time={current_time}, timestamp={timestamp}, diff={token_age}")
                return False
            
            # 验证签名
            data_string = f"{token_image_id}:{token_user_id}:{':'.join(sorted(participants))}:{timestamp}"
            expected_signature = hmac.new(
                self.access_secret.encode('utf-8'),
                data_string.encode('utf-8'),
                hashlib.sha256
            ).hexdigest()
            
            is_valid = hmac.compare_digest(signature, expected_signature)
            if not is_valid:
                logger.error(f"签名验证失败: expected={expected_signature}, actual={signature}")
            
            return is_valid
            
        except Exception as e:
            logger.error(f"令牌验证失败: {e}")
            return False
    
    def get_chat_participants(self, db: Session, message_id: int) -> List[str]:
        """获取消息的聊天参与者"""
        from app.models import Task
        message = db.query(Message).filter(Message.id == message_id).first()
        if not message:
            return []
        
        # 如果是任务聊天，从任务中获取参与者
        if hasattr(message, 'conversation_type') and message.conversation_type == 'task' and message.task_id:
            task = db.query(Task).filter(Task.id == message.task_id).first()
            if task:
                participants = [task.poster_id]
                if task.taker_id:
                    participants.append(task.taker_id)
                return participants
        
        # 普通聊天：使用发送者和接收者
        participants = [message.sender_id]
        if message.receiver_id:
            participants.append(message.receiver_id)
        return participants
    
    def upload_image(self, content: bytes, filename: str, user_id: str, db: Session, task_id: Optional[int] = None, chat_id: Optional[str] = None, content_type: Optional[str] = None) -> Dict[str, Any]:
        """上传图片，支持按任务ID或聊天ID分类"""
        try:
            # 验证图片（支持从 Content-Type 或 magic bytes 检测）
            self.validate_image(content, filename, content_type=content_type)
            
            # 生成图片ID
            image_id = self.generate_image_id(user_id, filename)
            extension = self.get_file_extension(filename, content_type=content_type, content=content)
            
            # 保存图片（按任务ID或聊天ID分类）
            file_path = self.save_image(content, image_id, extension, task_id, chat_id)
            
            location_info = ""
            if task_id:
                location_info = f"任务ID: {task_id}"
            elif chat_id:
                location_info = f"聊天ID: {chat_id}"
            
            logger.info(f"用户 {user_id} 上传图片: {image_id} ({location_info})")
            
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
            # 验证访问令牌（传入db用于任务聊天场景下的扩展验证）
            if not self.verify_access_token(access_token, image_id, user_id, db=db):
                raise HTTPException(status_code=403, detail="无权访问此图片")
            
            # 优化：先从数据库查询消息，获取task_id或chat_id，直接定位文件夹
            file_path = None
            
            # 1. 先查询任务消息表（Message）
            from app.models import Message
            task_message = db.query(Message).filter(Message.image_id == image_id).first()
            if task_message and task_message.task_id:
                # 任务聊天图片：直接定位到任务文件夹
                task_dir = self.base_dir / "tasks" / str(task_message.task_id)
                for ext in self.allowed_extensions:
                    potential_file = task_dir / f"{image_id}{ext}"
                    if potential_file.exists() and potential_file.is_file():
                        file_path = potential_file
                        break
            
            # 2. 如果没找到，查询客服消息表（CustomerServiceMessage）
            if not file_path:
                from app.models import CustomerServiceMessage
                cs_message = db.query(CustomerServiceMessage).filter(
                    CustomerServiceMessage.image_id == image_id
                ).first()
                if cs_message and cs_message.chat_id:
                    # 客服聊天图片：直接定位到聊天文件夹
                    chat_dir = self.base_dir / "chats" / cs_message.chat_id
                    for ext in self.allowed_extensions:
                        potential_file = chat_dir / f"{image_id}{ext}"
                        if potential_file.exists() and potential_file.is_file():
                            file_path = potential_file
                            break
            
            # 3. 如果数据库查询失败或文件不存在，回退到全局搜索（向后兼容）
            if not file_path:
                image_files = []
                
                # 先查找任务文件夹
                task_dirs = list(self.base_dir.glob("tasks/*"))
                for task_dir in task_dirs:
                    task_files = list(task_dir.glob(f"{image_id}.*"))
                    if task_files:
                        image_files.extend(task_files)
                
                # 再查找聊天文件夹
                chat_dirs = list(self.base_dir.glob("chats/*"))
                for chat_dir in chat_dirs:
                    chat_files = list(chat_dir.glob(f"{image_id}.*"))
                    if chat_files:
                        image_files.extend(chat_files)
                
                # 最后查找根目录（向后兼容）
                root_files = list(self.base_dir.glob(f"{image_id}.*"))
                if root_files:
                    image_files.extend(root_files)
                
                if image_files:
                    file_path = image_files[0]
            
            if not file_path or not file_path.exists() or not file_path.is_file():
                raise HTTPException(status_code=404, detail="图片不存在")
            
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
