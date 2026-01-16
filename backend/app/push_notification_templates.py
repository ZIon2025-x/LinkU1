"""
推送通知国际化模板
支持多语言的推送通知标题和内容
"""
import logging

logger = logging.getLogger(__name__)

# 推送通知模板字典
# 格式: {notification_type: {language: {"title": "...", "body": "..."}}}
# 注意：使用简洁友好的表达，适当使用表情符号增强视觉效果
PUSH_NOTIFICATION_TEMPLATES = {
    # 任务申请
    "task_application": {
        "en": {
            "title": "✨ New Application",
            "body_template": "{applicant_name} applied for「{task_title}」"
        },
        "zh": {
            "title": "✨ 新申请",
            "body_template": "{applicant_name} 申请了「{task_title}」"
        }
    },
    
    # 任务申请被接受
    "application_accepted": {
        "en": {
            "title": "🎉 Application Accepted!",
            "body_template": "Great news! Your application for「{task_title}」has been accepted"
        },
        "zh": {
            "title": "🎉 申请已通过！",
            "body_template": "好消息！您对「{task_title}」的申请已通过"
        }
    },
    
    # 任务申请被拒绝
    "application_rejected": {
        "en": {
            "title": "Application Not Selected",
            "body_template": "Your application for「{task_title}」was not selected this time"
        },
        "zh": {
            "title": "申请未通过",
            "body_template": "很遗憾，您对「{task_title}」的申请未通过"
        }
    },
    
    # 任务申请撤回
    "application_withdrawn": {
        "en": {
            "title": "Application Withdrawn",
            "body_template": "An applicant withdrew from「{task_title}」"
        },
        "zh": {
            "title": "申请已撤回",
            "body_template": "有申请者撤回了对「{task_title}」的申请"
        }
    },
    
    # 任务完成
    "task_completed": {
        "en": {
            "title": "✅ Task Completed",
            "body_template": "{taker_name} marked「{task_title}」as completed"
        },
        "zh": {
            "title": "✅ 任务已完成",
            "body_template": "{taker_name} 已将「{task_title}」标记为完成"
        }
    },
    
    # 任务确认完成
    "task_confirmed": {
        "en": {
            "title": "💰 Reward Issued!",
            "body_template": "Task completed and confirmed! Reward for「{task_title}」has been issued"
        },
        "zh": {
            "title": "💰 奖励已发放！",
            "body_template": "任务已完成并确认！「{task_title}」的奖励已发放"
        }
    },
    
    # 任务拒绝
    "task_rejected": {
        "en": {
            "title": "Application Not Selected",
            "body_template": "Your application for「{task_title}」was not selected"
        },
        "zh": {
            "title": "申请未通过",
            "body_template": "很抱歉，您对「{task_title}」的申请未通过"
        }
    },
    
    # 申请留言/议价
    "application_message": {
        "en": {
            "title": "💬 New Message",
            "body_template": "{message}"
        },
        "zh": {
            "title": "💬 新留言",
            "body_template": "{message}"
        }
    },
    
    # 申请留言回复
    "application_message_reply": {
        "en": {
            "title": "💬 Reply Received",
            "body_template": "Reply to your message about「{task_title}」: {message}"
        },
        "zh": {
            "title": "💬 收到回复",
            "body_template": "关于「{task_title}」的留言回复：{message}"
        }
    },
    
    # 议价提议（发布者发起议价）
    "negotiation_offer": {
        "en": {
            "title": "💰 New Price Offer",
            "body_template": "Publisher proposed a new price for「{task_title}」: £{negotiated_price:.2f}"
        },
        "zh": {
            "title": "💰 新的议价提议",
            "body_template": "发布者对「{task_title}」提出新价格：£{negotiated_price:.2f}"
        }
    },
    
    # 议价被拒绝
    "negotiation_rejected": {
        "en": {
            "title": "Negotiation Not Accepted",
            "body_template": "Your negotiation for「{task_title}」was not accepted"
        },
        "zh": {
            "title": "议价未接受",
            "body_template": "您对「{task_title}」的议价未被接受"
        }
    },
    
    # 私信消息
    "message": {
        "en": {
            "title": "💌 New Message",
            "body_template": "{message}"
        },
        "zh": {
            "title": "💌 新消息",
            "body_template": "{message}"
        }
    },
    
    # 论坛回复帖子
    "reply_post": {
        "en": {
            "title": "💬 Post Replied",
            "body_template": "{user_name} replied to your post"
        },
        "zh": {
            "title": "💬 帖子有新回复",
            "body_template": "{user_name} 回复了您的帖子"
        }
    },
    
    # 论坛回复评论
    "reply_reply": {
        "en": {
            "title": "💬 Comment Replied",
            "body_template": "{user_name} replied to your comment"
        },
        "zh": {
            "title": "💬 评论有新回复",
            "body_template": "{user_name} 回复了您的评论"
        }
    },
    
    # 论坛回复（通用）
    "forum_reply": {
        "en": {
            "title": "💬 Forum Reply",
            "body_template": "{user_name} replied to「{post_title}」"
        },
        "zh": {
            "title": "💬 论坛回复",
            "body_template": "{user_name} 回复了「{post_title}」"
        }
    },
    
    # 跳蚤市场购买申请
    "flea_market_purchase_request": {
        "en": {
            "title": "🛒 New Purchase Request",
            "body_template": "{buyer_name} wants to buy「{item_title}」"
        },
        "zh": {
            "title": "🛒 新的购买申请",
            "body_template": "{buyer_name} 想要购买「{item_title}」"
        }
    },
    
    # 跳蚤市场购买申请已接受
    "flea_market_purchase_accepted": {
        "en": {
            "title": "✅ Purchase Accepted!",
            "body_template": "Your purchase request for「{item_title}」has been accepted"
        },
        "zh": {
            "title": "✅ 购买申请已接受！",
            "body_template": "您对「{item_title}」的购买申请已被接受"
        }
    },
    
    # 跳蚤市场直接购买
    "flea_market_direct_purchase": {
        "en": {
            "title": "💰 Item Sold",
            "body_template": "{buyer_name} directly purchased「{item_title}」"
        },
        "zh": {
            "title": "💰 商品已售出",
            "body_template": "{buyer_name} 直接购买了「{item_title}」"
        }
    },
    
    # 任务消息（任务聊天）
    "task_message": {
        "en": {
            "title": "💬 New Task Message",
            "body_template": "{sender_name}: {message}"
        },
        "zh": {
            "title": "💬 新任务消息",
            "body_template": "{sender_name}: {message}"
        }
    },
    
    # 任务达人服务申请
    "service_application": {
        "en": {
            "title": "🎯 New Service Application",
            "body_template": "{applicant_name} applied for service「{service_name}」"
        },
        "zh": {
            "title": "🎯 新服务申请",
            "body_template": "{applicant_name} 申请了服务「{service_name}」"
        }
    },
    
    # 任务达人服务申请已批准
    "service_application_approved": {
        "en": {
            "title": "✅ Service Application Approved!",
            "body_template": "Your service application for「{service_name}」has been approved"
        },
        "zh": {
            "title": "✅ 服务申请已通过！",
            "body_template": "您对「{service_name}」的服务申请已通过"
        }
    },
    
    # 任务达人服务申请被拒绝
    "service_application_rejected": {
        "en": {
            "title": "Service Application Rejected",
            "body_template": "Your service application for「{service_name}」was rejected"
        },
        "zh": {
            "title": "服务申请被拒绝",
            "body_template": "您对「{service_name}」的服务申请被拒绝"
        }
    },
    
    # 任务达人服务申请已取消
    "service_application_cancelled": {
        "en": {
            "title": "Service Application Cancelled",
            "body_template": "{applicant_name} cancelled application for「{service_name}」"
        },
        "zh": {
            "title": "服务申请已取消",
            "body_template": "{applicant_name} 取消了对「{service_name}」的申请"
        }
    },
    
    # 任务达人再次议价
    "counter_offer": {
        "en": {
            "title": "💰 New Counter Offer",
            "body_template": "Expert proposed new price for「{service_name}」: £{counter_price:.2f}"
        },
        "zh": {
            "title": "💰 新的议价提议",
            "body_template": "任务达人对「{service_name}」提出新价格：£{counter_price:.2f}"
        }
    },
    
    # 用户同意任务达人的议价
    "counter_offer_accepted": {
        "en": {
            "title": "✅ Counter Offer Accepted",
            "body_template": "{applicant_name} accepted your counter offer for「{service_name}」"
        },
        "zh": {
            "title": "✅ 议价已接受",
            "body_template": "{applicant_name} 已接受您对「{service_name}」的议价"
        }
    },
    
    # 用户拒绝任务达人的议价
    "counter_offer_rejected": {
        "en": {
            "title": "Counter Offer Rejected",
            "body_template": "{applicant_name} rejected your counter offer for「{service_name}」"
        },
        "zh": {
            "title": "议价被拒绝",
            "body_template": "{applicant_name} 拒绝了您对「{service_name}」的议价"
        }
    },
    
    # 通用通知
    "general": {
        "en": {
            "title": "📢 Notification",
            "body_template": "{message}"
        },
        "zh": {
            "title": "📢 通知",
            "body_template": "{message}"
        }
    }
}


