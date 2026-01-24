#!/usr/bin/env python3
"""
检查图片存储配置

功能：
1. 检查当前使用的存储后端类型
2. 检查 public_url 配置
3. 检查 FRONTEND_URL 配置
4. 提供配置建议

使用方法：
    python scripts/check_storage_config.py
"""

import os
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.storage_backend import get_storage_backend
from app.config import Config

def check_storage_config():
    """检查存储配置"""
    print("=" * 60)
    print("图片存储配置检查")
    print("=" * 60)
    print()
    
    # 1. 检查存储后端类型
    storage_backend_type = os.getenv('STORAGE_BACKEND', 'local').lower()
    print(f"1. 存储后端类型: {storage_backend_type.upper()}")
    if storage_backend_type == 'local':
        print("   ✅ 使用本地存储（默认）")
    elif storage_backend_type == 's3':
        print("   ⚠️  使用 AWS S3 存储")
    elif storage_backend_type == 'r2':
        print("   ⚠️  使用 Cloudflare R2 存储")
    else:
        print(f"   ❌ 未知的存储后端类型: {storage_backend_type}")
    print()
    
    # 2. 检查 FRONTEND_URL
    frontend_url = Config.FRONTEND_URL
    print(f"2. FRONTEND_URL: {frontend_url}")
    if frontend_url:
        print("   ✅ FRONTEND_URL 已配置")
    else:
        print("   ❌ FRONTEND_URL 未配置")
    print()
    
    # 3. 检查存储后端实例
    try:
        storage = get_storage_backend()
        storage_type = type(storage).__name__
        print(f"3. 存储后端实例: {storage_type}")
        
        # 检查 base_url 或 public_url
        if hasattr(storage, 'base_url'):
            base_url = storage.base_url
            print(f"   base_url: {base_url}")
            if base_url:
                print("   ✅ base_url 已配置")
            else:
                print("   ❌ base_url 未配置")
        
        if hasattr(storage, 'public_url'):
            public_url = storage.public_url
            print(f"   public_url: {public_url}")
            if public_url:
                print("   ✅ public_url 已配置（URL 永久有效）")
            else:
                print("   ⚠️  public_url 未配置（将生成预签名 URL，1 小时后过期）")
                print("   ⚠️  建议配置 S3_PUBLIC_URL 或 R2_PUBLIC_URL 环境变量")
        
    except Exception as e:
        print(f"   ❌ 获取存储后端失败: {e}")
    print()
    
    # 4. 检查 S3 配置
    if storage_backend_type == 's3':
        print("4. S3 配置检查:")
        s3_bucket = os.getenv('S3_BUCKET_NAME')
        s3_public_url = os.getenv('S3_PUBLIC_URL')
        aws_key = os.getenv('AWS_ACCESS_KEY_ID')
        aws_secret = os.getenv('AWS_SECRET_ACCESS_KEY')
        
        print(f"   S3_BUCKET_NAME: {s3_bucket or '❌ 未配置'}")
        print(f"   S3_PUBLIC_URL: {s3_public_url or '❌ 未配置（重要！）'}")
        print(f"   AWS_ACCESS_KEY_ID: {'✅ 已配置' if aws_key else '❌ 未配置'}")
        print(f"   AWS_SECRET_ACCESS_KEY: {'✅ 已配置' if aws_secret else '❌ 未配置'}")
        
        if not s3_public_url:
            print()
            print("   ⚠️  警告：未配置 S3_PUBLIC_URL")
            print("   ⚠️  这将导致图片 URL 在 1 小时后失效")
            print("   ⚠️  建议配置：S3_PUBLIC_URL=https://your-bucket-name.s3.amazonaws.com")
    print()
    
    # 5. 检查 R2 配置
    if storage_backend_type == 'r2':
        print("5. R2 配置检查:")
        r2_bucket = os.getenv('R2_BUCKET_NAME')
        r2_public_url = os.getenv('R2_PUBLIC_URL')
        r2_endpoint = os.getenv('R2_ENDPOINT_URL')
        r2_key = os.getenv('R2_ACCESS_KEY_ID')
        r2_secret = os.getenv('R2_SECRET_ACCESS_KEY')
        
        print(f"   R2_BUCKET_NAME: {r2_bucket or '❌ 未配置'}")
        print(f"   R2_PUBLIC_URL: {r2_public_url or '❌ 未配置（重要！）'}")
        print(f"   R2_ENDPOINT_URL: {r2_endpoint or '❌ 未配置'}")
        print(f"   R2_ACCESS_KEY_ID: {'✅ 已配置' if r2_key else '❌ 未配置'}")
        print(f"   R2_SECRET_ACCESS_KEY: {'✅ 已配置' if r2_secret else '❌ 未配置'}")
        
        if not r2_public_url:
            print()
            print("   ⚠️  警告：未配置 R2_PUBLIC_URL")
            print("   ⚠️  这将导致图片 URL 在 1 小时后失效")
            print("   ⚠️  建议配置：R2_PUBLIC_URL=https://pub-xxxxx.r2.dev/your-bucket-name")
    print()
    
    # 6. 配置建议
    print("=" * 60)
    print("配置建议")
    print("=" * 60)
    
    if storage_backend_type == 'local':
        print("✅ 当前使用本地存储，URL 永久有效")
        print()
        print("确保以下配置正确：")
        print(f"   FRONTEND_URL={frontend_url}")
        print()
        print("确保前端可以访问 /uploads/ 路径：")
        print("   - 如果使用 Vercel，需要在 vercel.json 中配置代理")
        print("   - 或者后端直接提供静态文件服务")
    elif storage_backend_type in ('s3', 'r2'):
        if not (hasattr(storage, 'public_url') and storage.public_url):
            print("❌ 未配置 public_url，图片 URL 将在 1 小时后失效")
            print()
            print("请配置以下环境变量：")
            if storage_backend_type == 's3':
                print("   S3_PUBLIC_URL=https://your-bucket-name.s3.amazonaws.com")
                print("   或使用 CloudFront CDN：")
                print("   S3_PUBLIC_URL=https://your-cloudfront-domain.cloudfront.net")
            else:
                print("   R2_PUBLIC_URL=https://pub-xxxxx.r2.dev/your-bucket-name")
            print()
            print("详细配置说明请查看：backend/STORAGE_URL_CONFIG.md")
        else:
            print("✅ public_url 已配置，URL 永久有效")
    
    print()
    print("=" * 60)

if __name__ == "__main__":
    check_storage_config()
