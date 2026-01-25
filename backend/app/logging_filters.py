"""
日志过滤器
用于过滤敏感信息，防止密码、token等敏感数据泄露到日志中
"""
import re
import logging


class SensitiveDataFilter(logging.Filter):
    """敏感信息日志过滤器"""
    
    # 敏感字段模式
    SENSITIVE_PATTERNS = [
        # 密码相关
        (r'password["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'password=***'),
        (r'pwd["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'pwd=***'),
        (r'passwd["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'passwd=***'),
        
        # Token相关
        (r'token["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'token=***'),
        (r'access_token["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'access_token=***'),
        (r'refresh_token["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'refresh_token=***'),
        (r'session_id["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'session_id=***'),
        
        # API密钥相关
        (r'api_key["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'api_key=***'),
        (r'apikey["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'apikey=***'),
        (r'secret["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'secret=***'),
        (r'secret_key["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'secret_key=***'),
        
        # 授权相关
        (r'authorization["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'authorization=***'),
        (r'auth["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'auth=***'),
        
        # 信用卡相关（如果涉及支付）
        (r'card_number["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'card_number=***'),
        (r'cvv["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'cvv=***'),
        # Stripe 与客户端敏感字段
        (r'client_secret["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'client_secret=***'),
        (r'ephemeral_key_secret["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'ephemeral_key_secret=***'),
        (r'device_token["\']?\s*[:=]\s*["\']?([^"\'\s]+)', 'device_token=***'),
    ]
    
    def filter(self, record: logging.LogRecord) -> bool:
        """过滤日志记录中的敏感信息"""
        if hasattr(record, 'msg'):
            msg = str(record.msg)
            original_msg = msg
            
            # 应用所有敏感信息模式
            for pattern, replacement in self.SENSITIVE_PATTERNS:
                msg = re.sub(pattern, replacement, msg, flags=re.IGNORECASE)
            
            # 如果消息被修改，更新记录
            if msg != original_msg:
                record.msg = msg
                # 如果有args，也需要处理
                if hasattr(record, 'args') and record.args:
                    new_args = []
                    for arg in record.args:
                        if isinstance(arg, str):
                            arg_str = str(arg)
                            for pattern, replacement in self.SENSITIVE_PATTERNS:
                                arg_str = re.sub(pattern, replacement, arg_str, flags=re.IGNORECASE)
                            new_args.append(arg_str)
                        else:
                            new_args.append(arg)
                    record.args = tuple(new_args)
        
        return True


def setup_sensitive_data_filter():
    """设置敏感信息过滤器到所有日志处理器"""
    filter_instance = SensitiveDataFilter()
    
    # 获取根日志记录器
    root_logger = logging.getLogger()
    
    # 为所有处理器添加过滤器
    for handler in root_logger.handlers:
        handler.addFilter(filter_instance)
    
    # 也为当前模块的日志记录器添加
    logger = logging.getLogger(__name__)
    logger.addFilter(filter_instance)
    
    return filter_instance

