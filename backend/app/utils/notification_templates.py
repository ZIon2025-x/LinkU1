"""
系统通知国际化模板
用于生成中英文通知标题和内容
"""
from typing import Dict, Any, Optional, Tuple

# 系统通知模板字典
# 格式: {notification_type: {"zh": {"title": "...", "content": "..."}, "en": {"title": "...", "content": "..."}}}
NOTIFICATION_TEMPLATES: Dict[str, Dict[str, Dict[str, str]]] = {
    # 任务申请
    "task_application": {
        "zh": {
            "title": "新任务申请",
            "content_template": "{applicant_name} 申请了任务「{task_title}」\n申请留言：{application_message}\n议价金额：{price_info}"
        },
        "en": {
            "title": "New Task Application",
            "content_template": "{applicant_name} applied for task「{task_title}」\nApplication message: {application_message}\nNegotiated price: {price_info}"
        }
    },
    
    # 任务申请被接受
    "application_accepted": {
        "zh": {
            "title": "申请者已接受您的议价，请完成支付",
            "content_template": "申请者已接受您对任务「{task_title}」的议价，请完成支付。{payment_expires_info}"
        },
        "en": {
            "title": "Application Accepted - Payment Required",
            "content_template": "The applicant has accepted your negotiation offer for task「{task_title}」. Please complete the payment.{payment_expires_info}"
        }
    },
    
    # 任务申请被拒绝
    "application_rejected": {
        "zh": {
            "title": "您的申请已被拒绝",
            "content_template": "您的任务申请已被拒绝：{task_title}"
        },
        "en": {
            "title": "Application Rejected",
            "content_template": "Your task application has been rejected: {task_title}"
        }
    },
    
    # 任务申请撤回
    "application_withdrawn": {
        "zh": {
            "title": "有申请者撤回了申请",
            "content_template": "有申请者撤回了对任务「{task_title}」的申请"
        },
        "en": {
            "title": "Application Withdrawn",
            "content_template": "An applicant has withdrawn their application for task「{task_title}」"
        }
    },
    
    # 任务完成
    "task_completed": {
        "zh": {
            "title": "任务已完成",
            "content_template": "{taker_name} 已将任务「{task_title}」标记为完成"
        },
        "en": {
            "title": "Task Completed",
            "content_template": "{taker_name} has marked task「{task_title}」as completed"
        }
    },
    
    # 任务确认完成
    "task_confirmed": {
        "zh": {
            "title": "奖励已发放",
            "content_template": "任务已完成并确认！「{task_title}」的奖励已发放"
        },
        "en": {
            "title": "Reward Issued",
            "content_template": "Task completed and confirmed! Reward for「{task_title}」has been issued"
        }
    },
    
    # 确认提醒（3天）
    "confirmation_reminder_3days": {
        "zh": {
            "title": "任务确认提醒",
            "content_template": "任务「{task_title}」还有 3 天需要确认完成，请及时确认。"
        },
        "en": {
            "title": "Task Confirmation Reminder",
            "content_template": "Task「{task_title}」has 3 days left to confirm completion. Please confirm in time."
        }
    },
    
    # 确认提醒（1天）
    "confirmation_reminder_1day": {
        "zh": {
            "title": "任务确认提醒",
            "content_template": "任务「{task_title}」还有 1 天需要确认完成，请及时确认。"
        },
        "en": {
            "title": "Task Confirmation Reminder",
            "content_template": "Task「{task_title}」has 1 day left to confirm completion. Please confirm in time."
        }
    },
    
    # 确认提醒（6小时）
    "confirmation_reminder_6hours": {
        "zh": {
            "title": "任务确认提醒",
            "content_template": "任务「{task_title}」还有 6 小时需要确认完成，请及时确认。"
        },
        "en": {
            "title": "Task Confirmation Reminder",
            "content_template": "Task「{task_title}」has 6 hours left to confirm completion. Please confirm in time."
        }
    },
    
    # 确认提醒（1小时）
    "confirmation_reminder_1hour": {
        "zh": {
            "title": "任务确认提醒（紧急）",
            "content_template": "任务「{task_title}」还有 1 小时需要确认完成，请立即确认，否则将自动确认。"
        },
        "en": {
            "title": "Task Confirmation Reminder (Urgent)",
            "content_template": "Task「{task_title}」has 1 hour left to confirm completion. Please confirm immediately, otherwise it will be auto-confirmed."
        }
    },
    
    # 任务自动确认（发布者）
    "task_auto_confirmed_poster": {
        "zh": {
            "title": "任务已自动确认完成",
            "content_template": "任务「{task_title}」已自动确认完成（5天未确认，系统自动确认）。"
        },
        "en": {
            "title": "Task Auto-Confirmed",
            "content_template": "Task「{task_title}」has been automatically confirmed as completed (5 days unconfirmed, system auto-confirmed)."
        }
    },
    
    # 任务自动确认（接单人）
    "task_auto_confirmed_taker": {
        "zh": {
            "title": "任务已自动确认完成",
            "content_template": "任务「{task_title}」已自动确认完成，奖励已发放。"
        },
        "en": {
            "title": "Task Auto-Confirmed",
            "content_template": "Task「{task_title}」has been automatically confirmed as completed. Reward has been issued."
        }
    },
    
    # 任务自动确认（通用）
    "task_auto_confirmed": {
        "zh": {
            "title": "任务已自动确认完成",
            "content_template": "任务「{task_title}」已自动确认完成（5天未确认，系统自动确认）。"
        },
        "en": {
            "title": "Task Auto-Confirmed",
            "content_template": "Task「{task_title}」has been automatically confirmed as completed (5 days unconfirmed, system auto-confirmed)."
        }
    },
    
    # 任务已取消
    "task_cancelled": {
        "zh": {
            "title": "任务已取消",
            "content_template": "您的任务「{task_title}」已被取消"
        },
        "en": {
            "title": "Task Cancelled",
            "content_template": "Your task「{task_title}」has been cancelled"
        }
    },
    
    # 任务自动取消
    "task_auto_cancelled": {
        "zh": {
            "title": "任务自动取消",
            "content_template": "您的任务「{task_title}」因超过截止日期已自动取消"
        },
        "en": {
            "title": "Task Auto-Cancelled",
            "content_template": "Your task「{task_title}」has been automatically cancelled due to exceeding the deadline"
        }
    },
    
    # 申请留言/议价
    "application_message": {
        "zh": {
            "title": "新留言",
            "content_template": "任务「{task_title}」的发布者给您留言：{message}"
        },
        "en": {
            "title": "New Message",
            "content_template": "The publisher of task「{task_title}」sent you a message: {message}"
        }
    },
    
    # 议价提议（发布者发起议价）
    "negotiation_offer": {
        "zh": {
            "title": "新的议价提议",
            "content_template": "任务「{task_title}」的发布者提出议价\n留言：{message}\n议价金额：£{negotiated_price:.2f} {currency}"
        },
        "en": {
            "title": "New Price Offer",
            "content_template": "The publisher of task「{task_title}」proposed a negotiation\nMessage: {message}\nNegotiated price: £{negotiated_price:.2f} {currency}"
        }
    },
    
    # 议价被拒绝
    "negotiation_rejected": {
        "zh": {
            "title": "申请者已拒绝您的议价",
            "content_template": "申请者已拒绝您对任务「{task_title}」的议价"
        },
        "en": {
            "title": "Negotiation Rejected",
            "content_template": "The applicant has rejected your negotiation offer for task「{task_title}」"
        }
    },
    
    # 任务已批准
    "task_approved": {
        "zh": {
            "title": "任务申请已通过",
            "content_template": "您对任务「{task_title}」的申请已通过"
        },
        "en": {
            "title": "Task Application Approved",
            "content_template": "Your application for task「{task_title}」has been approved"
        }
    },
    
    # 任务奖励已支付
    "task_reward_paid": {
        "zh": {
            "title": "任务奖励已支付",
            "content_template": "任务「{task_title}」的奖励已支付"
        },
        "en": {
            "title": "Task Reward Paid",
            "content_template": "Reward for task「{task_title}」has been paid"
        }
    },
    
    # 任务申请已同意（带支付提醒）
    "task_approved_with_payment": {
        "zh": {
            "title": "任务申请已同意，请完成支付",
            "content_template": "您的任务申请已被同意！任务：{task_title}{payment_expires_info}"
        },
        "en": {
            "title": "Task Application Approved - Payment Required",
            "content_template": "Your task application has been approved! Task: {task_title}{payment_expires_info}"
        }
    },
}


