"""
通知变量提取工具
从通知的 content 文本中提取动态变量，用于前端使用翻译键格式化
"""
import re
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


def extract_notification_variables(
    notification_type: str,
    content: str,
    content_en: Optional[str] = None
) -> Dict[str, Any]:
    """
    从通知的 content 文本中提取动态变量
    
    Args:
        notification_type: 通知类型
        content: 中文内容
        content_en: 英文内容（可选，用于提取变量）
    
    Returns:
        包含动态变量的字典
    """
    variables: Dict[str, Any] = {}
    
    try:
        if notification_type == "task_application":
            # 格式: "{applicant_name} 申请了任务「{task_title}」\n申请留言：{application_message}\n议价金额：{price_info}"
            # 或: "{applicant_name} applied for task「{task_title}」\nApplication message: {application_message}\nNegotiated price: {price_info}"
            match = re.search(r'(.+?)\s+(?:申请了任务|applied for task)「(.+?)」', content)
            if match:
                variables["applicant_name"] = match.group(1).strip()
                variables["task_title"] = match.group(2).strip()
            
            # 提取申请留言
            message_match = re.search(r'(?:申请留言|Application message)[：:]\s*(.+?)(?:\n|$)', content, re.MULTILINE)
            if message_match:
                variables["application_message"] = message_match.group(1).strip()
            
            # 提取议价金额
            price_match = re.search(r'(?:议价金额|Negotiated price)[：:]\s*(.+?)(?:\n|$)', content, re.MULTILINE)
            if price_match:
                variables["price_info"] = price_match.group(1).strip()
        
        elif notification_type == "application_accepted":
            # 格式: "申请者已接受您对任务「{task_title}」的议价，请完成支付。{payment_expires_info}"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
            
            # 提取支付过期信息
            expires_match = re.search(r'(请完成支付[。.]?\s*(.+?))?$', content)
            if expires_match and expires_match.group(2):
                variables["payment_expires_info"] = expires_match.group(2).strip()
        
        elif notification_type == "application_rejected":
            # 格式: "您的任务申请已被拒绝：{task_title}"
            match = re.search(r'[：:]\s*(.+?)$', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "application_withdrawn":
            # 格式: "有申请者撤回了对任务「{task_title}」的申请"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "task_completed":
            # 格式: "{taker_name} 已将任务「{task_title}」标记为完成"
            match = re.search(r'(.+?)\s+(?:已将任务|has marked task)「(.+?)」', content)
            if match:
                variables["taker_name"] = match.group(1).strip()
                variables["task_title"] = match.group(2).strip()
        
        elif notification_type == "task_confirmed":
            # 格式: "任务已完成并确认！「{task_title}」的奖励已发放"
            match = re.search(r'「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type in ["task_cancelled", "task_auto_cancelled"]:
            # 格式: "您的任务「{task_title}」已被取消" 或 "您的任务「{task_title}」因超过截止日期已自动取消"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "application_message":
            # 格式: "任务「{task_title}」的发布者给您留言：{message}"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
            
            message_match = re.search(r'[：:]\s*(.+?)$', content)
            if message_match:
                variables["message"] = message_match.group(1).strip()
        
        elif notification_type == "negotiation_offer":
            # 格式: "任务「{task_title}」的发布者提出议价\n留言：{message}\n议价金额：£{negotiated_price:.2f} {currency}"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
            
            # 提取留言
            message_match = re.search(r'(?:留言|Message)[：:]\s*(.+?)(?:\n|$)', content, re.MULTILINE)
            if message_match:
                variables["message"] = message_match.group(1).strip()
            
            # 提取议价金额
            price_match = re.search(r'£([\d.]+)\s*(\w+)', content)
            if price_match:
                variables["negotiated_price"] = float(price_match.group(1))
                variables["currency"] = price_match.group(2).strip()
        
        elif notification_type == "negotiation_rejected":
            # 格式: "申请者已拒绝您对任务「{task_title}」的议价"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "task_approved":
            # 格式: "您对任务「{task_title}」的申请已通过"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "task_reward_paid":
            # 格式: "任务「{task_title}」的奖励已支付"
            match = re.search(r'任务「(.+?)」', content)
            if match:
                variables["task_title"] = match.group(1).strip()
        
        elif notification_type == "task_approved_with_payment":
            # 格式: "您的任务申请已被同意！任务：{task_title}{payment_expires_info}"
            match = re.search(r'任务[：:]\s*(.+?)(?:\n|$)', content)
            if match:
                task_part = match.group(1).strip()
                # 尝试分离 task_title 和 payment_expires_info
                if "请完成支付" in task_part or "Please complete" in task_part:
                    parts = re.split(r'(?:请完成支付|Please complete)', task_part, 1)
                    variables["task_title"] = parts[0].strip()
                    if len(parts) > 1:
                        variables["payment_expires_info"] = parts[1].strip()
                else:
                    variables["task_title"] = task_part
        
    except Exception as e:
        logger.warning(f"提取通知变量失败 (type={notification_type}): {e}")
    
    return variables
