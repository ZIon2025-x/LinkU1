"""
WebSocket 连接管理器
提供连接池管理、心跳检测、连接清理等功能
"""
import asyncio
import logging
import time
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Dict, Optional, Set
from fastapi import WebSocket
from fastapi.websockets import WebSocketState

from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


class WebSocketConnection:
    """WebSocket 连接包装类"""
    
    def __init__(self, websocket: WebSocket, user_id: str):
        self.websocket = websocket
        self.user_id = user_id
        self.created_at = get_utc_time()
        self.last_activity = get_utc_time()
        self.ping_count = 0
        self.pong_count = 0
        self.missing_pongs = 0
        self.is_alive = True
    
    def update_activity(self):
        """更新活动时间"""
        self.last_activity = get_utc_time()
        self.missing_pongs = 0  # 重置缺失 pong 计数
    
    def record_pong(self):
        """记录收到 pong"""
        self.pong_count += 1
        self.update_activity()
    
    def record_missing_pong(self):
        """记录缺失 pong"""
        self.missing_pongs += 1
    
    def is_stale(self, max_idle_seconds: int = 300) -> bool:
        """检查连接是否过期（超过最大空闲时间）"""
        idle_time = (get_utc_time() - self.last_activity).total_seconds()
        return idle_time > max_idle_seconds
    
    def get_stats(self) -> Dict:
        """获取连接统计信息"""
        return {
            'user_id': self.user_id,
            'created_at': format_iso_utc(self.created_at),
            'last_activity': format_iso_utc(self.last_activity),
            'ping_count': self.ping_count,
            'pong_count': self.pong_count,
            'missing_pongs': self.missing_pongs,
            'is_alive': self.is_alive,
            'idle_seconds': (get_utc_time() - self.last_activity).total_seconds()
        }


