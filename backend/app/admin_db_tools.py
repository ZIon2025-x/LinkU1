"""
数据库管理工具 API
用于诊断和修复数据库问题
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import text
from app.database import sync_engine
from app.separate_auth_deps import get_current_admin
from app import models
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/admin/db/fix-conversation-key")
def fix_conversation_key(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """手动触发修复 conversation_key 字段"""
    try:
        with sync_engine.connect() as conn:
            # 1. 填充所有 null 值
            result = conn.execute(text("""
                UPDATE messages 
                SET conversation_key = LEAST(sender_id::text, receiver_id::text) || '-' || 
                                      GREATEST(sender_id::text, receiver_id::text)
                WHERE conversation_key IS NULL 
                  AND sender_id IS NOT NULL 
                  AND receiver_id IS NOT NULL
            """))
            updated_count = result.rowcount
            conn.commit()
            
            # 2. 检查触发器是否存在
            trigger_check = conn.execute(text("""
                SELECT COUNT(*) 
                FROM information_schema.triggers
                WHERE event_object_table = 'messages' 
                  AND trigger_name = 'trigger_update_conversation_key'
            """))
            trigger_exists = trigger_check.scalar() > 0
            
            # 3. 检查填充情况
            stats = conn.execute(text("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(conversation_key) as with_key,
                    COUNT(*) - COUNT(conversation_key) as without_key
                FROM messages
            """))
            stats_row = stats.fetchone()
            
            return {
                "success": True,
                "updated_count": updated_count,
                "trigger_exists": trigger_exists,
                "statistics": {
                    "total_messages": stats_row[0],
                    "messages_with_key": stats_row[1],
                    "messages_without_key": stats_row[2]
                }
            }
    except Exception as e:
        logger.error(f"修复 conversation_key 失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"修复失败: {str(e)}")


@router.get("/admin/db/check-conversation-key")
def check_conversation_key(
    current_admin: models.AdminUser = Depends(get_current_admin)
):
    """检查 conversation_key 状态"""
    try:
        with sync_engine.connect() as conn:
            # 检查字段
            field_check = conn.execute(text("""
                SELECT column_name, data_type, is_nullable
                FROM information_schema.columns
                WHERE table_name = 'messages' 
                  AND column_name = 'conversation_key'
            """))
            field_info = field_check.fetchone()
            
            # 检查触发器
            trigger_check = conn.execute(text("""
                SELECT 
                    trigger_name, 
                    event_manipulation,
                    action_timing
                FROM information_schema.triggers
                WHERE event_object_table = 'messages' 
                  AND trigger_name = 'trigger_update_conversation_key'
            """))
            trigger_info = trigger_check.fetchone()
            
            # 统计信息
            stats = conn.execute(text("""
                SELECT 
                    COUNT(*) as total,
                    COUNT(conversation_key) as with_key,
                    COUNT(CASE WHEN sender_id IS NOT NULL AND receiver_id IS NOT NULL AND conversation_key IS NULL THEN 1 END) as should_have_key_but_null
                FROM messages
            """))
            stats_row = stats.fetchone()
            
            # 示例数据
            samples = conn.execute(text("""
                SELECT 
                    id,
                    sender_id,
                    receiver_id,
                    conversation_key,
                    created_at
                FROM messages
                WHERE sender_id IS NOT NULL 
                  AND receiver_id IS NOT NULL
                ORDER BY created_at DESC
                LIMIT 5
            """))
            sample_data = [
                {
                    "id": row[0],
                    "sender_id": row[1],
                    "receiver_id": row[2],
                    "conversation_key": row[3],
                    "created_at": str(row[4])
                }
                for row in samples.fetchall()
            ]
            
            return {
                "field_exists": field_info is not None,
                "field_info": {
                    "name": field_info[0] if field_info else None,
                    "type": field_info[1] if field_info else None,
                    "nullable": field_info[2] if field_info else None
                },
                "trigger_exists": trigger_info is not None,
                "trigger_info": {
                    "name": trigger_info[0] if trigger_info else None,
                    "event": trigger_info[1] if trigger_info else None,
                    "timing": trigger_info[2] if trigger_info else None
                },
                "statistics": {
                    "total_messages": stats_row[0],
                    "messages_with_key": stats_row[1],
                    "messages_without_key": stats_row[0] - stats_row[1],
                    "should_have_key_but_null": stats_row[2]
                },
                "sample_data": sample_data
            }
    except Exception as e:
        logger.error(f"检查 conversation_key 失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"检查失败: {str(e)}")

