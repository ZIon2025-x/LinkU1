#!/usr/bin/env python3
"""
图片消息迁移工具
将数据库中存储的base64图片迁移到文件系统存储
"""

import os
import sys
import base64
import uuid
from pathlib import Path
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import logging

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.config import Config
from app.models import Base, Message, CustomerServiceMessage

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ImageMigrator:
    def __init__(self):
        self.engine = create_engine(Config.DATABASE_URL)
        self.Session = sessionmaker(bind=self.engine)
        
        # 创建上传目录
        self.upload_dir = Path("uploads/images")
        self.upload_dir.mkdir(parents=True, exist_ok=True)
        
        # 统计信息
        self.stats = {
            'total_messages': 0,
            'image_messages': 0,
            'base64_images': 0,
            'url_images': 0,
            'migrated': 0,
            'errors': 0
        }
    
    def is_image_message(self, content: str) -> bool:
        """检查是否是图片消息"""
        return content.startswith('[图片] ')
    
    def is_base64_image(self, content: str) -> bool:
        """检查是否是base64图片（已禁用base64存储）"""
        return False  # 不再支持base64存储
    
    def extract_image_data(self, content: str) -> tuple:
        """提取图片数据，返回 (is_base64, image_data, file_extension)"""
        if not self.is_image_message(content):
            return False, None, None
        
        image_data = content.replace('[图片] ', '')
        # 不再支持base64，所有图片都应该是URL
        return False, image_data, None
    
    def save_image_file(self, image_data: str, file_extension: str) -> str:
        """保存图片文件，返回文件名"""
        try:
            # 解码base64数据
            image_bytes = base64.b64decode(image_data)
            
            # 生成唯一文件名
            file_id = str(uuid.uuid4())
            filename = f"{file_id}{file_extension}"
            file_path = self.upload_dir / filename
            
            # 保存文件
            with open(file_path, 'wb') as f:
                f.write(image_bytes)
            
            logger.info(f"图片文件保存成功: {filename}")
            return filename
            
        except Exception as e:
            logger.error(f"保存图片文件失败: {e}")
            raise
    
    def migrate_message(self, message: Message) -> bool:
        """迁移单个消息（已禁用base64，只检查文件存储状态）"""
        try:
            if not self.is_image_message(str(message.content)):
                return True
            
            image_data = str(message.content).replace('[图片] ', '')
            
            # 检查是否已经是文件存储
            if image_data.startswith('http') or image_data.startswith('/uploads/'):
                # 已经是文件存储，不需要迁移
                self.stats['url_images'] += 1
                return True
            else:
                # 如果是base64数据，记录为需要迁移但无法处理
                logger.warning(f"消息 {message.id} 包含base64数据，但base64存储已禁用，请手动处理")
                self.stats['errors'] += 1
                return False
            
        except Exception as e:
            logger.error(f"检查消息 {message.id} 失败: {e}")
            self.stats['errors'] += 1
            return False
    
    def migrate_customer_service_message(self, message: CustomerServiceMessage) -> bool:
        """迁移客服消息（已禁用base64，只检查文件存储状态）"""
        try:
            if not self.is_image_message(str(message.content)):
                return True
            
            image_data = str(message.content).replace('[图片] ', '')
            
            # 检查是否已经是文件存储
            if image_data.startswith('http') or image_data.startswith('/uploads/'):
                # 已经是文件存储，不需要迁移
                self.stats['url_images'] += 1
                return True
            else:
                # 如果是base64数据，记录为需要迁移但无法处理
                logger.warning(f"客服消息 {message.id} 包含base64数据，但base64存储已禁用，请手动处理")
                self.stats['errors'] += 1
                return False
            
        except Exception as e:
            logger.error(f"检查客服消息 {message.id} 失败: {e}")
            self.stats['errors'] += 1
            return False
    
    def migrate_all_images(self, dry_run: bool = False):
        """迁移所有图片消息"""
        logger.info("开始图片迁移...")
        
        with self.Session() as session:
            # 迁移普通消息
            logger.info("迁移普通消息...")
            messages = session.query(Message).all()
            self.stats['total_messages'] += len(messages)
            
            for message in messages:
                if self.is_image_message(str(message.content)):
                    self.stats['image_messages'] += 1
                    # 检查图片存储状态
                    image_data = str(message.content).replace('[图片] ', '')
                    if image_data.startswith('data:image/'):
                        self.stats['base64_images'] += 1
                        logger.warning(f"发现base64图片消息 {message.id}，但base64存储已禁用")
                    else:
                        self.stats['url_images'] += 1
                    
                    if not dry_run:
                        self.migrate_message(message)
                    else:
                        logger.info(f"[DRY RUN] 将检查消息 {message.id}")
            
            # 检查客服消息
            logger.info("检查客服消息...")
            cs_messages = session.query(CustomerServiceMessage).all()
            self.stats['total_messages'] += len(cs_messages)
            
            for message in cs_messages:
                if self.is_image_message(str(message.content)):
                    self.stats['image_messages'] += 1
                    # 检查图片存储状态
                    image_data = str(message.content).replace('[图片] ', '')
                    if image_data.startswith('data:image/'):
                        self.stats['base64_images'] += 1
                        logger.warning(f"发现base64客服消息 {message.id}，但base64存储已禁用")
                    else:
                        self.stats['url_images'] += 1
                    
                    if not dry_run:
                        self.migrate_customer_service_message(message)
                    else:
                        logger.info(f"[DRY RUN] 将检查客服消息 {message.id}")
        
        # 打印统计信息
        self.print_stats(dry_run)
    
    def print_stats(self, dry_run: bool = False):
        """打印迁移统计信息"""
        logger.info("=" * 50)
        logger.info("图片存储状态检查")
        logger.info("=" * 50)
        logger.info(f"总消息数: {self.stats['total_messages']}")
        logger.info(f"图片消息数: {self.stats['image_messages']}")
        logger.info(f"文件存储图片数: {self.stats['url_images']}")
        logger.info(f"base64图片数: {self.stats['base64_images']} (已禁用)")
        
        if self.stats['base64_images'] > 0:
            logger.warning(f"⚠️  发现 {self.stats['base64_images']} 个base64图片，但base64存储已禁用")
            logger.warning("建议手动处理这些图片或删除相关消息")
        
        if dry_run:
            logger.info(f"[DRY RUN] 检查完成")
        else:
            logger.info(f"检查完成，错误数: {self.stats['errors']} 个")
        
        logger.info("=" * 50)

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='图片消息迁移工具')
    parser.add_argument('--dry-run', action='store_true', help='试运行，不实际修改数据')
    parser.add_argument('--verbose', '-v', action='store_true', help='详细输出')
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        migrator = ImageMigrator()
        migrator.migrate_all_images(dry_run=args.dry_run)
        
        if not args.dry_run:
            logger.info("图片迁移完成！")
        else:
            logger.info("试运行完成，使用 --dry-run=false 执行实际迁移")
            
    except Exception as e:
        logger.error(f"迁移失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
