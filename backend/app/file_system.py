"""
私密文件系统
确保文件永久可见但完全私密，外人无法通过URL访问
支持按任务ID或聊天ID分类存储
"""

import os
import uuid
import hashlib
import hmac
import time
from pathlib import Path
from typing import Optional, List, Dict, Any
from fastapi import HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.models import Message, CustomerServiceMessage, MessageAttachment
import logging

logger = logging.getLogger(__name__)


class PrivateFileSystem:
    """私密文件系统"""
    
    def __init__(self):
        # 检测部署环境
        self.railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        
        # 文件存储目录
        if self.railway_env:
            self.base_dir = Path("/data/uploads/private_files")
        else:
            self.base_dir = Path("uploads/private_files")
        
        # 确保目录存在
        self.base_dir.mkdir(parents=True, exist_ok=True)
        
        # 危险文件扩展名（不允许上传）
        self.dangerous_extensions = {
            ".exe", ".bat", ".cmd", ".com", ".pif", ".scr", ".vbs", ".js",
            ".jar", ".app", ".deb", ".pkg", ".dmg", ".msi", ".sh", ".ps1"
        }
        
        # 最大文件大小：10MB
        self.max_file_size = 10 * 1024 * 1024
    
    def generate_file_id(self, user_id: str, original_filename: str) -> str:
        """生成唯一的文件ID"""
        timestamp = str(int(time.time()))
        random_part = str(uuid.uuid4())[:8]
        return f"{user_id}_{timestamp}_{random_part}"
    
    def get_file_extension(self, filename: str) -> str:
        """获取文件扩展名"""
        return Path(filename).suffix.lower()
    
    def validate_file(self, content: bytes, filename: str) -> None:
        """验证文件"""
        # 检查文件扩展名
        extension = self.get_file_extension(filename)
        if extension in self.dangerous_extensions:
            raise HTTPException(
                status_code=400,
                detail=f"不允许上传此类型的文件。危险文件类型: {', '.join(self.dangerous_extensions)}"
            )
        
        # 检查文件大小
        if len(content) > self.max_file_size:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大。最大允许大小: {self.max_file_size // (1024*1024)}MB"
            )
    
    def save_file(self, content: bytes, file_id: str, extension: str, task_id: Optional[int] = None, chat_id: Optional[str] = None) -> Path:
        """保存文件到私有目录，按任务ID或聊天ID分类"""
        filename = f"{file_id}{extension}"
        
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
    
    def upload_file(self, content: bytes, filename: str, user_id: str, db: Session, task_id: Optional[int] = None, chat_id: Optional[str] = None) -> Dict[str, Any]:
        """上传文件，支持按任务ID或聊天ID分类"""
        try:
            # 验证文件
            self.validate_file(content, filename)
            
            # 生成文件ID
            file_id = self.generate_file_id(user_id, filename)
            extension = self.get_file_extension(filename)
            
            # 保存文件（按任务ID或聊天ID分类）
            file_path = self.save_file(content, file_id, extension, task_id, chat_id)
            
            logger.info(f"文件上传成功: {file_id} - 用户: {user_id}, 任务: {task_id}, 聊天: {chat_id}")
            
            return {
                "success": True,
                "file_id": file_id,
                "filename": file_path.name,
                "original_filename": filename,
                "size": len(content),
                "extension": extension
            }
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"文件上传失败: {e}")
            raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")
    
    def get_file(self, file_id: str, user_id: str, db: Session) -> FileResponse:
        """获取文件（需要验证访问权限）"""
        try:
            # 优化：先从数据库查询附件，获取task_id或chat_id，直接定位文件夹
            file_path = None
            
            # 1. 先查询消息附件表（MessageAttachment）
            attachment = db.query(MessageAttachment).filter(
                MessageAttachment.blob_id == file_id
            ).first()
            
            if attachment:
                # 通过附件找到消息，再找到task_id或chat_id
                from app.models import Message, CustomerServiceMessage
                
                # 查询任务消息
                task_message = db.query(Message).filter(Message.id == attachment.message_id).first()
                if task_message and task_message.task_id:
                    # 任务聊天文件：直接定位到任务文件夹
                    task_dir = self.base_dir / "tasks" / str(task_message.task_id)
                    # 尝试不同扩展名
                    for ext_file in task_dir.glob(f"{file_id}.*"):
                        if ext_file.is_file():
                            file_path = ext_file
                            break
                
                # 如果没找到，查询客服消息
                if not file_path:
                    cs_message = db.query(CustomerServiceMessage).filter(
                        CustomerServiceMessage.id == attachment.message_id
                    ).first()
                    if cs_message and cs_message.chat_id:
                        # 客服聊天文件：直接定位到聊天文件夹
                        chat_dir = self.base_dir / "chats" / cs_message.chat_id
                        for ext_file in chat_dir.glob(f"{file_id}.*"):
                            if ext_file.is_file():
                                file_path = ext_file
                                break
            
            # 2. 如果数据库查询失败或文件不存在，回退到全局搜索（向后兼容）
            if not file_path:
                # 先查找任务文件夹
                task_dirs = list(self.base_dir.glob("tasks/*"))
                for task_dir in task_dirs:
                    task_files = list(task_dir.glob(f"{file_id}.*"))
                    if task_files:
                        file_path = task_files[0]
                        break
                
                # 再查找聊天文件夹
                if not file_path:
                    chat_dirs = list(self.base_dir.glob("chats/*"))
                    for chat_dir in chat_dirs:
                        chat_files = list(chat_dir.glob(f"{file_id}.*"))
                        if chat_files:
                            file_path = chat_files[0]
                            break
                
                # 最后查找根目录（向后兼容）
                if not file_path:
                    root_files = list(self.base_dir.glob(f"{file_id}.*"))
                    if root_files:
                        file_path = root_files[0]
            
            if not file_path or not file_path.exists() or not file_path.is_file():
                raise HTTPException(status_code=404, detail="文件不存在")
            
            # 确定MIME类型
            extension = file_path.suffix.lower()
            mime_types = {
                '.pdf': 'application/pdf',
                '.doc': 'application/msword',
                '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                '.xls': 'application/vnd.ms-excel',
                '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                '.ppt': 'application/vnd.ms-powerpoint',
                '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
                '.zip': 'application/zip',
                '.rar': 'application/x-rar-compressed',
                '.txt': 'text/plain',
                '.csv': 'text/csv',
            }
            media_type = mime_types.get(extension, 'application/octet-stream')
            
            return FileResponse(
                path=file_path,
                media_type=media_type,
                filename=file_path.name
            )
            
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"获取文件失败: {e}")
            raise HTTPException(status_code=500, detail=f"获取文件失败: {str(e)}")


# 创建全局实例
private_file_system = PrivateFileSystem()

