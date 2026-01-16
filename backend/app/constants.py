"""
WebSocket关闭码协议契约
所有关闭码和reason必须使用此文件中的常量，禁止硬编码
修改关闭码/reason需要前后端同步更新
"""

# 预定义的英国主要城市列表（用于位置筛选）
# 当筛选 "Other" 时，会排除这些城市
UK_MAIN_CITIES = [
    "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", 
    "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", 
    "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", 
    "Leicester", "York", "Aberdeen", "Bath", "Dundee", 
    "Reading", "St Andrews", "Belfast", "Brighton", "Durham", 
    "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", 
    "Cambridge", "Oxford"
]

# 中英文城市名映射表（用于地址筛选时支持中英文互查）
CITY_NAME_MAPPING = {
    # 英文 -> 中文
    "London": "伦敦",
    "Edinburgh": "爱丁堡",
    "Manchester": "曼彻斯特",
    "Birmingham": "伯明翰",
    "Glasgow": "格拉斯哥",
    "Bristol": "布里斯托",
    "Sheffield": "谢菲尔德",
    "Leeds": "利兹",
    "Nottingham": "诺丁汉",
    "Newcastle": "纽卡斯尔",
    "Southampton": "南安普顿",
    "Liverpool": "利物浦",
    "Cardiff": "卡迪夫",
    "Coventry": "考文垂",
    "Exeter": "埃克塞特",
    "Leicester": "莱斯特",
    "York": "约克",
    "Aberdeen": "阿伯丁",
    "Bath": "巴斯",
    "Dundee": "邓迪",
    "Reading": "雷丁",
    "St Andrews": "圣安德鲁斯",
    "Belfast": "贝尔法斯特",
    "Brighton": "布莱顿",
    "Durham": "达勒姆",
    "Norwich": "诺里奇",
    "Swansea": "斯旺西",
    "Loughborough": "拉夫堡",
    "Lancaster": "兰开斯特",
    "Warwick": "华威",
    "Cambridge": "剑桥",
    "Oxford": "牛津",
}

# 反向映射：中文 -> 英文
CITY_NAME_REVERSE_MAPPING = {v: k for k, v in CITY_NAME_MAPPING.items()}

def get_city_name_variants(city_name: str) -> list:
    """
    获取城市名的所有变体（英文和中文）
    例如：输入 "Birmingham" 返回 ["Birmingham", "伯明翰"]
         输入 "伯明翰" 返回 ["Birmingham", "伯明翰"]
    """
    variants = [city_name]  # 包含原始名称
    
    # 如果输入是英文，添加中文
    if city_name in CITY_NAME_MAPPING:
        variants.append(CITY_NAME_MAPPING[city_name])
    
    # 如果输入是中文，添加英文
    if city_name in CITY_NAME_REVERSE_MAPPING:
        variants.append(CITY_NAME_REVERSE_MAPPING[city_name])
    
    return list(set(variants))  # 去重

# WebSocket关闭码协议契约
WS_CLOSE_CODE_NORMAL = 1000  # 正常关闭（仅用于"新连接替换"场景）
WS_CLOSE_CODE_HEARTBEAT_TIMEOUT = 4001  # 心跳超时（应用自定义，需要重连）
WS_CLOSE_CODE_AUTH_FAILED = 1008  # 认证失败（协议错误）

# 关闭原因（固定文案，禁止修改）
WS_CLOSE_REASON_NEW_CONNECTION = "New connection established"  # 新连接替换，前端不重连
WS_CLOSE_REASON_HEARTBEAT_TIMEOUT = "Heartbeat timeout"  # 心跳超时，前端需要重连
WS_CLOSE_REASON_AUTH_FAILED = "Authentication failed"  # 认证失败统一文案
WS_CLOSE_REASON_TOKEN_EXPIRED = "Token expired"  # Token过期，可恢复
WS_CLOSE_REASON_TOKEN_INVALID = "Token invalid"  # Token无效，不可恢复