def get_push_notification_text(
    notification_type: str,
    language: str = "en",
    **kwargs
) -> tuple[str, str]:
    """
    获取推送通知的标题和内容（根据语言）
    
    Args:
        notification_type: 通知类型（如 "task_application", "task_completed" 等）
        language: 语言代码（"en" 或 "zh"）
        **kwargs: 模板变量（如 applicant_name, task_title 等）
    
    Returns:
        tuple: (title, body) 推送通知的标题和内容
    """
    # 默认使用英文
    if language not in ["en", "zh"]:
        language = "en"
    
    # 获取模板
    templates = PUSH_NOTIFICATION_TEMPLATES.get(notification_type)
    if not templates:
        # 如果没有找到对应的通知类型，使用通用模板
        templates = PUSH_NOTIFICATION_TEMPLATES.get("general", {})
    
    # 获取指定语言的模板
    template = templates.get(language)
    if not template:
        # 如果指定语言不存在，回退到英文
        template = templates.get("en", {"title": "Notification", "body_template": "{message}"})
    
    # 格式化标题和内容
    title = template.get("title", "Notification")
    body_template = template.get("body_template", "{message}")
    
    # 如果 body_template 中没有变量，直接返回
    try:
        body = body_template.format(**kwargs)
    except KeyError as e:
        # 如果缺少必需的变量，使用默认值
        logger.warning(f"Missing template variable {e} for notification type {notification_type}")
        # 尝试使用 message 作为后备
        if "message" in kwargs:
            body = kwargs["message"]
        else:
            body = body_template
    
    return title, body


