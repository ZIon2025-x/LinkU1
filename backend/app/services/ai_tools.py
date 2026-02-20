"""
AI Agent 工具定义 — Phase 1 只读工具（零风险）
"""

TOOLS = [
    {
        "name": "query_my_tasks",
        "description": "查询当前用户的任务列表，支持按状态筛选。Query the current user's task list, with optional status filter.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "enum": ["all", "open", "in_progress", "completed", "cancelled"],
                    "description": "任务状态筛选，默认 all",
                },
                "page": {
                    "type": "integer",
                    "description": "页码，默认 1",
                    "default": 1,
                },
            },
        },
    },
    {
        "name": "get_task_detail",
        "description": "查询单个任务的详细信息（标题、描述、状态、金额、参与者等）。Get detailed info for a specific task.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "integer",
                    "description": "任务 ID",
                },
            },
            "required": ["task_id"],
        },
    },
    {
        "name": "recommend_tasks",
        "description": "获取为当前用户个性化推荐的任务（基于内容、协同过滤、位置等）。Get personalized task recommendations for the current user.",
        "input_schema": {
            "type": "object",
            "properties": {
                "limit": {
                    "type": "integer",
                    "description": "返回数量，默认 10，最大 20",
                    "default": 10,
                },
                "task_type": {
                    "type": "string",
                    "description": "任务类型筛选（可选）",
                },
                "keyword": {
                    "type": "string",
                    "description": "关键词筛选（可选）",
                },
            },
        },
    },
    {
        "name": "search_tasks",
        "description": "搜索平台上的公开任务（按关键词、类型、价格范围）。Search public tasks on the platform.",
        "input_schema": {
            "type": "object",
            "properties": {
                "keyword": {
                    "type": "string",
                    "description": "搜索关键词",
                },
                "task_type": {
                    "type": "string",
                    "description": "任务类型筛选",
                },
                "min_reward": {
                    "type": "number",
                    "description": "最低报酬（GBP）",
                },
                "max_reward": {
                    "type": "number",
                    "description": "最高报酬（GBP）",
                },
            },
        },
    },
    {
        "name": "get_my_profile",
        "description": "获取当前用户的个人资料、评分、任务统计。Get the current user's profile, rating, and task stats.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "get_platform_faq",
        "description": "查询平台常见问题解答（如何发布任务、支付流程、费用说明等）。Query platform FAQ about posting tasks, payments, fees, etc.",
        "input_schema": {
            "type": "object",
            "properties": {
                "question": {
                    "type": "string",
                    "description": "用户的问题关键词",
                },
            },
        },
    },
    {
        "name": "check_cs_availability",
        "description": "检查是否有人工客服在线。Check if any human customer service agents are currently online.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "get_my_points_and_coupons",
        "description": "查询当前用户的积分余额和可用优惠券列表。Get user's points balance and available coupons.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "list_activities",
        "description": "浏览平台进行中的公开活动，支持关键词搜索。List active public activities, with optional keyword search.",
        "input_schema": {
            "type": "object",
            "properties": {
                "keyword": {
                    "type": "string",
                    "description": "搜索关键词（匹配标题/描述）",
                },
            },
        },
    },
    {
        "name": "get_my_notifications_summary",
        "description": "获取当前用户的未读通知数和最近通知。Get user's unread notification count and recent notifications.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "list_my_forum_posts",
        "description": "查询当前用户发布的论坛帖子。List the current user's forum posts.",
        "input_schema": {
            "type": "object",
            "properties": {
                "page": {
                    "type": "integer",
                    "description": "页码，默认 1",
                    "default": 1,
                },
            },
        },
    },
    {
        "name": "search_flea_market",
        "description": "搜索跳蚤市场商品，支持关键词、分类、价格范围筛选。Search flea market items by keyword, category, price range.",
        "input_schema": {
            "type": "object",
            "properties": {
                "keyword": {
                    "type": "string",
                    "description": "搜索关键词",
                },
                "category": {
                    "type": "string",
                    "description": "商品分类",
                },
                "min_price": {
                    "type": "number",
                    "description": "最低价格（GBP）",
                },
                "max_price": {
                    "type": "number",
                    "description": "最高价格（GBP）",
                },
            },
        },
    },
    {
        "name": "get_leaderboard_summary",
        "description": "查看排行榜概览或单个排行榜详情。View leaderboard overview or a specific leaderboard's details.",
        "input_schema": {
            "type": "object",
            "properties": {
                "leaderboard_id": {
                    "type": "integer",
                    "description": "排行榜 ID（不传则返回所有活跃排行榜列表）",
                },
            },
        },
    },
    {
        "name": "list_task_experts",
        "description": "浏览平台活跃的任务达人，支持关键词搜索。List active task experts, with optional keyword search.",
        "input_schema": {
            "type": "object",
            "properties": {
                "keyword": {
                    "type": "string",
                    "description": "搜索关键词（匹配姓名/简介）",
                },
            },
        },
    },
    # ── Phase 2 新增只读工具 ──────────────────────────────────
    {
        "name": "get_activity_detail",
        "description": "查询单个活动的详细信息（标题、描述、地点、价格、参与人数等）。Get detailed info for a specific activity.",
        "input_schema": {
            "type": "object",
            "properties": {
                "activity_id": {
                    "type": "integer",
                    "description": "活动 ID",
                },
            },
            "required": ["activity_id"],
        },
    },
    {
        "name": "get_expert_detail",
        "description": "查询达人详情及其服务列表。Get expert profile and their service list.",
        "input_schema": {
            "type": "object",
            "properties": {
                "expert_id": {
                    "type": "string",
                    "description": "达人 ID（用户 ID）",
                },
            },
            "required": ["expert_id"],
        },
    },
    {
        "name": "get_forum_post_detail",
        "description": "查询论坛帖子详情（标题、内容、分类、互动数据等）。Get forum post details.",
        "input_schema": {
            "type": "object",
            "properties": {
                "post_id": {
                    "type": "integer",
                    "description": "帖子 ID",
                },
            },
            "required": ["post_id"],
        },
    },
    {
        "name": "get_flea_market_item_detail",
        "description": "查询跳蚤市场商品详情（标题、描述、价格、卖家等）。Get flea market item details.",
        "input_schema": {
            "type": "object",
            "properties": {
                "item_id": {
                    "type": "integer",
                    "description": "商品 ID",
                },
            },
            "required": ["item_id"],
        },
    },
    {
        "name": "list_my_applications",
        "description": "查询当前用户的任务申请列表（普通任务申请）。List the current user's task applications.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "enum": ["all", "pending", "approved", "rejected"],
                    "description": "申请状态筛选，默认 all",
                },
                "page": {
                    "type": "integer",
                    "description": "页码，默认 1",
                    "default": 1,
                },
            },
        },
    },
    {
        "name": "list_my_service_applications",
        "description": "查询当前用户的达人服务预约列表。List the current user's expert service applications.",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "enum": ["all", "pending", "negotiating", "price_agreed", "approved", "rejected", "cancelled"],
                    "description": "预约状态筛选，默认 all",
                },
                "page": {
                    "type": "integer",
                    "description": "页码，默认 1",
                    "default": 1,
                },
            },
        },
    },
    {
        "name": "list_my_activities",
        "description": "查询当前用户参与或收藏的活动。List activities the user participated in or favorited.",
        "input_schema": {
            "type": "object",
            "properties": {
                "type": {
                    "type": "string",
                    "enum": ["participated", "favorited"],
                    "description": "查询类型：participated（参与的）或 favorited（收藏的），默认 participated",
                },
            },
        },
    },
    {
        "name": "list_forum_categories",
        "description": "获取论坛分类列表。Get the list of forum categories.",
        "input_schema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "get_task_reviews",
        "description": "查询任务的评价列表（评分、评论、评价者）。Get reviews for a specific task.",
        "input_schema": {
            "type": "object",
            "properties": {
                "task_id": {
                    "type": "integer",
                    "description": "任务 ID",
                },
            },
            "required": ["task_id"],
        },
    },
]