def get_notification_texts(
    notification_type: str,
    **kwargs
) -> Tuple[str, str, str, str]:
    """
    获取通知的中英文标题和内容
    
    Args:
        notification_type: 通知类型（如 "task_application", "task_completed" 等）
        **kwargs: 模板变量（如 applicant_name, task_title 等）
    
    Returns:
        tuple: (title_zh, content_zh, title_en, content_en) 中文和英文的标题和内容
    """
    template = NOTIFICATION_TEMPLATES.get(notification_type)
    if not template:
        # 如果没有找到对应的通知类型，返回默认值
        default_zh = {"title": "通知", "content_template": "{message}"}
        default_en = {"title": "Notification", "content_template": "{message}"}
        template = {"zh": default_zh, "en": default_en}
    
    # 获取中文模板
    zh_template = template.get("zh", {})
    title_zh = zh_template.get("title", "通知")
    content_template_zh = zh_template.get("content_template", "{message}")
    
    # 获取英文模板
    en_template = template.get("en", {})
    title_en = en_template.get("title", "Notification")
    content_template_en = en_template.get("content_template", "{message}")
    
    # 格式化内容
    try:
        content_zh = content_template_zh.format(**kwargs)
    except (KeyError, ValueError) as e:
        # 如果缺少必需的变量或格式化错误，使用默认值
        logger.warning(f"格式化中文通知内容失败 (type={notification_type}): {e}, 使用模板: {content_template_zh}")
        content_zh = content_template_zh
        if "message" in kwargs:
            content_zh = kwargs.get("message", content_template_zh)
    
    try:
        content_en = content_template_en.format(**kwargs)
    except (KeyError, ValueError) as e:
        # 如果缺少必需的变量或格式化错误，使用默认值
        logger.warning(f"格式化英文通知内容失败 (type={notification_type}): {e}, 使用模板: {content_template_en}")
        content_en = content_template_en
        if "message" in kwargs:
            content_en = kwargs.get("message", content_template_en)
    
    return title_zh, content_zh, title_en, content_en
