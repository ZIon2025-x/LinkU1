"""
推送通知国际化模板
支持多语言的推送通知标题和内容
"""
import logging
import re

logger = logging.getLogger(__name__)

# 推送通知模板字典
# 格式: {notification_type: {language: {"title": "...", "body": "..."}}}
# 注意：使用简洁友好的表达，适当使用表情符号增强视觉效果
PUSH_NOTIFICATION_TEMPLATES = {
    # 指定用户任务请求（用户资料页发给指定用户，需对方同意或议价）
    "task_direct_request": {
        "en": {
            "title": "📩 Task Request",
            "body_template": "Someone sent you a task request. Tap to accept or negotiate:「{task_title}」{reward_text_en}"
        },
        "zh": {
            "title": "📩 任务请求",
            "body_template": "有人向您发送了任务请求，请同意或议价：「{task_title}」{reward_text_zh}"
        }
    },

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
    
    # 任务完成（可选 template_vars: evidence_summary / evidence_summary_en 为证据摘要，无则为空串）
    "task_completed": {
        "en": {
            "title": "✅ Task Completed",
            "body_template": "{taker_name} marked「{task_title}」as completed.{evidence_summary_en}"
        },
        "zh": {
            "title": "✅ 任务已完成",
            "body_template": "{taker_name} 已将「{task_title}」标记为完成。{evidence_summary}"
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
    
    # 任务自动确认完成（超时未确认，系统自动确认）
    "task_auto_confirmed": {
        "en": {
            "title": "✅ Task Auto-Confirmed",
            "body_template": "Task「{task_title}」has been auto-confirmed (unconfirmed for 5 days)"
        },
        "zh": {
            "title": "✅ 任务已自动确认",
            "body_template": "任务「{task_title}」已自动确认完成（5天未确认，系统自动确认）"
        }
    },
    
    # 自动转账提醒（确认截止前 1-2 天提醒发布者）
    "auto_transfer_reminder": {
        "en": {
            "title": "⏰ Auto-Transfer Reminder",
            "body_template": "Task「{task_title}」will be auto-confirmed in {days_remaining} day(s). Please confirm or dispute if needed"
        },
        "zh": {
            "title": "⏰ 自动转账提醒",
            "body_template": "任务「{task_title}」将在 {days_remaining} 天后自动确认转账，如有异议请及时处理"
        }
    },
    
    # 自动确认转账完成（3天后系统自动确认并转账）
    "auto_confirm_transfer": {
        "en": {
            "title": "💰 Payment Auto-Transferred",
            "body_template": "Task「{task_title}」has been auto-confirmed. Payment of {amount} has been transferred"
        },
        "zh": {
            "title": "💰 报酬已自动发放",
            "body_template": "任务「{task_title}」已自动确认完成，报酬 {amount} 已转账"
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
    
    # 跳蚤市场直接购买（待付款阶段，买家下单但尚未支付）
    "flea_market_direct_purchase": {
        "en": {
            "title": "🛒 New Order Received",
            "body_template": "{buyer_name} placed an order for「{item_title}」, awaiting payment"
        },
        "zh": {
            "title": "🛒 商品已被下单",
            "body_template": "{buyer_name} 下单了「{item_title}」，等待买家完成付款"
        }
    },
    
    # 跳蚤市场商品售出（支付成功后）
    "flea_market_sold": {
        "en": {
            "title": "💰 Item Sold!",
            "body_template": "「{item_title}」has been sold! The buyer has completed payment."
        },
        "zh": {
            "title": "💰 商品已售出",
            "body_template": "「{item_title}」已售出！买家已完成付款，可以开始交易了"
        }
    },
    
    # 跳蚤市场支付提醒
    "flea_market_pending_payment": {
        "en": {
            "title": "💳 Payment Reminder",
            "body_template": "Please complete payment for「{item_title}」within 30 minutes"
        },
        "zh": {
            "title": "💳 支付提醒",
            "body_template": "请在30分钟内完成「{item_title}」的支付"
        }
    },
    
    # 跳蚤市场卖家议价
    "flea_market_seller_counter_offer": {
        "en": {
            "title": "💰 New Counter Offer",
            "body_template": "{seller_name} proposed a new price for「{item_title}」: £{counter_price:.2f}"
        },
        "zh": {
            "title": "💰 卖家提出新价格",
            "body_template": "{seller_name} 对「{item_title}」提出了新价格：£{counter_price:.2f}"
        }
    },
    
    # 跳蚤市场购买申请被拒绝
    "flea_market_purchase_rejected": {
        "en": {
            "title": "❌ Purchase Request Rejected",
            "body_template": "Your purchase request for「{item_title}」has been rejected by {seller_name}"
        },
        "zh": {
            "title": "❌ 购买申请已拒绝",
            "body_template": "您对「{item_title}」的购买申请已被 {seller_name} 拒绝"
        }
    },
    
    # 跳蚤市场（通用，用于其他情况）
    "flea_market_generic": {
        "en": {
            "title": "🛒 Flea Market Update",
            "body_template": "You have a new update about「{item_title}」"
        },
        "zh": {
            "title": "🛒 跳蚤市场动态",
            "body_template": "您的商品「{item_title}」有新的动态"
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
    
    # 任务截止日期提醒
    "deadline_reminder": {
        "en": {
            "title": "⏰ Deadline Reminder",
            "body_template": "Task「{task_title}」will expire in {time_text}. Please pay attention to the task progress."
        },
        "zh": {
            "title": "⏰ 截止日期提醒",
            "body_template": "任务「{task_title}」将在{time_text}后到期，请及时关注任务进度。"
        }
    },

    # 任务取消
    "task_cancelled": {
        "en": {
            "title": "Task Cancelled",
            "body_template": "Task「{task_title}」has been cancelled"
        },
        "zh": {
            "title": "任务已取消",
            "body_template": "任务「{task_title}」已被取消"
        }
    },

    # 退款申请
    "refund_request": {
        "en": {
            "title": "💳 Refund Request",
            "body_template": "{poster_name} requested a refund for「{task_title}」({reason_type})"
        },
        "zh": {
            "title": "💳 退款申请",
            "body_template": "{poster_name} 对「{task_title}」发起了退款申请（{reason_type}）"
        }
    },

    # 取消请求通过
    "cancel_request_approved": {
        "en": {
            "title": "✅ Cancel Request Approved",
            "body_template": "Your cancel request for「{task_title}」has been approved"
        },
        "zh": {
            "title": "✅ 取消请求已通过",
            "body_template": "您对「{task_title}」的取消请求已通过审核"
        }
    },

    # 取消请求被拒绝
    "cancel_request_rejected": {
        "en": {
            "title": "Cancel Request Rejected",
            "body_template": "Your cancel request for「{task_title}」has been rejected"
        },
        "zh": {
            "title": "取消请求被拒绝",
            "body_template": "您对「{task_title}」的取消请求被拒绝"
        }
    },

    # 活动奖励积分
    "activity_reward_points": {
        "en": {
            "title": "🎉 Activity Reward",
            "body_template": "You earned {points} points for completing activity「{activity_title}」"
        },
        "zh": {
            "title": "🎉 活动奖励",
            "body_template": "您完成活动「{activity_title}」的任务，获得 {points} 积分奖励"
        }
    },

    # 活动现金奖励
    "activity_reward_cash": {
        "en": {
            "title": "💰 Cash Reward",
            "body_template": "You earned £{amount:.2f} for completing activity「{activity_title}」"
        },
        "zh": {
            "title": "💰 现金奖励",
            "body_template": "您完成活动「{activity_title}」的任务，获得 £{amount:.2f} 现金奖励"
        }
    },

    # 任务奖励已支付
    "task_reward_paid": {
        "en": {
            "title": "💰 Reward Paid",
            "body_template": "The reward for task「{task_title}」has been paid to your account"
        },
        "zh": {
            "title": "💰 任务金已发放",
            "body_template": "任务「{task_title}」的报酬已发放到您的账户"
        }
    },

    # VIP 激活
    "vip_activated": {
        "en": {
            "title": "⭐ VIP Activated!",
            "body_template": "Congratulations! You are now a VIP member. Enjoy all VIP benefits!"
        },
        "zh": {
            "title": "⭐ VIP 已激活！",
            "body_template": "恭喜您成为VIP会员！现在可以享受所有VIP权益了。"
        }
    },

    # 论坛板块申请通过
    "forum_category_approved": {
        "en": {
            "title": "✅ Category Approved",
            "body_template": "Your forum category application「{category_name}」has been approved!"
        },
        "zh": {
            "title": "✅ 板块申请已通过",
            "body_template": "您申请的板块「{category_name}」已通过审核！"
        }
    },

    # 论坛板块申请被拒绝
    "forum_category_rejected": {
        "en": {
            "title": "Category Application Rejected",
            "body_template": "Your forum category application「{category_name}」was not approved"
        },
        "zh": {
            "title": "板块申请未通过",
            "body_template": "很抱歉，您申请的板块「{category_name}」未通过审核"
        }
    },

    # 确认完成提醒
    "confirmation_reminder": {
        "en": {
            "title": "⏰ Confirmation Reminder",
            "body_template": "Task「{task_title}」is awaiting your confirmation ({hours_remaining}h remaining)"
        },
        "zh": {
            "title": "⏰ 确认提醒",
            "body_template": "任务「{task_title}」等待您确认完成（剩余 {hours_remaining} 小时）"
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
    },

    # 附近新任务推送
    "nearby_task": {
        "en": {
            "title": "New task nearby",
            "body_template": "{task_title}, near you"
        },
        "zh": {
            "title": "附近有新任务",
            "body_template": "{task_title}，就在你附近"
        }
    },
}


_TEMPLATE_VAR_RE = re.compile(r"\{(\w+)(?:[^}]*)?\}")

_NOTIFICATION_FALLBACK = {
    "zh": "您有一条新通知",
    "en": "You have a new notification",
}
_MESSAGE_FALLBACK = {
    "zh": "您有一条新消息",
    "en": "You have a new message",
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
    if language not in ("en", "zh"):
        language = "en"

    templates = PUSH_NOTIFICATION_TEMPLATES.get(notification_type)
    if not templates:
        templates = PUSH_NOTIFICATION_TEMPLATES.get("general", {})

    template = templates.get(language) or templates.get("en", {
        "title": "Notification",
        "body_template": "{message}",
    })

    title = template.get("title", "Notification")
    body_template = template.get("body_template", "{message}")

    # ---- 预填缺失 / 空白的模板变量 ----
    kwargs = dict(kwargs)  # 避免修改原始 dict

    # {message} 特殊处理：空/None 时使用友好文案
    if "{message}" in body_template:
        msg = kwargs.get("message")
        if msg is None or (isinstance(msg, str) and not msg.strip()):
            kwargs["message"] = _MESSAGE_FALLBACK[language]

    # 检查模板所需的所有变量，为缺失的变量填入空字符串避免 KeyError
    required_vars = set(_TEMPLATE_VAR_RE.findall(body_template))
    for var in required_vars:
        if var not in kwargs:
            kwargs[var] = ""

    # ---- 格式化 ----
    try:
        body = body_template.format(**kwargs)
    except (KeyError, ValueError, IndexError) as e:
        logger.warning(
            f"Template format error for notification_type={notification_type}: {e}"
        )
        if kwargs.get("message"):
            body = kwargs["message"]
        else:
            body = _NOTIFICATION_FALLBACK[language]

    # 最终安全检查：空正文兜底
    if not body or not body.strip():
        body = _NOTIFICATION_FALLBACK[language]

    return title, body


