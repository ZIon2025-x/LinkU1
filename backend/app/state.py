"""
应用状态管理模块
用于管理应用生命周期状态，特别是关停状态和主事件循环
"""
import asyncio
import threading
from typing import Optional

# 全局关停标记
_is_shutting_down = False
_shutdown_lock = threading.Lock()

# 主事件循环（在 startup 事件中设置）
_main_event_loop: Optional[asyncio.AbstractEventLoop] = None
_loop_lock = threading.Lock()


def set_main_event_loop(loop: asyncio.AbstractEventLoop):
    """设置主事件循环（在 startup 事件中调用）"""
    global _main_event_loop
    with _loop_lock:
        _main_event_loop = loop


def get_main_event_loop() -> Optional[asyncio.AbstractEventLoop]:
    """获取主事件循环"""
    with _loop_lock:
        return _main_event_loop


def mark_shutting_down():
    """标记应用正在关停"""
    global _is_shutting_down
    with _shutdown_lock:
        _is_shutting_down = True


def set_app_shutting_down(flag: bool):
    """设置应用关停状态（别名，保持兼容性）"""
    global _is_shutting_down
    with _shutdown_lock:
        _is_shutting_down = flag


def is_app_shutting_down() -> bool:
    """检查应用是否正在关停"""
    with _shutdown_lock:
        return _is_shutting_down


def reset_shutdown_state():
    """重置关停状态（主要用于测试）"""
    global _is_shutting_down, _main_event_loop
    with _shutdown_lock:
        _is_shutting_down = False
    with _loop_lock:
        _main_event_loop = None

