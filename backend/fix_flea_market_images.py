"""
修复跳蚤市场商品图片URL脚本
- 检查所有商品的图片URL
- 如果URL指向错误的路径（/uploads/images/public/temp_...），修复为正确路径
- 移动文件到正确位置（如果文件还在临时目录）
- 更新数据库中的URL
"""

import os
import sys
import json
import shutil
import logging
from pathlib import Path
from urllib.parse import urlparse

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.database import SessionLocal
from app import models
from app.config import Config

logger = logging.getLogger(__name__)

def fix_flea_market_images():
    """修复所有跳蚤市场商品的图片URL"""
    
    # 检测部署环境
    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
    if RAILWAY_ENVIRONMENT:
        base_uploads_dir = Path("/data/uploads")
        flea_market_dir = Path("/data/uploads/flea_market")
        public_temp_dir = Path("/data/uploads/images/public")
    else:
        base_uploads_dir = Path("uploads")
        flea_market_dir = Path("uploads/flea_market")
        public_temp_dir = Path("uploads/images/public")
    
    db = SessionLocal()
    try:
        # 获取所有有图片的商品
        items = db.query(models.FleaMarketItem).filter(
            models.FleaMarketItem.images.isnot(None)
        ).all()
        
        print(f"找到 {len(items)} 个有图片的商品")
        
        fixed_count = 0
        moved_count = 0
        error_count = 0
        
        for item in items:
            try:
                # 解析图片URL列表
                images = []
                if item.images:
                    try:
                        images = json.loads(item.images) if isinstance(item.images, str) else item.images
                    except:
                        images = []
                
                if not images:
                    continue
                
                updated_images = []
                needs_update = False
                
                for image_url in images:
                    # 检查是否是错误的路径（/uploads/images/public/temp_...）
                    if "/uploads/images/public/temp_" in image_url:
                        print(f"\n商品 {item.id} ({item.title}): 发现错误路径的图片")
                        print(f"  原URL: {image_url}")
                        
                        # 从URL中提取文件名
                        filename = image_url.split('/')[-1]
                        
                        # 查找文件可能的位置
                        # 1. 检查临时目录
                        temp_user_id = None
                        for part in image_url.split('/'):
                            if part.startswith('temp_'):
                                temp_user_id = part.replace('temp_', '')
                                break
                        
                        source_file = None
                        if temp_user_id:
                            # 检查临时目录
                            temp_file_path = public_temp_dir / f"temp_{temp_user_id}" / filename
                            if temp_file_path.exists():
                                source_file = temp_file_path
                                print(f"  找到文件在临时目录: {temp_file_path}")
                        
                        # 2. 如果临时目录没有，检查是否已经在正确位置
                        target_dir = flea_market_dir / str(item.id)
                        target_file = target_dir / filename
                        
                        if target_file.exists():
                            # 文件已经在正确位置，只需更新URL
                            print(f"  文件已在正确位置: {target_file}")
                            new_url = f"{Config.FRONTEND_URL.rstrip('/')}/uploads/flea_market/{item.id}/{filename}"
                            updated_images.append(new_url)
                            needs_update = True
                            print(f"  新URL: {new_url}")
                        elif source_file and source_file.exists():
                            # 需要移动文件
                            target_dir.mkdir(parents=True, exist_ok=True)
                            shutil.move(str(source_file), str(target_file))
                            new_url = f"{Config.FRONTEND_URL.rstrip('/')}/uploads/flea_market/{item.id}/{filename}"
                            updated_images.append(new_url)
                            needs_update = True
                            moved_count += 1
                            print(f"  已移动文件到: {target_file}")
                            print(f"  新URL: {new_url}")
                        else:
                            # 文件不存在，保持原URL但记录警告
                            print(f"  ⚠️  警告: 文件不存在，保持原URL")
                            updated_images.append(image_url)
                    elif "/uploads/flea_market/temp_" in image_url:
                        # 检查是否是跳蚤市场临时目录的图片
                        print(f"\n商品 {item.id} ({item.title}): 发现跳蚤市场临时目录的图片")
                        print(f"  原URL: {image_url}")
                        
                        # 从URL中提取文件名
                        filename = image_url.split('/')[-1]
                        
                        # 提取用户ID
                        temp_user_id = None
                        for part in image_url.split('/'):
                            if part.startswith('temp_'):
                                temp_user_id = part.replace('temp_', '')
                                break
                        
                        # 检查临时文件
                        temp_file_path = flea_market_dir / f"temp_{temp_user_id}" / filename
                        target_dir = flea_market_dir / str(item.id)
                        target_file = target_dir / filename
                        
                        if target_file.exists():
                            # 文件已经在正确位置
                            print(f"  文件已在正确位置: {target_file}")
                            new_url = f"{Config.FRONTEND_URL.rstrip('/')}/uploads/flea_market/{item.id}/{filename}"
                            updated_images.append(new_url)
                            needs_update = True
                            print(f"  新URL: {new_url}")
                        elif temp_file_path.exists():
                            # 需要移动文件
                            target_dir.mkdir(parents=True, exist_ok=True)
                            shutil.move(str(temp_file_path), str(target_file))
                            new_url = f"{Config.FRONTEND_URL.rstrip('/')}/uploads/flea_market/{item.id}/{filename}"
                            updated_images.append(new_url)
                            needs_update = True
                            moved_count += 1
                            print(f"  已移动文件到: {target_file}")
                            print(f"  新URL: {new_url}")
                        else:
                            # 文件不存在
                            print(f"  ⚠️  警告: 文件不存在，保持原URL")
                            updated_images.append(image_url)
                    else:
                        # 已经是正确路径，保持不变
                        updated_images.append(image_url)
                
                # 如果有更新，保存到数据库
                if needs_update:
                    item.images = json.dumps(updated_images)
                    db.commit()
                    fixed_count += 1
                    print(f"  ✅ 已更新商品 {item.id} 的图片URL")
                
            except Exception as e:
                error_count += 1
                print(f"\n❌ 处理商品 {item.id} 时出错: {e}")
                import traceback
                traceback.print_exc()
        
        print(f"\n{'='*60}")
        print(f"修复完成:")
        print(f"  - 修复商品数: {fixed_count}")
        print(f"  - 移动文件数: {moved_count}")
        print(f"  - 错误数: {error_count}")
        print(f"{'='*60}")
        
    finally:
        db.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("开始修复跳蚤市场商品图片URL...")
    fix_flea_market_images()
    print("修复完成！")

