"""
位置工具函数
用于位置信息的模糊显示和验证
"""
from typing import Optional, Tuple


def obfuscate_location(location_text: Optional[str], latitude: Optional[float] = None, longitude: Optional[float] = None) -> str:
    """
    模糊显示位置信息，保护用户隐私
    
    策略：
    1. 如果 location_text 存在，优先使用（已经是模糊的文本）
    2. 如果有坐标但没有文本，可以根据坐标反向地理编码到城市级别
    3. 对于 "Online"，直接返回
    
    Args:
        location_text: 位置文本（如 "London", "Online"）
        latitude: 纬度（可选）
        longitude: 经度（可选）
    
    Returns:
        模糊的位置文本（如 "London, UK" 或 "Online"）
    """
    # 如果位置文本是 "Online"，直接返回
    if location_text and location_text.lower() in ["online", "线上", "线上交易"]:
        return "Online"
    
    # 如果有位置文本，直接使用（假设已经是模糊的）
    if location_text:
        return location_text
    
    # 如果有坐标但没有文本，可以在这里进行反向地理编码
    # 但为了性能，建议在创建时就从坐标生成文本
    # 这里返回一个默认值
    if latitude is not None and longitude is not None:
        # 可以根据坐标判断大致区域（英国主要城市）
        # 这里简化处理，实际可以使用地理编码服务
        return "UK"  # 默认返回国家级别
    
    return "位置未指定"


def validate_coordinates(latitude: Optional[float], longitude: Optional[float]) -> Tuple[bool, Optional[str]]:
    """
    验证坐标是否有效
    
    Args:
        latitude: 纬度
        longitude: 经度
    
    Returns:
        (是否有效, 错误信息)
    """
    # 如果两个都为空，是有效的（允许只有文本位置）
    if latitude is None and longitude is None:
        return True, None
    
    # 如果只有一个为空，无效
    if (latitude is None) != (longitude is None):
        return False, "纬度和经度必须同时提供或同时为空"
    
    # 验证纬度范围
    if latitude < -90 or latitude > 90:
        return False, f"纬度必须在 -90 到 90 之间，当前值: {latitude}"
    
    # 验证经度范围
    if longitude < -180 or longitude > 180:
        return False, f"经度必须在 -180 到 180 之间，当前值: {longitude}"
    
    return True, None


def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    计算两个坐标点之间的距离（使用 Haversine 公式）
    返回距离（单位：公里）
    
    Args:
        lat1, lon1: 第一个点的纬度和经度
        lat2, lon2: 第二个点的纬度和经度
    
    Returns:
        距离（公里）
    """
    import math
    
    # 地球半径（公里）
    R = 6371.0
    
    # 转换为弧度
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # 计算差值
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    # Haversine 公式
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    distance = R * c
    
    return distance

