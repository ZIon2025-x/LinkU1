"""
推送通知国际化模板
支持多语言的推送通知标题和内容
"""
import logging

logger = logging.getLogger(__name__)

# 推送通知模板字典
# 格式: {notification_type: {language: {"title": "...", "body": "..."}}}
PUSH_NOTIFICATION_TEMPLATES = {
    # 任务申请
    "task_application": {
        "en": {
            "title": "New Task Application",
            "body_template": "{applicant_name} applied for task「{task_title}」"
        },
        "zh": {
            "title": "新任务申请",
            "body_template": "{applicant_name} 申请了任务「{task_title}」"
        }
    },
    
    # 任务申请被接受
    "application_accepted": {
        "en": {
            "title": "Application Accepted",
            "body_template": "Your application has been accepted: {task_title}"
        },
        "zh": {
            "title": "申请已被接受",
            "body_template": "您的任务申请已被接受：{task_title}"
        }
    },
    
    # 任务申请被拒绝
    "application_rejected": {
        "en": {
            "title": "Application Rejected",
            "body_template": "Your application has been rejected: {task_title}"
        },
        "zh": {
            "title": "申请已被拒绝",
            "body_template": "您的任务申请已被拒绝：{task_title}"
        }
    },
    
    # 任务申请撤回
    "application_withdrawn": {
        "en": {
            "title": "Application Withdrawn",
            "body_template": "An applicant withdrew their application for task「{task_title}」"
        },
        "zh": {
            "title": "申请已撤回",
            "body_template": "有申请者撤回了对任务「{task_title}」的申请"
        }
    },
    
    # 任务完成
    "task_completed": {
        "en": {
            "title": "Task Completed",
            "body_template": "{taker_name} marked task as completed: {task_title}"
        },
        "zh": {
            "title": "任务已完成",
            "body_template": "{taker_name} 标记任务已完成：{task_title}"
        }
    },
    
    # 任务确认完成
    "task_confirmed": {
        "en": {
            "title": "Task Confirmed",
            "body_template": "Task completed and confirmed! Reward has been issued: {task_title}"
        },
        "zh": {
            "title": "任务已确认完成",
            "body_template": "任务已完成并确认！奖励已发放：{task_title}"
        }
    },
    
    # 任务拒绝
    "task_rejected": {
        "en": {
            "title": "Application Rejected",
            "body_template": "Sorry, your task application was rejected: {task_title}"
        },
        "zh": {
            "title": "任务申请被拒绝",
            "body_template": "很抱歉，您的任务申请被拒绝：{task_title}"
        }
    },
    
    # 申请留言/议价
    "application_message": {
        "en": {
            "title": "New Message",
            "body_template": "{message}"
        },
        "zh": {
            "title": "新的留言",
            "body_template": "{message}"
        }
    },
    
    # 申请留言回复
    "application_message_reply": {
        "en": {
            "title": "Reply to Your Message",
            "body_template": "Applicant replied to your message for task「{task_title}」: {message}"
        },
        "zh": {
            "title": "申请者回复了您的留言",
            "body_template": "申请者回复了您对任务「{task_title}」的留言：{message}"
        }
    },
    
    # 议价被拒绝
    "negotiation_rejected": {
        "en": {
            "title": "Negotiation Rejected",
            "body_template": "Applicant rejected your negotiation for task「{task_title}」"
        },
        "zh": {
            "title": "议价被拒绝",
            "body_template": "申请者已拒绝您对任务「{task_title}」的议价"
        }
    },
    
    # 私信消息
    "message": {
        "en": {
            "title": "New Message",
            "body_template": "{message}"
        },
        "zh": {
            "title": "新消息",
            "body_template": "{message}"
        }
    },
    
    # 论坛回复帖子
    "reply_post": {
        "en": {
            "title": "Post Replied",
            "body_template": "{user_name} replied to your post"
        },
        "zh": {
            "title": "有人回复了您的帖子",
            "body_template": "{user_name} 回复了您的帖子"
        }
    },
    
    # 论坛回复评论
    "reply_reply": {
        "en": {
            "title": "Comment Replied",
            "body_template": "{user_name} replied to your comment"
        },
        "zh": {
            "title": "有人回复了您的评论",
            "body_template": "{user_name} 回复了您的评论"
        }
    },
    
    # 论坛回复（通用）
    "forum_reply": {
        "en": {
            "title": "Forum Reply",
            "body_template": "{user_name} replied to your post: {post_title}"
        },
        "zh": {
            "title": "论坛回复",
            "body_template": "{user_name} 回复了您的帖子：{post_title}"
        }
    },
    
    # 通用通知
    "general": {
        "en": {
            "title": "Notification",
            "body_template": "{message}"
        },
        "zh": {
            "title": "通知",
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