class WebSocketManager:
    """WebSocket 连接管理器"""
    
    def __init__(self):
        self.connections: Dict[str, WebSocketConnection] = {}
        self.connection_locks: Dict[str, asyncio.Lock] = defaultdict(asyncio.Lock)
        self._cleanup_task: Optional[asyncio.Task] = None
        self._heartbeat_task: Optional[asyncio.Task] = None
        
        # 配置
        self.heartbeat_interval = 20  # 20秒发送一次 ping
        self.max_missing_pongs = 3  # 连续3次未收到 pong 才断开
        self.max_idle_time = 300  # 5分钟无活动则断开
        self.cleanup_interval = 60  # 每分钟清理一次
    
    async def add_connection(self, websocket: WebSocket, user_id: str) -> Optional[WebSocket]:
        """
        添加新连接，返回旧连接（如果有）
        
        Returns:
            旧连接（如果有），否则返回 None
        """
        old_connection = self.connections.get(user_id)
        
        # 创建新连接对象
        new_connection = WebSocketConnection(websocket, user_id)
        self.connections[user_id] = new_connection
        
        # 启动清理和心跳任务（如果还没启动）
        if self._cleanup_task is None or self._cleanup_task.done():
            self._cleanup_task = asyncio.create_task(self._cleanup_loop())
        
        if self._heartbeat_task is None or self._heartbeat_task.done():
            self._heartbeat_task = asyncio.create_task(self._heartbeat_loop())
        
        logger.info(
            f"WebSocket 连接已添加: user={user_id}, "
            f"总连接数={len(self.connections)}"
        )
        
        # 更新 Prometheus 指标
        try:
            from app.metrics import (
                record_websocket_connection,
                update_websocket_connections_active
            )
            record_websocket_connection("established")
            update_websocket_connections_active(len(self.connections))
        except Exception:
            pass
        
        return old_connection.websocket if old_connection else None
    
    def remove_connection(self, user_id: str):
        """移除连接"""
        if user_id in self.connections:
            del self.connections[user_id]
            logger.debug(f"WebSocket 连接已移除: user={user_id}, 总连接数={len(self.connections)}")
            
            # 更新 Prometheus 指标
            try:
                from app.metrics import (
                    record_websocket_connection,
                    update_websocket_connections_active
                )
                record_websocket_connection("closed")
                update_websocket_connections_active(len(self.connections))
            except Exception:
                pass
        
        # 清理锁（如果不再有连接）
        if user_id not in self.connections and user_id in self.connection_locks:
            del self.connection_locks[user_id]
    
    def get_connection(self, user_id: str) -> Optional[WebSocket]:
        """获取连接"""
        connection = self.connections.get(user_id)
        if connection and connection.is_alive:
            connection.update_activity()
            return connection.websocket
        return None
    
    def get_lock(self, user_id: str) -> asyncio.Lock:
        """获取用户级连接锁"""
        return self.connection_locks[user_id]
    
    async def send_to_user(self, user_id: str, message: dict) -> bool:
        """向指定用户发送消息"""
        connection = self.connections.get(user_id)
        if not connection or not connection.is_alive:
            return False
        
        try:
            await connection.websocket.send_json(message)
            connection.update_activity()
            return True
        except Exception as e:
            logger.warning(f"向用户 {user_id} 发送消息失败: {e}")
            connection.is_alive = False
            return False
    
    async def broadcast(self, message: dict, exclude_users: Optional[Set[str]] = None):
        """广播消息给所有连接的用户"""
        exclude_users = exclude_users or set()
        failed_users = []
        
        for user_id, connection in list(self.connections.items()):
            if user_id in exclude_users or not connection.is_alive:
                continue
            
            try:
                await connection.websocket.send_json(message)
                connection.update_activity()
            except Exception as e:
                logger.debug(f"广播消息给用户 {user_id} 失败: {e}")
                connection.is_alive = False
                failed_users.append(user_id)
        
        # 清理失败的连接
        for user_id in failed_users:
            self.remove_connection(user_id)
    
    async def _heartbeat_loop(self):
        """心跳循环"""
        logger.info("WebSocket 心跳循环已启动")
        
        while True:
            try:
                await asyncio.sleep(self.heartbeat_interval)
                
                current_time = get_utc_time()
                dead_connections = []
                
                for user_id, connection in list(self.connections.items()):
                    if not connection.is_alive:
                        dead_connections.append(user_id)
                        continue
                    
                    try:
                        # 发送 ping
                        await connection.websocket.send_json({"type": "ping"})
                        connection.ping_count += 1
                        
                        # 检查是否超过最大缺失 pong 次数
                        if connection.missing_pongs >= self.max_missing_pongs:
                            logger.warning(
                                f"用户 {user_id} 的连接心跳超时 "
                                f"(缺失 {connection.missing_pongs} 次 pong)"
                            )
                            connection.is_alive = False
                            dead_connections.append(user_id)
                        else:
                            # 增加缺失 pong 计数（如果下次收到 pong 会重置）
                            connection.record_missing_pong()
                    
                    except Exception as e:
                        logger.debug(f"向用户 {user_id} 发送心跳失败: {e}")
                        connection.is_alive = False
                        dead_connections.append(user_id)
                
                # 清理死连接
                for user_id in dead_connections:
                    self.remove_connection(user_id)
            
            except asyncio.CancelledError:
                logger.info("WebSocket 心跳循环已取消")
                break
            except Exception as e:
                logger.error(f"心跳循环出错: {e}", exc_info=True)
                await asyncio.sleep(self.heartbeat_interval)
    
    async def _cleanup_loop(self):
        """清理循环"""
        logger.info("WebSocket 清理循环已启动")
        
        while True:
            try:
                await asyncio.sleep(self.cleanup_interval)
                
                current_time = get_utc_time()
                stale_connections = []
                
                for user_id, connection in list(self.connections.items()):
                    # 检查连接是否过期
                    if connection.is_stale(self.max_idle_time):
                        logger.debug(
                            f"用户 {user_id} 的连接已过期 "
                            f"(空闲 {connection.get_stats()['idle_seconds']:.0f} 秒)"
                        )
                        stale_connections.append(user_id)
                    elif not connection.is_alive:
                        stale_connections.append(user_id)
                
                # 清理过期连接
                for user_id in stale_connections:
                    connection = self.connections.get(user_id)
                    if connection:
                        try:
                            await connection.websocket.close(
                                code=1001,
                                reason="Connection idle timeout"
                            )
                        except Exception:
                            pass
                    self.remove_connection(user_id)
                
                if stale_connections:
                    logger.info(
                        f"清理了 {len(stale_connections)} 个过期连接, "
                        f"当前连接数: {len(self.connections)}"
                    )
            
            except asyncio.CancelledError:
                logger.info("WebSocket 清理循环已取消")
                break
            except Exception as e:
                logger.error(f"清理循环出错: {e}", exc_info=True)
                await asyncio.sleep(self.cleanup_interval)
    
    def record_pong(self, user_id: str):
        """记录收到 pong"""
        connection = self.connections.get(user_id)
        if connection:
            connection.record_pong()
    
    def get_stats(self) -> Dict:
        """获取管理器统计信息"""
        return {
            'total_connections': len(self.connections),
            'active_connections': sum(1 for c in self.connections.values() if c.is_alive),
            'connections': [
                connection.get_stats()
                for connection in self.connections.values()
            ]
        }
    
    async def close_all(self):
        """关闭所有连接"""
        logger.info(f"正在关闭 {len(self.connections)} 个 WebSocket 连接...")
        
        # 取消清理和心跳任务
        if self._cleanup_task:
            self._cleanup_task.cancel()
        if self._heartbeat_task:
            self._heartbeat_task.cancel()
        
        # 关闭所有连接
        close_tasks = []
        for user_id, connection in list(self.connections.items()):
            try:
                if connection.websocket.client_state != WebSocketState.DISCONNECTED:
                    close_tasks.append(
                        connection.websocket.close(
                            code=1001,
                            reason="Server shutting down"
                        )
                    )
            except Exception as e:
                logger.debug(f"关闭连接 {user_id} 时出错: {e}")
        
        # 等待所有关闭操作完成
        if close_tasks:
            try:
                await asyncio.wait_for(
                    asyncio.gather(*close_tasks, return_exceptions=True),
                    timeout=2.0
                )
            except asyncio.TimeoutError:
                logger.warning("WebSocket 关闭超时，强制继续")
        
        self.connections.clear()
        self.connection_locks.clear()
        logger.info("所有 WebSocket 连接已关闭")


# 全局管理器实例
_ws_manager: Optional[WebSocketManager] = None


def get_ws_manager() -> WebSocketManager:
    """获取全局 WebSocket 管理器实例"""
    global _ws_manager
    if _ws_manager is None:
        _ws_manager = WebSocketManager()
    return _ws_manager

