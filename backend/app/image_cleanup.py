"""
图片和文件清理工具
用于自动清理不再使用的图片和文件
"""

import os
import logging
from pathlib import Path
from typing import Optional, List
from urllib.parse import urlparse

logger = logging.getLogger(__name__)


def extract_filename_from_url(url: str) -> Optional[str]:
    """从URL中提取文件名"""
    if not url:
        return None
    try:
        parsed = urlparse(url)
        path = parsed.path
        # 提取最后一个路径段作为文件名
        filename = path.split('/')[-1]
        return filename if filename else None
    except Exception as e:
        logger.warning(f"从URL提取文件名失败: {url}, 错误: {e}")
        return None


def delete_expert_avatar(expert_id: str, old_avatar_url: Optional[str] = None):
    """删除任务达人的旧头像"""
    if not old_avatar_url:
        return
    
    try:
        filename = extract_filename_from_url(old_avatar_url)
        if not filename:
            return
        
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            avatar_dir = Path("/data/uploads/public/images/expert_avatars") / expert_id
        else:
            avatar_dir = Path("uploads/public/images/expert_avatars") / expert_id
        
        if avatar_dir.exists():
            avatar_file = avatar_dir / filename
            if avatar_file.exists():
                avatar_file.unlink()
                logger.info(f"删除任务达人 {expert_id} 的旧头像: {filename}")
                
                # 如果文件夹为空，尝试删除它
                try:
                    if not any(avatar_dir.iterdir()):
                        avatar_dir.rmdir()
                        logger.info(f"删除空的头像文件夹: {avatar_dir}")
                except Exception as e:
                    logger.debug(f"删除头像文件夹失败（可能不为空）: {avatar_dir}: {e}")
    except Exception as e:
        logger.warning(f"删除任务达人头像失败 {expert_id}: {e}")


def delete_service_images(expert_id: str, service_id: int, image_urls: Optional[List[str]] = None):
    """删除服务的所有图片"""
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            service_dir = Path("/data/uploads/public/images/service_images") / expert_id
        else:
            service_dir = Path("uploads/public/images/service_images") / expert_id
        
        deleted_count = 0
        
        # 如果提供了图片URL列表，删除指定的图片
        if image_urls:
            for url in image_urls:
                if not url:
                    continue
                filename = extract_filename_from_url(url)
                if filename and service_dir.exists():
                    image_file = service_dir / filename
                    if image_file.exists():
                        image_file.unlink()
                        deleted_count += 1
                        logger.info(f"删除服务 {service_id} 的图片: {filename}")
        
        # 如果文件夹为空，尝试删除它
        try:
            if service_dir.exists() and not any(service_dir.iterdir()):
                service_dir.rmdir()
                logger.info(f"删除空的服务图片文件夹: {service_dir}")
        except Exception as e:
            logger.debug(f"删除服务图片文件夹失败（可能不为空）: {service_dir}: {e}")
        
        if deleted_count > 0:
            logger.info(f"服务 {service_id} 已删除 {deleted_count} 张图片")
    except Exception as e:
        logger.warning(f"删除服务图片失败 {service_id}: {e}")


def delete_task_images(task_id: int, include_private: bool = True):
    """删除任务相关的所有图片（公开和私密）"""
    try:
        deleted_count = 0
        
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        
        # 1. 删除公开图片（任务图片）
        if RAILWAY_ENVIRONMENT:
            public_task_dir = Path("/data/uploads/public/images/public") / str(task_id)
        else:
            public_task_dir = Path("uploads/public/images/public") / str(task_id)
        
        if public_task_dir.exists():
            for image_file in public_task_dir.iterdir():
                if image_file.is_file():
                    try:
                        image_file.unlink()
                        deleted_count += 1
                        logger.info(f"删除任务 {task_id} 的公开图片: {image_file.name}")
                    except Exception as e:
                        logger.warning(f"删除公开图片失败 {image_file}: {e}")
            
            # 如果文件夹为空，删除它
            try:
                if not any(public_task_dir.iterdir()):
                    public_task_dir.rmdir()
                    logger.info(f"删除空的任务公开图片文件夹: {public_task_dir}")
            except Exception as e:
                logger.debug(f"删除任务公开图片文件夹失败: {public_task_dir}: {e}")
        
        # 2. 删除私密图片（任务聊天图片）
        if include_private:
            if RAILWAY_ENVIRONMENT:
                private_task_dir = Path("/data/uploads/private_images/tasks") / str(task_id)
            else:
                private_task_dir = Path("uploads/private_images/tasks") / str(task_id)
            
            if private_task_dir.exists():
                for image_file in private_task_dir.iterdir():
                    if image_file.is_file():
                        try:
                            image_file.unlink()
                            deleted_count += 1
                            logger.info(f"删除任务 {task_id} 的私密图片: {image_file.name}")
                        except Exception as e:
                            logger.warning(f"删除私密图片失败 {image_file}: {e}")
                
                # 如果文件夹为空，删除它
                try:
                    if not any(private_task_dir.iterdir()):
                        private_task_dir.rmdir()
                        logger.info(f"删除空的任务私密图片文件夹: {private_task_dir}")
                except Exception as e:
                    logger.debug(f"删除任务私密图片文件夹失败: {private_task_dir}: {e}")
        
        if deleted_count > 0:
            logger.info(f"任务 {task_id} 已删除 {deleted_count} 张图片")
        
        return deleted_count
    except Exception as e:
        logger.error(f"删除任务图片失败 {task_id}: {e}")
        return 0


def delete_chat_images_and_files(chat_id: str):
    """删除客服聊天的所有图片和文件"""
    try:
        deleted_count = 0
        
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        
        # 删除私密图片（客服聊天图片）
        if RAILWAY_ENVIRONMENT:
            chat_dir = Path("/data/uploads/private_images/chats") / chat_id
        else:
            chat_dir = Path("uploads/private_images/chats") / chat_id
        
        if chat_dir.exists():
            for file_path in chat_dir.iterdir():
                if file_path.is_file():
                    try:
                        file_path.unlink()
                        deleted_count += 1
                        logger.info(f"删除聊天 {chat_id} 的文件: {file_path.name}")
                    except Exception as e:
                        logger.warning(f"删除聊天文件失败 {file_path}: {e}")
            
            # 如果文件夹为空，删除它
            try:
                if not any(chat_dir.iterdir()):
                    chat_dir.rmdir()
                    logger.info(f"删除空的聊天文件夹: {chat_dir}")
            except Exception as e:
                logger.debug(f"删除聊天文件夹失败: {chat_dir}: {e}")
        
        if deleted_count > 0:
            logger.info(f"聊天 {chat_id} 已删除 {deleted_count} 个文件")
        
        return deleted_count
    except Exception as e:
        logger.error(f"删除聊天文件失败 {chat_id}: {e}")
        return 0

