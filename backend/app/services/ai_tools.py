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
]
