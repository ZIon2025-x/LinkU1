#!/usr/bin/env python3
"""
批量清理数据库中的无效图片URL

功能：
1. 扫描数据库中所有包含图片URL的字段
2. 检查对应的文件是否存在
3. 清理无效的URL（设置为NULL或空字符串）

使用方法：
    python scripts/cleanup_invalid_image_urls.py [--dry-run] [--verbose]
    
参数：
    --dry-run: 只检查不修改（默认）
    --verbose: 显示详细信息
    --fix: 实际执行清理操作
"""

import os
import sys
import json
import argparse
from pathlib import Path
from urllib.parse import urlparse
from typing import List, Dict, Tuple, Optional

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy.orm import Session
from sqlalchemy import text
from app.database import SessionLocal
from app.models import User, Task, TaskExpert, Banner, MessageAttachment
from app.config import Config
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ImageURLCleaner:
    """图片URL清理器"""
    
    def __init__(self, dry_run: bool = True, verbose: bool = False):
        self.dry_run = dry_run
        self.verbose = verbose
        self.stats = {
            'checked': 0,
            'invalid': 0,
            'fixed': 0,
            'errors': 0
        }
        
        # 检测部署环境
        self.railway_env = os.getenv("RAILWAY_ENVIRONMENT")
        if self.railway_env:
            self.base_upload_dir = Path("/data/uploads")
        else:
            self.base_upload_dir = Path("uploads")
        
        # 支持的图片URL前缀
        self.valid_prefixes = [
            "/uploads/images/",
            "/uploads/flea_market/",
            "/uploads/public/",
        ]
        
        # 从配置获取前端URL（用于解析相对路径）
        try:
            from app.config import Config
            self.frontend_url = Config.FRONTEND_URL.rstrip('/')
        except:
            self.frontend_url = "https://www.link2ur.com"
    
    def is_local_image_url(self, url: str) -> bool:
        """检查是否是本地图片URL"""
        if not url or not isinstance(url, str):
            return False
        
        # 检查是否是完整URL
        parsed = urlparse(url)
        if parsed.netloc:
            # 完整URL，检查是否是我们的域名
            return self.frontend_url in url or "link2ur.com" in url or "api.link2ur.com" in url
        
        # 相对路径
        return any(url.startswith(prefix) for prefix in self.valid_prefixes)
    
    def url_to_file_path(self, url: str) -> Optional[Path]:
        """将URL转换为文件路径"""
        if not url:
            return None
        
        try:
            parsed = urlparse(url)
            
            # 如果是完整URL，提取路径部分
            if parsed.netloc:
                path = parsed.path
            else:
                path = url
            
            # 移除开头的 /uploads/
            if path.startswith("/uploads/"):
                path = path[9:]  # 移除 "/uploads/"
            elif path.startswith("uploads/"):
                path = path[8:]  # 移除 "uploads/"
            
            # 构建完整文件路径
            # 根据路径类型选择基础目录
            if path.startswith("flea_market/"):
                file_path = self.base_upload_dir / path
            elif path.startswith("images/"):
                # 新格式：images/{category}/{resource_id}/{filename}
                # 旧格式：images/{filename} (直接根目录)
                file_path = self.base_upload_dir / "public" / path
            elif path.startswith("public/"):
                file_path = self.base_upload_dir / path
            else:
                # 默认在public目录下
                file_path = self.base_upload_dir / "public" / path
            
            return file_path
        except Exception as e:
            if self.verbose:
                logger.error(f"URL转路径失败: {url}, 错误: {e}")
            return None
    
    def check_file_exists(self, file_path: Path) -> bool:
        """检查文件是否存在"""
        try:
            return file_path.exists() and file_path.is_file()
        except Exception as e:
            if self.verbose:
                logger.error(f"检查文件失败: {file_path}, 错误: {e}")
            return False
    
    def check_image_url(self, url: str) -> Tuple[bool, Optional[str]]:
        """检查图片URL是否有效
        
        返回: (是否有效, 错误信息)
        """
        if not url or not isinstance(url, str) or url.strip() == "":
            return True, None  # 空值视为有效（不需要清理）
        
        # 检查是否是本地图片URL
        if not self.is_local_image_url(url):
            return True, None  # 外部URL视为有效（不检查）
        
        # 转换为文件路径
        file_path = self.url_to_file_path(url)
        if not file_path:
            return False, "无法解析URL路径"
        
        # 检查文件是否存在
        if not self.check_file_exists(file_path):
            return False, f"文件不存在: {file_path}"
        
        return True, None
    
    def cleanup_users_avatars(self, db: Session) -> int:
        """清理用户头像"""
        logger.info("开始清理用户头像...")
        fixed_count = 0
        
        users = db.query(User).filter(User.avatar.isnot(None)).filter(User.avatar != "").all()
        logger.info(f"找到 {len(users)} 个有头像的用户")
        
        for user in users:
            self.stats['checked'] += 1
            is_valid, error = self.check_image_url(user.avatar)
            
            if not is_valid:
                self.stats['invalid'] += 1
                if self.verbose:
                    logger.warning(f"用户 {user.id} ({user.name}) 头像无效: {user.avatar}, 错误: {error}")
                
                if not self.dry_run:
                    user.avatar = ""
                    fixed_count += 1
                    self.stats['fixed'] += 1
        
        if not self.dry_run:
            db.commit()
            logger.info(f"已清理 {fixed_count} 个无效用户头像")
        else:
            logger.info(f"发现 {self.stats['invalid']} 个无效用户头像（模拟模式）")
        
        return fixed_count
    
    def cleanup_task_experts_avatars(self, db: Session) -> int:
        """清理任务达人头像"""
        logger.info("开始清理任务达人头像...")
        fixed_count = 0
        
        experts = db.query(TaskExpert).filter(TaskExpert.avatar.isnot(None)).filter(TaskExpert.avatar != "").all()
        logger.info(f"找到 {len(experts)} 个有头像的任务达人")
        
        for expert in experts:
            self.stats['checked'] += 1
            is_valid, error = self.check_image_url(expert.avatar)
            
            if not is_valid:
                self.stats['invalid'] += 1
                if self.verbose:
                    logger.warning(f"任务达人 {expert.id} ({expert.expert_name}) 头像无效: {expert.avatar}, 错误: {error}")
                
                if not self.dry_run:
                    expert.avatar = None
                    fixed_count += 1
                    self.stats['fixed'] += 1
        
        if not self.dry_run:
            db.commit()
            logger.info(f"已清理 {fixed_count} 个无效任务达人头像")
        else:
            logger.info(f"发现 {self.stats['invalid']} 个无效任务达人头像（模拟模式）")
        
        return fixed_count
    
    def cleanup_tasks_images(self, db: Session) -> int:
        """清理任务图片"""
        logger.info("开始清理任务图片...")
        fixed_count = 0
        
        tasks = db.query(Task).filter(Task.images.isnot(None)).filter(Task.images != "").all()
        logger.info(f"找到 {len(tasks)} 个有图片的任务")
        
        for task in tasks:
            try:
                # 解析JSON数组
                if not task.images:
                    continue
                
                images = json.loads(task.images) if isinstance(task.images, str) else task.images
                if not isinstance(images, list):
                    continue
                
                valid_images = []
                has_invalid = False
                
                for img_url in images:
                    self.stats['checked'] += 1
                    is_valid, error = self.check_image_url(img_url)
                    
                    if is_valid:
                        valid_images.append(img_url)
                    else:
                        self.stats['invalid'] += 1
                        has_invalid = True
                        if self.verbose:
                            logger.warning(f"任务 {task.id} 图片无效: {img_url}, 错误: {error}")
                
                if has_invalid and not self.dry_run:
                    # 更新为有效的图片列表
                    if valid_images:
                        task.images = json.dumps(valid_images)
                    else:
                        task.images = None
                    fixed_count += 1
                    self.stats['fixed'] += 1
                    
            except json.JSONDecodeError as e:
                self.stats['errors'] += 1
                if self.verbose:
                    logger.error(f"任务 {task.id} 图片JSON解析失败: {e}")
            except Exception as e:
                self.stats['errors'] += 1
                if self.verbose:
                    logger.error(f"处理任务 {task.id} 时出错: {e}")
        
        if not self.dry_run:
            db.commit()
            logger.info(f"已清理 {fixed_count} 个任务的无效图片")
        else:
            logger.info(f"发现 {self.stats['invalid']} 个无效任务图片（模拟模式）")
        
        return fixed_count
    
    def cleanup_banners_images(self, db: Session) -> int:
        """清理Banner图片"""
        logger.info("开始清理Banner图片...")
        fixed_count = 0
        
        banners = db.query(Banner).filter(Banner.image_url.isnot(None)).filter(Banner.image_url != "").all()
        logger.info(f"找到 {len(banners)} 个Banner")
        
        for banner in banners:
            self.stats['checked'] += 1
            is_valid, error = self.check_image_url(banner.image_url)
            
            if not is_valid:
                self.stats['invalid'] += 1
                if self.verbose:
                    logger.warning(f"Banner {banner.id} 图片无效: {banner.image_url}, 错误: {error}")
                
                if not self.dry_run:
                    # Banner图片是必填的，设置为空字符串并禁用
                    banner.image_url = ""
                    banner.is_active = False
                    fixed_count += 1
                    self.stats['fixed'] += 1
        
        if not self.dry_run:
            db.commit()
            logger.info(f"已清理 {fixed_count} 个无效Banner图片")
        else:
            logger.info(f"发现 {self.stats['invalid']} 个无效Banner图片（模拟模式）")
        
        return fixed_count
    
    def cleanup_message_attachments(self, db: Session) -> int:
        """清理消息附件URL"""
        logger.info("开始清理消息附件...")
        fixed_count = 0
        
        attachments = db.query(MessageAttachment).filter(
            MessageAttachment.attachment_type == "image"
        ).filter(MessageAttachment.url.isnot(None)).filter(MessageAttachment.url != "").all()
        logger.info(f"找到 {len(attachments)} 个图片附件")
        
        for attachment in attachments:
            self.stats['checked'] += 1
            is_valid, error = self.check_image_url(attachment.url)
            
            if not is_valid:
                self.stats['invalid'] += 1
                if self.verbose:
                    logger.warning(f"消息附件 {attachment.id} 图片无效: {attachment.url}, 错误: {error}")
                
                if not self.dry_run:
                    # 消息附件URL可以为空（如果有blob_id）
                    attachment.url = None
                    fixed_count += 1
                    self.stats['fixed'] += 1
        
        if not self.dry_run:
            db.commit()
            logger.info(f"已清理 {fixed_count} 个无效消息附件")
        else:
            logger.info(f"发现 {self.stats['invalid']} 个无效消息附件（模拟模式）")
        
        return fixed_count
    
    def run(self):
        """执行清理"""
        logger.info("=" * 60)
        logger.info("开始批量清理无效图片URL")
        logger.info(f"模式: {'模拟运行（不修改数据）' if self.dry_run else '实际执行（将修改数据）'}")
        logger.info("=" * 60)
        
        db = SessionLocal()
        try:
            # 清理各个表的图片URL
            self.cleanup_users_avatars(db)
            self.cleanup_task_experts_avatars(db)
            self.cleanup_tasks_images(db)
            self.cleanup_banners_images(db)
            self.cleanup_message_attachments(db)
            
            # 打印统计信息
            logger.info("=" * 60)
            logger.info("清理完成！统计信息：")
            logger.info(f"  检查的URL数量: {self.stats['checked']}")
            logger.info(f"  无效的URL数量: {self.stats['invalid']}")
            logger.info(f"  修复的记录数: {self.stats['fixed']}")
            logger.info(f"  错误数量: {self.stats['errors']}")
            logger.info("=" * 60)
            
        except Exception as e:
            logger.error(f"清理过程中出错: {e}", exc_info=True)
            if not self.dry_run:
                db.rollback()
        finally:
            db.close()


def main():
    parser = argparse.ArgumentParser(description="批量清理数据库中的无效图片URL")
    parser.add_argument("--dry-run", action="store_true", default=True, help="只检查不修改（默认）")
    parser.add_argument("--fix", action="store_true", help="实际执行清理操作（需要明确指定）")
    parser.add_argument("--verbose", "-v", action="store_true", help="显示详细信息")
    
    args = parser.parse_args()
    
    # 如果指定了--fix，则不是dry-run
    dry_run = not args.fix
    
    if not dry_run:
        # 确认操作
        response = input("⚠️  警告：这将修改数据库！确定要继续吗？(yes/no): ")
        if response.lower() != "yes":
            logger.info("操作已取消")
            return
    
    cleaner = ImageURLCleaner(dry_run=dry_run, verbose=args.verbose)
    cleaner.run()


if __name__ == "__main__":
    main()

