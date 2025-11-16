#!/usr/bin/env python3
"""
图片文件夹结构迁移工具
将现有图片从旧结构迁移到新的分类结构

旧结构：
- uploads/images/ (所有图片混在一起)
- uploads/private_images/ (所有私密图片混在一起)

新结构：
- uploads/public/images/expert_avatars/{expert_id}/
- uploads/public/images/service_images/{expert_id}/
- uploads/public/images/public/{task_id}/
- uploads/private_images/tasks/{task_id}/
- uploads/private_images/chats/{chat_id}/
"""

import os
import sys
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urlparse

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from app.config import Config
from app.models import TaskExpert, TaskExpertService, Task, Message, CustomerServiceChat

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class ImageStructureMigrator:
    def __init__(self, dry_run: bool = False):
        self.dry_run = dry_run
        self.engine = create_engine(Config.DATABASE_URL)
        self.Session = sessionmaker(bind=self.engine)
        
        # 检测部署环境
        self.RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        
        if self.RAILWAY_ENVIRONMENT:
            self.base_public_dir = Path("/data/uploads/public/images")
            self.base_private_dir = Path("/data/uploads/private_images")
            self.old_images_dir = Path("/data/uploads/images")  # 可能的旧路径
        else:
            self.base_public_dir = Path("uploads/public/images")
            self.base_private_dir = Path("uploads/private_images")
            self.old_images_dir = Path("uploads/images")  # 可能的旧路径
        
        # 统计信息
        self.stats = {
            'expert_avatars_migrated': 0,
            'service_images_migrated': 0,
            'task_images_migrated': 0,
            'private_task_images_migrated': 0,
            'private_chat_images_migrated': 0,
            'errors': 0,
            'skipped': 0
        }
    
    def extract_filename_from_url(self, url: str) -> Optional[str]:
        """从URL中提取文件名"""
        if not url:
            return None
        try:
            parsed = urlparse(url)
            path = parsed.path
            filename = path.split('/')[-1]
            return filename if filename else None
        except Exception as e:
            logger.warning(f"从URL提取文件名失败: {url}, 错误: {e}")
            return None
    
    def find_image_file(self, filename: str, search_dirs: List[Path]) -> Optional[Path]:
        """在多个目录中查找图片文件"""
        for search_dir in search_dirs:
            if not search_dir.exists():
                continue
            
            # 在根目录查找
            file_path = search_dir / filename
            if file_path.exists() and file_path.is_file():
                return file_path
            
            # 递归查找子目录
            for file_path in search_dir.rglob(filename):
                if file_path.is_file():
                    return file_path
        
        return None
    
    def migrate_expert_avatars(self, session):
        """迁移任务达人头像"""
        logger.info("开始迁移任务达人头像...")
        
        experts = session.query(TaskExpert).filter(TaskExpert.avatar.isnot(None)).all()
        
        for expert in experts:
            if not expert.avatar:
                continue
            
            try:
                filename = self.extract_filename_from_url(expert.avatar)
                if not filename:
                    self.stats['skipped'] += 1
                    continue
                
                # 目标目录
                target_dir = self.base_public_dir / "expert_avatars" / expert.id
                target_dir.mkdir(parents=True, exist_ok=True)
                target_path = target_dir / filename
                
                # 如果目标文件已存在，跳过
                if target_path.exists():
                    logger.debug(f"头像已在新位置: {expert.id}/{filename}")
                    self.stats['skipped'] += 1
                    continue
                
                # 查找源文件
                search_dirs = [
                    self.old_images_dir,
                    self.base_public_dir,
                    self.base_public_dir / "expert_avatars",
                ]
                
                source_path = self.find_image_file(filename, search_dirs)
                
                if source_path and source_path != target_path:
                    if not self.dry_run:
                        # 移动文件
                        import shutil
                        from app.config import Config
                        shutil.move(str(source_path), str(target_path))
                        
                        # 更新数据库中的URL
                        base_url = Config.FRONTEND_URL.rstrip('/')
                        new_url = f"{base_url}/uploads/images/expert_avatars/{expert.id}/{filename}"
                        expert.avatar = new_url
                        session.commit()
                        
                        logger.info(f"迁移头像: {expert.id}/{filename} (已更新数据库URL)")
                    else:
                        logger.info(f"[DRY RUN] 将迁移头像: {expert.id}/{filename} ({source_path} -> {target_path})")
                    self.stats['expert_avatars_migrated'] += 1
                else:
                    logger.debug(f"未找到头像文件: {filename} (专家ID: {expert.id})")
                    self.stats['skipped'] += 1
                    
            except Exception as e:
                logger.error(f"迁移头像失败 {expert.id}: {e}")
                self.stats['errors'] += 1
    
    def migrate_service_images(self, session):
        """迁移服务图片"""
        logger.info("开始迁移服务图片...")
        
        services = session.query(TaskExpertService).filter(
            TaskExpertService.images.isnot(None)
        ).all()
        
        for service in services:
            if not service.images:
                continue
            
            try:
                # 解析图片URL列表
                if isinstance(service.images, str):
                    image_urls = json.loads(service.images)
                elif isinstance(service.images, list):
                    image_urls = service.images
                else:
                    continue
                
                if not image_urls:
                    continue
                
                # 目标目录
                target_dir = self.base_public_dir / "service_images" / service.expert_id
                target_dir.mkdir(parents=True, exist_ok=True)
                
                for url in image_urls:
                    if not url:
                        continue
                    
                    filename = self.extract_filename_from_url(url)
                    if not filename:
                        continue
                    
                    target_path = target_dir / filename
                    
                    # 如果目标文件已存在，跳过
                    if target_path.exists():
                        continue
                    
                    # 查找源文件
                    search_dirs = [
                        self.old_images_dir,
                        self.base_public_dir,
                        self.base_public_dir / "service_images",
                    ]
                    
                    source_path = self.find_image_file(filename, search_dirs)
                    
                    if source_path and source_path != target_path:
                        if not self.dry_run:
                            import shutil
                            from app.config import Config
                            shutil.move(str(source_path), str(target_path))
                            
                            # 更新数据库中的URL（如果URL列表中有这个URL）
                            base_url = Config.FRONTEND_URL.rstrip('/')
                            new_url = f"{base_url}/uploads/images/service_images/{service.expert_id}/{filename}"
                            
                            # 更新URL列表
                            updated_urls = []
                            url_updated = False
                            for old_url in image_urls:
                                if old_url == url:
                                    updated_urls.append(new_url)
                                    url_updated = True
                                else:
                                    updated_urls.append(old_url)
                            
                            if url_updated:
                                if isinstance(service.images, str):
                                    service.images = json.dumps(updated_urls)
                                else:
                                    service.images = updated_urls
                                session.commit()
                            
                            logger.info(f"迁移服务图片: {service.expert_id}/{service.id}/{filename} (已更新数据库URL)")
                        else:
                            logger.info(f"[DRY RUN] 将迁移服务图片: {service.expert_id}/{service.id}/{filename}")
                        self.stats['service_images_migrated'] += 1
                    
            except Exception as e:
                logger.error(f"迁移服务图片失败 {service.id}: {e}")
                self.stats['errors'] += 1
    
    def migrate_task_images(self, session):
        """迁移任务图片"""
        logger.info("开始迁移任务图片...")
        
        tasks = session.query(Task).filter(Task.images.isnot(None)).all()
        
        for task in tasks:
            if not task.images:
                continue
            
            try:
                # 解析图片URL列表
                if isinstance(task.images, str):
                    image_urls = json.loads(task.images)
                elif isinstance(task.images, list):
                    image_urls = task.images
                else:
                    continue
                
                if not image_urls:
                    continue
                
                # 目标目录
                target_dir = self.base_public_dir / "public" / str(task.id)
                target_dir.mkdir(parents=True, exist_ok=True)
                
                for url in image_urls:
                    if not url:
                        continue
                    
                    filename = self.extract_filename_from_url(url)
                    if not filename:
                        continue
                    
                    target_path = target_dir / filename
                    
                    # 如果目标文件已存在，跳过
                    if target_path.exists():
                        continue
                    
                    # 查找源文件
                    search_dirs = [
                        self.old_images_dir,
                        self.base_public_dir,
                        self.base_public_dir / "public",
                    ]
                    
                    source_path = self.find_image_file(filename, search_dirs)
                    
                    if source_path and source_path != target_path:
                        if not self.dry_run:
                            import shutil
                            from app.config import Config
                            shutil.move(str(source_path), str(target_path))
                            
                            # 更新数据库中的URL（如果URL列表中有这个URL）
                            base_url = Config.FRONTEND_URL.rstrip('/')
                            new_url = f"{base_url}/uploads/images/public/{task.id}/{filename}"
                            
                            # 更新URL列表
                            updated_urls = []
                            url_updated = False
                            for old_url in image_urls:
                                if old_url == url:
                                    updated_urls.append(new_url)
                                    url_updated = True
                                else:
                                    updated_urls.append(old_url)
                            
                            if url_updated:
                                if isinstance(task.images, str):
                                    task.images = json.dumps(updated_urls)
                                else:
                                    task.images = updated_urls
                                session.commit()
                            
                            logger.info(f"迁移任务图片: {task.id}/{filename} (已更新数据库URL)")
                        else:
                            logger.info(f"[DRY RUN] 将迁移任务图片: {task.id}/{filename}")
                        self.stats['task_images_migrated'] += 1
                    
            except Exception as e:
                logger.error(f"迁移任务图片失败 {task.id}: {e}")
                self.stats['errors'] += 1
    
    def migrate_private_task_images(self, session):
        """迁移任务聊天私密图片"""
        logger.info("开始迁移任务聊天私密图片...")
        
        # 获取所有有图片消息的任务
        messages = session.execute(text("""
            SELECT DISTINCT task_id, image_id
            FROM messages
            WHERE task_id IS NOT NULL AND image_id IS NOT NULL
        """)).fetchall()
        
        task_image_map: Dict[int, List[str]] = {}
        for task_id, image_id in messages:
            if task_id not in task_image_map:
                task_image_map[task_id] = []
            task_image_map[task_id].append(image_id)
        
        for task_id, image_ids in task_image_map.items():
            try:
                # 目标目录
                target_dir = self.base_private_dir / "tasks" / str(task_id)
                target_dir.mkdir(parents=True, exist_ok=True)
                
                for image_id in image_ids:
                    # 目标文件路径（尝试不同扩展名）
                    target_path = None
                    target_ext = None
                    
                    # 先检查目标文件是否已存在（可能已经在正确位置）
                    for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                        potential_target = target_dir / f"{image_id}{ext}"
                        if potential_target.exists() and potential_target.is_file():
                            # 文件已在正确位置，跳过
                            self.stats['skipped'] += 1
                            target_path = None
                            break
                    
                    if target_path is None:
                        # 文件不在目标位置，需要查找并移动
                        # 查找源文件（可能有不同扩展名）
                        search_dirs = [
                            self.base_private_dir,  # 根目录
                            self.base_private_dir / "tasks",  # 可能在旧的任务文件夹
                            Path("uploads/private/images") if not self.RAILWAY_ENVIRONMENT else Path("/data/uploads/private/images"),
                        ]
                        
                        source_path = None
                        for search_dir in search_dirs:
                            if not search_dir.exists():
                                continue
                            
                            # 如果在 tasks 目录，递归搜索所有子文件夹
                            if search_dir.name == "tasks":
                                for subdir in search_dir.iterdir():
                                    if subdir.is_dir():
                                        for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                                            potential_file = subdir / f"{image_id}{ext}"
                                            if potential_file.exists() and potential_file.is_file():
                                                source_path = potential_file
                                                break
                                        if source_path:
                                            break
                            else:
                                # 在根目录或旧目录中查找
                                for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                                    potential_file = search_dir / f"{image_id}{ext}"
                                    if potential_file.exists() and potential_file.is_file():
                                        source_path = potential_file
                                        break
                            
                            if source_path:
                                break
                        
                        if source_path:
                            # 确定目标文件扩展名
                            target_ext = source_path.suffix
                            target_path = target_dir / f"{image_id}{target_ext}"
                            
                            # 确保源文件不在目标位置（避免移动到自己）
                            if source_path != target_path:
                                if not self.dry_run:
                                    import shutil
                                    shutil.move(str(source_path), str(target_path))
                                    logger.info(f"迁移任务私密图片: {task_id}/{image_id}{target_ext}")
                                else:
                                    logger.info(f"[DRY RUN] 将迁移任务私密图片: {task_id}/{image_id}{target_ext} ({source_path} -> {target_path})")
                                self.stats['private_task_images_migrated'] += 1
                            else:
                                # 文件已在正确位置
                                self.stats['skipped'] += 1
                    
            except Exception as e:
                logger.error(f"迁移任务私密图片失败 {task_id}: {e}")
                self.stats['errors'] += 1
    
    def migrate_private_chat_images(self, session):
        """迁移客服聊天私密图片"""
        logger.info("开始迁移客服聊天私密图片...")
        
        # 获取所有有图片消息的客服聊天
        messages = session.execute(text("""
            SELECT DISTINCT chat_id, image_id
            FROM customer_service_messages
            WHERE chat_id IS NOT NULL AND image_id IS NOT NULL
        """)).fetchall()
        
        chat_image_map: Dict[str, List[str]] = {}
        for chat_id, image_id in messages:
            if chat_id not in chat_image_map:
                chat_image_map[chat_id] = []
            chat_image_map[chat_id].append(image_id)
        
        for chat_id, image_ids in chat_image_map.items():
            try:
                # 目标目录
                target_dir = self.base_private_dir / "chats" / chat_id
                target_dir.mkdir(parents=True, exist_ok=True)
                
                for image_id in image_ids:
                    # 目标文件路径（尝试不同扩展名）
                    target_path = None
                    target_ext = None
                    
                    # 先检查目标文件是否已存在（可能已经在正确位置）
                    for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                        potential_target = target_dir / f"{image_id}{ext}"
                        if potential_target.exists() and potential_target.is_file():
                            # 文件已在正确位置，跳过
                            self.stats['skipped'] += 1
                            target_path = None
                            break
                    
                    if target_path is None:
                        # 文件不在目标位置，需要查找并移动
                        # 查找源文件（可能有不同扩展名）
                        search_dirs = [
                            self.base_private_dir,  # 根目录
                            self.base_private_dir / "chats",  # 可能在旧的聊天文件夹
                            Path("uploads/private/images") if not self.RAILWAY_ENVIRONMENT else Path("/data/uploads/private/images"),
                        ]
                        
                        source_path = None
                        for search_dir in search_dirs:
                            if not search_dir.exists():
                                continue
                            
                            # 如果在 chats 目录，递归搜索所有子文件夹
                            if search_dir.name == "chats":
                                for subdir in search_dir.iterdir():
                                    if subdir.is_dir():
                                        for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                                            potential_file = subdir / f"{image_id}{ext}"
                                            if potential_file.exists() and potential_file.is_file():
                                                source_path = potential_file
                                                break
                                        if source_path:
                                            break
                            else:
                                # 在根目录或旧目录中查找
                                for ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
                                    potential_file = search_dir / f"{image_id}{ext}"
                                    if potential_file.exists() and potential_file.is_file():
                                        source_path = potential_file
                                        break
                            
                            if source_path:
                                break
                        
                        if source_path:
                            # 确定目标文件扩展名
                            target_ext = source_path.suffix
                            target_path = target_dir / f"{image_id}{target_ext}"
                            
                            # 确保源文件不在目标位置（避免移动到自己）
                            if source_path != target_path:
                                if not self.dry_run:
                                    import shutil
                                    shutil.move(str(source_path), str(target_path))
                                    logger.info(f"迁移客服聊天图片: {chat_id}/{image_id}{target_ext}")
                                else:
                                    logger.info(f"[DRY RUN] 将迁移客服聊天图片: {chat_id}/{image_id}{target_ext} ({source_path} -> {target_path})")
                                self.stats['private_chat_images_migrated'] += 1
                            else:
                                # 文件已在正确位置
                                self.stats['skipped'] += 1
                    
            except Exception as e:
                logger.error(f"迁移客服聊天图片失败 {chat_id}: {e}")
                self.stats['errors'] += 1
    
    def migrate_all(self):
        """执行所有迁移"""
        logger.info("=" * 60)
        logger.info("开始图片文件夹结构迁移")
        logger.info(f"模式: {'试运行 (DRY RUN)' if self.dry_run else '实际迁移'}")
        logger.info("=" * 60)
        
        with self.Session() as session:
            # 迁移任务达人头像
            self.migrate_expert_avatars(session)
            
            # 迁移服务图片
            self.migrate_service_images(session)
            
            # 迁移任务图片
            self.migrate_task_images(session)
            
            # 迁移任务聊天私密图片
            self.migrate_private_task_images(session)
            
            # 迁移客服聊天私密图片
            self.migrate_private_chat_images(session)
        
        # 打印统计信息
        logger.info("=" * 60)
        logger.info("迁移统计:")
        logger.info(f"  任务达人头像: {self.stats['expert_avatars_migrated']} 个")
        logger.info(f"  服务图片: {self.stats['service_images_migrated']} 个")
        logger.info(f"  任务图片: {self.stats['task_images_migrated']} 个")
        logger.info(f"  任务私密图片: {self.stats['private_task_images_migrated']} 个")
        logger.info(f"  客服聊天图片: {self.stats['private_chat_images_migrated']} 个")
        logger.info(f"  跳过: {self.stats['skipped']} 个")
        logger.info(f"  错误: {self.stats['errors']} 个")
        logger.info("=" * 60)


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='图片文件夹结构迁移工具')
    parser.add_argument('--dry-run', action='store_true', help='试运行，不实际移动文件')
    parser.add_argument('--verbose', '-v', action='store_true', help='详细输出')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        migrator = ImageStructureMigrator(dry_run=args.dry_run)
        migrator.migrate_all()
        
        if not args.dry_run:
            logger.info("图片结构迁移完成！")
        else:
            logger.info("试运行完成，使用不带 --dry-run 参数执行实际迁移")
            
    except Exception as e:
        logger.error(f"迁移失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()

