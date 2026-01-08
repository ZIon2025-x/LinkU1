"""
位置工具函数
用于位置信息的模糊显示和验证
"""
from typing import Optional, Tuple


def obfuscate_location(location_text: Optional[str], latitude: Optional[float] = None, longitude: Optional[float] = None) -> str:
    """
    模糊显示位置信息，保护用户隐私
    与前端和 iOS 的实现保持一致
    
    规则：
    - "Online" 保持不变
    - 移除邮编（如 "B16 9NS"）
    - 移除街道地址（以数字开头的部分）
    - 返回最后两个部分（通常是城市和国家）
    
    Args:
        location_text: 位置文本（如 "123 High Street, London, UK"）
        latitude: 纬度（可选，暂未使用）
        longitude: 经度（可选，暂未使用）
    
    Returns:
        模糊的位置文本（如 "London, UK" 或 "Online"）
    """
    import re
    
    # 如果位置文本是 "Online"，直接返回
    if not location_text or location_text.strip() == '':
        return "位置未指定"
    
    trimmed = location_text.strip()
    
    # Online 保持不变
    if trimmed.lower() in ["online", "线上", "线上交易"]:
        return "Online"
    
    # 按逗号分隔
    components = [c.strip() for c in trimmed.split(',')]
    
    # 如果只有一个部分，直接返回
    if len(components) <= 1:
        return trimmed
    
    # 邮编格式检测（英国邮编格式：字母数字混合，如 B16 9NS, SW1A 1AA）
    uk_postcode_pattern = re.compile(r'^[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}$', re.IGNORECASE)
    us_postcode_pattern = re.compile(r'^[0-9]{5}(-[0-9]{4})?$')
    
    def is_postcode(component: str) -> bool:
        return bool(uk_postcode_pattern.match(component) or us_postcode_pattern.match(component))
    
    # 检测是否包含门牌号（以数字开头）
    def has_street_number(component: str) -> bool:
        return bool(re.match(r'^[0-9]+\s', component))
    
    # 过滤掉邮编和街道地址，只保留城市相关的部分
    filtered_components = []
    
    for component in components:
        # 跳过邮编和街道地址
        if not is_postcode(component) and not has_street_number(component):
            filtered_components.append(component)
    
    # 如果第一个部分是街道地址，移除它
    if components and has_street_number(components[0]) and len(components) > 1:
        # 已经在上面过滤掉了
        pass
    
    # 返回最后两个部分（通常是城市和国家，或区域和城市）
    if len(filtered_components) >= 2:
        return ', '.join(filtered_components[-2:])
    elif len(filtered_components) == 1:
        # 只有一个部分，直接返回
        return filtered_components[0]
    
    # 如果过滤后没有内容，尝试从原始组件中获取最后两个非邮编、非街道地址的部分
    valid_components = []
    for component in reversed(components):
        if not is_postcode(component) and not has_street_number(component):
            valid_components.insert(0, component)
            if len(valid_components) >= 2:
                break
    
    if valid_components:
        return ', '.join(valid_components)
    
    # 如果所有部分都被过滤掉了，返回原始内容
    return trimmed


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

