"""
Railway部署配置
用于在线时间获取功能的配置管理
"""

import os
from typing import List, Dict

class RailwayTimeConfig:
    """Railway时间配置类"""
    
    def __init__(self):
        # 从环境变量读取配置，提供默认值
        self.enable_online_time = os.getenv('ENABLE_ONLINE_TIME', 'true').lower() == 'true'
        self.timeout_seconds = int(os.getenv('TIME_API_TIMEOUT', '3'))
        self.max_retries = int(os.getenv('TIME_API_MAX_RETRIES', '3'))
        self.fallback_to_local = os.getenv('FALLBACK_TO_LOCAL_TIME', 'true').lower() == 'true'
        
        # 自定义API列表（可选）
        custom_apis = os.getenv('CUSTOM_TIME_APIS', '')
        if custom_apis:
            self.custom_apis = self._parse_custom_apis(custom_apis)
        else:
            self.custom_apis = []
    
    def _parse_custom_apis(self, apis_str: str) -> List[Dict]:
        """解析自定义API配置"""
        apis = []
        try:
            # 格式: "name1:url1,name2:url2"
            for api_config in apis_str.split(','):
                if ':' in api_config:
                    name, url = api_config.split(':', 1)
                    apis.append({
                        'name': name.strip(),
                        'url': url.strip(),
                        'parser': self._get_default_parser()
                    })
        except Exception as e:
            print(f"解析自定义API配置失败: {e}")
        return apis
    
    def _get_default_parser(self):
        """获取默认的时间解析器"""
        from datetime import datetime
        return lambda data: datetime.fromisoformat(data.get('utc_datetime', data.get('dateTime', data.get('currentDateTime', ''))).replace('Z', '+00:00'))
    
    def get_apis(self) -> List[Dict]:
        """获取API列表，包括自定义API"""
        # 默认API列表
        default_apis = [
            {
                'name': 'WorldTimeAPI',
                'url': 'http://worldtimeapi.org/api/timezone/Europe/London',
                'parser': lambda data: self._parse_worldtimeapi(data)
            },
            {
                'name': 'TimeAPI',
                'url': 'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
                'parser': lambda data: self._parse_timeapi(data)
            },
            {
                'name': 'WorldClockAPI',
                'url': 'http://worldclockapi.com/api/json/utc/now',
                'parser': lambda data: self._parse_worldclockapi(data)
            }
        ]
        
        # 如果有自定义API，优先使用
        if self.custom_apis:
            return self.custom_apis + default_apis
        else:
            return default_apis
    
    def _parse_worldtimeapi(self, data):
        from datetime import datetime
        return datetime.fromisoformat(data['utc_datetime'].replace('Z', '+00:00'))
    
    def _parse_timeapi(self, data):
        from datetime import datetime
        return datetime.fromisoformat(data['dateTime'].replace('Z', '+00:00'))
    
    def _parse_worldclockapi(self, data):
        from datetime import datetime
        return datetime.fromisoformat(data['currentDateTime'].replace('Z', '+00:00'))

# 全局配置实例
railway_config = RailwayTimeConfig()
