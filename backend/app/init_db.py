import sys
from urllib.parse import urlparse
from sqlalchemy import text

from app.database import sync_engine, DATABASE_URL
from app.models import Base, Message, Notification, Review, Task, TaskHistory, User


def mask_password(url: str) -> str:
    """隐藏URL中的密码"""
    try:
        parsed = urlparse(url)
        if parsed.password:
            return url.replace(parsed.password, "***")
        return url
    except Exception:
        return url


def init_db():
    """初始化数据库表"""
    print("=" * 50)
    print("开始初始化数据库...")
    print("=" * 50)
    
    # 显示数据库连接信息（隐藏密码）
    masked_url = mask_password(DATABASE_URL)
    print(f"数据库URL: {masked_url}")
    
    try:
        # 测试数据库连接
        print("\n1. 测试数据库连接...")
        with sync_engine.connect() as conn:
            result = conn.execute(text("SELECT 1"))
            result.fetchone()
        print("   ✓ 数据库连接成功")
        
        # 创建表
        print("\n2. 创建数据库表...")
        Base.metadata.create_all(bind=sync_engine)
        print("   ✓ 数据库表创建完成！")
        
        # 验证表是否创建
        print("\n3. 验证表创建...")
        from sqlalchemy import inspect
        inspector = inspect(sync_engine)
        tables = inspector.get_table_names()
        print(f"   已创建的表: {', '.join(tables) if tables else '(无)'}")
        
        print("\n" + "=" * 50)
        print("数据库初始化完成！")
        print("=" * 50)
        
    except Exception as e:
        print("\n" + "=" * 50)
        print("❌ 数据库初始化失败！")
        print("=" * 50)
        print(f"错误类型: {type(e).__name__}")
        print(f"错误信息: {str(e)}")
        print("\n详细错误信息:")
        import traceback
        traceback.print_exc()
        print("\n" + "=" * 50)
        print("可能的解决方案:")
        print("1. 检查数据库服务是否正在运行")
        print("2. 检查 DATABASE_URL 环境变量是否正确")
        print("3. 检查数据库用户名和密码是否正确")
        print("4. 检查数据库 'linku_db' 是否存在")
        print("5. 检查防火墙设置是否允许连接")
        print("=" * 50)
        sys.exit(1)


if __name__ == "__main__":
    init_db()
