"""SQLAlchemy 事件钩子：自动维护 city_canonical 列。

监听 Task / TaskExpertService / Expert / Activity 四表的 before_insert + before_update，
在 location 字段变化时自动重算 city_canonical（由 resolve_city_canonical 规范化）。

为什么用事件钩子而不是在每个 endpoint 显式赋值：
- 任务 / 服务 / 达人团队的 create/update 路径分散在 ~10 个 router 文件，
  显式赋值容易漏写、形成数据漂移。
- 钩子集中，覆盖所有 SQLAlchemy 写入路径（含管理后台、后端脚本）。
- resolve_city_canonical 自带 lru_cache，无性能负担。

注：仅在 import 时注册一次。`app/models.py` 末尾 `import app.event_listeners`
触发，这样任何加载 models 的代码（FastAPI / Celery worker / 一次性脚本 /
migration runner）都会自动获得钩子。main.py 也显式 import 一次作为入口
文档（无副作用，sys.modules 缓存避免重复执行）。
"""

from sqlalchemy import event

from app import models
from app.models_expert import Expert
from app.utils.city_filter_utils import resolve_city_canonical


def _sync_city_canonical(target, attr_name: str = "location") -> None:
    """从 target.<attr_name>(默认 location) 算 city_canonical 并写入"""
    location = getattr(target, attr_name, None)
    target.city_canonical = resolve_city_canonical(location)


def _on_task_insert_or_update(_mapper, _connection, target):
    _sync_city_canonical(target)


def _on_service_insert_or_update(_mapper, _connection, target):
    _sync_city_canonical(target)


def _on_expert_insert_or_update(_mapper, _connection, target):
    _sync_city_canonical(target)


def _on_activity_insert_or_update(_mapper, _connection, target):
    _sync_city_canonical(target)


def register() -> None:
    """注册所有事件监听。idempotent — 重复调用 SQLAlchemy 会去重。"""
    event.listen(models.Task, "before_insert", _on_task_insert_or_update)
    event.listen(models.Task, "before_update", _on_task_insert_or_update)
    event.listen(models.TaskExpertService, "before_insert", _on_service_insert_or_update)
    event.listen(models.TaskExpertService, "before_update", _on_service_insert_or_update)
    event.listen(Expert, "before_insert", _on_expert_insert_or_update)
    event.listen(Expert, "before_update", _on_expert_insert_or_update)
    event.listen(models.Activity, "before_insert", _on_activity_insert_or_update)
    event.listen(models.Activity, "before_update", _on_activity_insert_or_update)


# 模块导入时即注册（main.py 启动时一次性 import 触发）
register()
