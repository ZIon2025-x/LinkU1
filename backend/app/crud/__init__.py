# CRUD 包：向后兼容，所有函数仍从 _monolith 统一导出。
# 后续可逐步拆分为 crud/user.py、crud/task.py 等，在此处聚合导出。
from app.crud._monolith import *  # noqa: F401, F403
