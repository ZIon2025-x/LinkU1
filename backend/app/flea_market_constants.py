"""
跳蚤市场常量定义
"""

# 商品分类列表（与前端保持一致）
FLEA_MARKET_CATEGORIES = [
    'Electronics',           # 电子产品
    'Clothing',             # 服装鞋帽
    'Books',                # 书籍
    'Furniture',            # 家具
    'Sports',               # 运动用品
    'Accessories',          # 配饰
    'Home & Living',        # 生活用品
    'Beauty & Personal',    # 美妆个护
    'Toys & Games',         # 玩具游戏
    'Other'                 # 其他
]

# 商品状态
ITEM_STATUS_ACTIVE = 'active'
ITEM_STATUS_SOLD = 'sold'
ITEM_STATUS_DELETED = 'deleted'

# 购买申请状态
PURCHASE_REQUEST_STATUS_PENDING = 'pending'
PURCHASE_REQUEST_STATUS_ACCEPTED = 'accepted'
PURCHASE_REQUEST_STATUS_REJECTED = 'rejected'

# 自动删除配置
AUTO_DELETE_DAYS = 10  # 超过10天未刷新自动删除

# 图片配置
MAX_IMAGES_PER_ITEM = 5  # 每个商品最多5张图片
MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB

