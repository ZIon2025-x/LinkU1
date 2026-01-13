"""
翻译服务监控告警模块
监控翻译服务健康状态，及时发送告警
"""
import logging
import time
from typing import Dict, List, Optional
from datetime import datetime, timedelta
from collections import defaultdict

logger = logging.getLogger(__name__)

# 告警阈值配置
ALERT_THRESHOLDS = {
    'failure_rate': 0.5,  # 失败率超过50%触发告警
    'response_time': 5.0,  # 响应时间超过5秒触发告警
    'consecutive_failures': 5,  # 连续失败5次触发告警
    'service_unavailable_duration': 300,  # 服务不可用超过5分钟触发告警
}

# 告警记录（内存中，可以定期清理）
_alerts = []
_alert_history = defaultdict(list)


class TranslationAlert:
    """翻译服务告警"""
    
    def __init__(
        self,
        alert_type: str,
        service_name: str,
        message: str,
        severity: str = 'warning',
        metadata: Optional[Dict] = None
    ):
        self.alert_type = alert_type
        self.service_name = service_name
        self.message = message
        self.severity = severity  # 'info', 'warning', 'error', 'critical'
        self.metadata = metadata or {}
        self.timestamp = datetime.utcnow()
    
    def to_dict(self) -> Dict:
        """转换为字典格式"""
        return {
            'alert_type': self.alert_type,
            'service_name': self.service_name,
            'message': self.message,
            'severity': self.severity,
            'metadata': self.metadata,
            'timestamp': self.timestamp.isoformat()
        }


def check_service_health(
    service_name: str,
    stats: Dict,
    recent_errors: List[Exception]
) -> List[TranslationAlert]:
    """
    检查服务健康状态并生成告警
    
    参数:
    - service_name: 服务名称
    - stats: 服务统计信息 {'success': int, 'failure': int, 'avg_time': float}
    - recent_errors: 最近的错误列表
    
    返回:
    - 告警列表
    """
    alerts = []
    
    # 计算失败率
    total_requests = stats.get('success', 0) + stats.get('failure', 0)
    if total_requests > 0:
        failure_rate = stats.get('failure', 0) / total_requests
        
        # 检查失败率
        if failure_rate >= ALERT_THRESHOLDS['failure_rate']:
            alerts.append(TranslationAlert(
                alert_type='high_failure_rate',
                service_name=service_name,
                message=f"翻译服务 {service_name} 失败率过高: {failure_rate:.2%}",
                severity='error' if failure_rate >= 0.8 else 'warning',
                metadata={
                    'failure_rate': failure_rate,
                    'total_requests': total_requests,
                    'failures': stats.get('failure', 0)
                }
            ))
    
    # 检查响应时间
    avg_time = stats.get('avg_time', 0)
    if avg_time > ALERT_THRESHOLDS['response_time']:
        alerts.append(TranslationAlert(
            alert_type='slow_response',
            service_name=service_name,
            message=f"翻译服务 {service_name} 响应时间过长: {avg_time:.2f}秒",
            severity='warning',
            metadata={'avg_time': avg_time}
        ))
    
    # 检查连续失败
    if len(recent_errors) >= ALERT_THRESHOLDS['consecutive_failures']:
        alerts.append(TranslationAlert(
            alert_type='consecutive_failures',
            service_name=service_name,
            message=f"翻译服务 {service_name} 连续失败 {len(recent_errors)} 次",
            severity='error',
            metadata={'consecutive_failures': len(recent_errors)}
        ))
    
    return alerts


def record_alert(alert: TranslationAlert):
    """记录告警"""
    _alerts.append(alert)
    _alert_history[alert.service_name].append(alert)
    
    # 只保留最近1000条告警
    if len(_alerts) > 1000:
        _alerts.pop(0)
    
    # 每个服务只保留最近100条告警
    if len(_alert_history[alert.service_name]) > 100:
        _alert_history[alert.service_name].pop(0)
    
    # 根据严重程度记录日志
    if alert.severity == 'critical':
        logger.critical(f"[翻译告警] {alert.message}")
    elif alert.severity == 'error':
        logger.error(f"[翻译告警] {alert.message}")
    elif alert.severity == 'warning':
        logger.warning(f"[翻译告警] {alert.message}")
    else:
        logger.info(f"[翻译告警] {alert.message}")


def get_recent_alerts(
    service_name: Optional[str] = None,
    severity: Optional[str] = None,
    limit: int = 50
) -> List[Dict]:
    """
    获取最近的告警
    
    参数:
    - service_name: 服务名称（可选）
    - severity: 严重程度（可选）
    - limit: 返回数量限制
    
    返回:
    - 告警列表
    """
    alerts = _alerts.copy()
    
    # 过滤
    if service_name:
        alerts = [a for a in alerts if a.service_name == service_name]
    if severity:
        alerts = [a for a in alerts if a.severity == severity]
    
    # 按时间倒序排序
    alerts.sort(key=lambda x: x.timestamp, reverse=True)
    
    # 限制数量
    return [a.to_dict() for a in alerts[:limit]]


def get_alert_stats() -> Dict:
    """获取告警统计信息"""
    stats = {
        'total_alerts': len(_alerts),
        'by_severity': defaultdict(int),
        'by_service': defaultdict(int),
        'by_type': defaultdict(int),
        'recent_critical': 0
    }
    
    # 统计最近24小时的告警
    cutoff_time = datetime.utcnow() - timedelta(hours=24)
    
    for alert in _alerts:
        if alert.timestamp >= cutoff_time:
            stats['by_severity'][alert.severity] += 1
            stats['by_service'][alert.service_name] += 1
            stats['by_type'][alert.alert_type] += 1
            if alert.severity == 'critical':
                stats['recent_critical'] += 1
    
    return stats


def clear_old_alerts(days: int = 7):
    """清理旧告警（保留最近N天）"""
    cutoff_time = datetime.utcnow() - timedelta(days=days)
    
    global _alerts
    _alerts = [a for a in _alerts if a.timestamp >= cutoff_time]
    
    # 清理历史记录
    for service_name in list(_alert_history.keys()):
        _alert_history[service_name] = [
            a for a in _alert_history[service_name]
            if a.timestamp >= cutoff_time
        ]
        if not _alert_history[service_name]:
            del _alert_history[service_name]
    
    logger.info(f"清理了 {days} 天前的告警记录")
