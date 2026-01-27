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


class WebhookVerboseLogFilter(logging.Filter):
    """
    Webhook详细日志过滤器
    将详细的webhook调试日志降级为DEBUG级别，减少生产环境日志量
    
    保留的关键日志（INFO级别）：
    - Webhook接收和处理完成
    - 支付成功/失败的关键操作
    - 错误和警告
    
    降级为DEBUG的日志：
    - 详细的字段检查
    - 中间步骤的确认信息
    - 重复的状态信息
    """
    
    # 需要降级为DEBUG的详细日志模式
    VERBOSE_PATTERNS = [
        # 详细的字段检查日志
        (r'✅ 返回响应数据字段检查', logging.DEBUG),
        (r'  - (message|application_id|task_id|payment_intent_id|client_secret|amount|currency|amount_display).*类型', logging.DEBUG),
        (r'✅ PaymentIntent client_secret (存在|长度)', logging.DEBUG),
        (r'✅ 创建 PaymentIntent:.*currency', logging.DEBUG),
        
        # 详细的webhook事件信息
        (r'📦 \[WEBHOOK\] 事件详情:', logging.DEBUG),
        (r'  - (时间|客户端IP|User-Agent|Content-Type|Payload 大小|Signature 前缀|Secret 配置|事件类型|事件ID|Livemode|创建时间)', logging.DEBUG),
        (r'💳 \[WEBHOOK\] Payment Intent 详情:', logging.DEBUG),
        (r'  - (Payment Intent ID|状态|金额|Metadata|Task ID|Application ID|Pending Approval)', logging.DEBUG),
        
        # 中间步骤的确认信息
        (r'✅ \[WEBHOOK\] 已创建事件记录', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 事件验证成功', logging.DEBUG),
        (r'🔍 Webhook检查:', logging.DEBUG),
        (r'🔍 查找申请:', logging.DEBUG),
        (r'🔍 找到申请:', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 已添加操作日志', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 更新任务成交价', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 自动拒绝其他申请', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 已发送(简单)?接受申请通知', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 已(创建|更新)支付历史记录', logging.DEBUG),
        (r'📝 \[WEBHOOK\] 提交前任务状态:', logging.DEBUG),
        (r'  - (is_paid|status|payment_intent_id|escrow_amount|taker_id).*更新前', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 数据库提交成功', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 已清除.*缓存', logging.DEBUG),
        (r'✅ \[WEBHOOK\] 任务.*支付完成.*提交后验证', logging.DEBUG),
        (r'  - (任务状态|是否已支付|Payment Intent ID|Escrow 金额|Taker ID)', logging.DEBUG),
        (r'⏱️ \[WEBHOOK\] 处理耗时', logging.DEBUG),
        
        # PaymentIntent创建时的详细日志
        (r'✅ 批准申请成功:', logging.DEBUG),
    ]
    
    # 保留为INFO的关键日志模式（不降级）
    IMPORTANT_PATTERNS = [
        r'🔔 \[WEBHOOK\] 收到 Stripe Webhook 请求',
        r'✅ \[WEBHOOK\] Webhook 处理完成',
        r'✅ \[WEBHOOK\] 支付成功，申请.*已批准',
        r'✅ \[WEBHOOK\] 开始批准申请',
        r'✅ \[WEBHOOK\] 申请已批准，任务状态设置为',
        r'❌ \[WEBHOOK\]',
        r'⚠️ \[WEBHOOK\]',
        r'Payment intent (succeeded|failed|created)',
        r'Charge (succeeded|failed)',
    ]
    
    def filter(self, record: logging.LogRecord) -> bool:
        """过滤并降级详细的webhook日志"""
        if record.levelno != logging.INFO:
            # 只处理INFO级别的日志
            return True
        
        msg = record.getMessage()
        
        # 检查是否是重要的日志（保留为INFO）
        for pattern in self.IMPORTANT_PATTERNS:
            if re.search(pattern, msg, re.IGNORECASE):
                return True
        
        # 检查是否需要降级为DEBUG
        for pattern, target_level in self.VERBOSE_PATTERNS:
            if re.search(pattern, msg, re.IGNORECASE):
                # 降级日志级别
                record.levelno = target_level
                record.levelname = logging.getLevelName(target_level)
                # 在生产环境中，DEBUG日志通常不会输出，所以这里返回False来完全过滤
                # 如果需要保留DEBUG日志，可以改为return True
                return True  # 保留但降级为DEBUG
        
        return True


def setup_webhook_verbose_log_filter():
    """设置webhook详细日志过滤器"""
    filter_instance = WebhookVerboseLogFilter()
    
    # 获取app.routers日志记录器（webhook处理的主要模块）
    routers_logger = logging.getLogger('app.routers')
    routers_logger.addFilter(filter_instance)
    
    # 也应用到task_chat_routes（支付创建相关）
    task_chat_logger = logging.getLogger('app.task_chat_routes')
    task_chat_logger.addFilter(filter_instance)
    
    return filter_instance

