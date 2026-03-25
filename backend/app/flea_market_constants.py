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

# Listing types
LISTING_TYPE_SALE = 'sale'
LISTING_TYPE_RENTAL = 'rental'
LISTING_TYPES = [LISTING_TYPE_SALE, LISTING_TYPE_RENTAL]

# Rental request statuses
RENTAL_REQUEST_PENDING = 'pending'
RENTAL_REQUEST_APPROVED = 'approved'
RENTAL_REQUEST_REJECTED = 'rejected'
RENTAL_REQUEST_COUNTER_OFFER = 'counter_offer'
RENTAL_REQUEST_EXPIRED = 'expired'

# Rental statuses
RENTAL_STATUS_ACTIVE = 'active'
RENTAL_STATUS_PENDING_RETURN = 'pending_return'
RENTAL_STATUS_RETURNED = 'returned'
RENTAL_STATUS_OVERDUE = 'overdue'
RENTAL_STATUS_DISPUTED = 'disputed'

# Deposit statuses
DEPOSIT_HELD = 'held'
DEPOSIT_REFUNDED = 'refunded'
DEPOSIT_FORFEITED = 'forfeited'

# Rental unit types
RENTAL_UNIT_DAY = 'day'
RENTAL_UNIT_WEEK = 'week'
RENTAL_UNIT_MONTH = 'month'
RENTAL_UNITS = [RENTAL_UNIT_DAY, RENTAL_UNIT_WEEK, RENTAL_UNIT_MONTH]

# Rental constraints
RENTAL_PAYMENT_TIMEOUT_HOURS = 24

# 自动删除配置
AUTO_DELETE_DAYS = 10  # 超过10天未刷新自动删除

# 图片配置
MAX_IMAGES_PER_ITEM = 5  # 每个商品最多5张图片
MAX_IMAGE_SIZE = 5 * 1024 * 1024  # 5MB

