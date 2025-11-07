"""
简化的数据库迁移脚本
直接在应用启动时执行 SQL，使用 IF NOT EXISTS 语法避免重复创建
"""
from sqlalchemy import text
from app.database import sync_engine
import logging

logger = logging.getLogger(__name__)


def run_simple_migration():
    """执行简化的数据库迁移"""
    try:
        with sync_engine.connect() as connection:
            # 开始事务
            trans = connection.begin()
            
            try:
                # ============================================
                # 1. 修改 Task 表
                # ============================================
                connection.execute(text("""
                    DO $$ 
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='tasks' AND column_name='base_reward') THEN
                            ALTER TABLE tasks ADD COLUMN base_reward NUMERIC(12,2);
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='tasks' AND column_name='agreed_reward') THEN
                            ALTER TABLE tasks ADD COLUMN agreed_reward NUMERIC(12,2);
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='tasks' AND column_name='currency') THEN
                            ALTER TABLE tasks ADD COLUMN currency VARCHAR(3) DEFAULT 'GBP';
                        END IF;
                    END $$;
                """))
                
                # ============================================
                # 2. 修改 TaskApplication 表
                # ============================================
                connection.execute(text("""
                    DO $$ 
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='task_applications' AND column_name='negotiated_price') THEN
                            ALTER TABLE task_applications ADD COLUMN negotiated_price NUMERIC(12,2);
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='task_applications' AND column_name='currency') THEN
                            ALTER TABLE task_applications ADD COLUMN currency VARCHAR(3) DEFAULT 'GBP';
                        END IF;
                    END $$;
                """))
                
                # ============================================
                # 3. 修改 Message 表
                # ============================================
                connection.execute(text("""
                    DO $$ 
                    BEGIN
                        -- 修改 receiver_id 为可空（如果还不是可空）
                        IF EXISTS (SELECT 1 FROM information_schema.columns 
                                   WHERE table_name='messages' AND column_name='receiver_id' 
                                   AND is_nullable='NO') THEN
                            ALTER TABLE messages ALTER COLUMN receiver_id DROP NOT NULL;
                        END IF;
                        
                        -- 添加新字段
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='messages' AND column_name='task_id') THEN
                            ALTER TABLE messages ADD COLUMN task_id INTEGER;
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='messages' AND column_name='message_type') THEN
                            ALTER TABLE messages ADD COLUMN message_type VARCHAR(20) DEFAULT 'normal';
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='messages' AND column_name='conversation_type') THEN
                            ALTER TABLE messages ADD COLUMN conversation_type VARCHAR(20) DEFAULT 'task';
                        END IF;
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='messages' AND column_name='meta') THEN
                            ALTER TABLE messages ADD COLUMN meta TEXT;
                        END IF;
                    EXCEPTION WHEN OTHERS THEN
                        -- 忽略错误，继续执行
                        NULL;
                    END $$;
                """))
                
                # 创建外键（如果不存在）
                connection.execute(text("""
                    DO $$ 
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                                      WHERE constraint_name='fk_messages_task_id') THEN
                            ALTER TABLE messages ADD CONSTRAINT fk_messages_task_id 
                            FOREIGN KEY (task_id) REFERENCES tasks(id);
                        END IF;
                    END $$;
                """))
                
                # 创建索引（如果不存在）
                indexes_to_create = [
                    ('ix_messages_task_id', 'messages', ['task_id']),
                    ('ix_messages_task_type', 'messages', ['task_id', 'message_type']),
                    ('ix_messages_task_created', 'messages', ['task_id', 'created_at', 'id']),
                    ('ix_messages_conversation_type', 'messages', ['conversation_type', 'task_id']),
                    ('ix_messages_task_id_id', 'messages', ['task_id', 'id']),
                ]
                
                for index_name, table_name, columns in indexes_to_create:
                    cols_str = ', '.join(columns)
                    connection.execute(text(f"""
                        DO $$ 
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM pg_indexes 
                                          WHERE indexname='{index_name}' AND tablename='{table_name}') THEN
                                CREATE INDEX {index_name} ON {table_name} ({cols_str});
                            END IF;
                        END $$;
                    """))
                
                # ============================================
                # 4. 修改 Notification 表
                # ============================================
                connection.execute(text("""
                    DO $$ 
                    BEGIN
                        -- 修改 user_id 为不可空（如果原来可空）
                        IF EXISTS (SELECT 1 FROM information_schema.columns 
                                   WHERE table_name='notifications' AND column_name='user_id' 
                                   AND is_nullable='YES') THEN
                            ALTER TABLE notifications ALTER COLUMN user_id SET NOT NULL;
                        END IF;
                        
                        -- 修改 type 字段长度（如果还不是 32）
                        IF EXISTS (SELECT 1 FROM information_schema.columns 
                                   WHERE table_name='notifications' AND column_name='type' 
                                   AND character_maximum_length != 32) THEN
                            ALTER TABLE notifications ALTER COLUMN type TYPE VARCHAR(32);
                        END IF;
                        
                        -- 修改 title 为可空（如果还不是可空）
                        IF EXISTS (SELECT 1 FROM information_schema.columns 
                                   WHERE table_name='notifications' AND column_name='title' 
                                   AND is_nullable='NO') THEN
                            ALTER TABLE notifications ALTER COLUMN title DROP NOT NULL;
                        END IF;
                        
                        -- 添加 read_at 字段
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                                      WHERE table_name='notifications' AND column_name='read_at') THEN
                            ALTER TABLE notifications ADD COLUMN read_at TIMESTAMP;
                        END IF;
                    EXCEPTION WHEN OTHERS THEN
                        -- 忽略错误，继续执行
                        NULL;
                    END $$;
                """))
                
                # 创建新索引
                notification_indexes = [
                    ('ix_notifications_user', 'notifications', ['user_id', 'created_at']),
                    ('ix_notifications_type', 'notifications', ['type', 'related_id']),
                ]
                
                for index_name, table_name, columns in notification_indexes:
                    cols_str = ', '.join(columns)
                    connection.execute(text(f"""
                        DO $$ 
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM pg_indexes 
                                          WHERE indexname='{index_name}' AND tablename='{table_name}') THEN
                                CREATE INDEX {index_name} ON {table_name} ({cols_str});
                            END IF;
                        END $$;
                    """))
                
                # ============================================
                # 5. 创建新表（如果不存在）
                # ============================================
                
                # MessageReads 表
                connection.execute(text("""
                    CREATE TABLE IF NOT EXISTS message_reads (
                        id SERIAL PRIMARY KEY,
                        message_id INTEGER NOT NULL,
                        user_id VARCHAR(8) NOT NULL,
                        read_at TIMESTAMP NOT NULL,
                        CONSTRAINT fk_message_reads_message FOREIGN KEY (message_id) 
                            REFERENCES messages(id) ON DELETE CASCADE,
                        CONSTRAINT fk_message_reads_user FOREIGN KEY (user_id) 
                            REFERENCES users(id),
                        CONSTRAINT uq_message_reads_message_user UNIQUE (message_id, user_id)
                    );
                """))
                
                # MessageAttachments 表
                connection.execute(text("""
                    CREATE TABLE IF NOT EXISTS message_attachments (
                        id SERIAL PRIMARY KEY,
                        message_id INTEGER NOT NULL,
                        attachment_type VARCHAR(20) NOT NULL,
                        url VARCHAR(500),
                        blob_id VARCHAR(100),
                        meta TEXT,
                        created_at TIMESTAMP NOT NULL,
                        CONSTRAINT fk_message_attachments_message FOREIGN KEY (message_id) 
                            REFERENCES messages(id) ON DELETE CASCADE,
                        CONSTRAINT ck_message_attachments_url_blob CHECK (
                            (url IS NOT NULL AND blob_id IS NULL) OR 
                            (url IS NULL AND blob_id IS NOT NULL)
                        )
                    );
                """))
                
                # NegotiationResponseLog 表
                connection.execute(text("""
                    CREATE TABLE IF NOT EXISTS negotiation_response_logs (
                        id SERIAL PRIMARY KEY,
                        notification_id INTEGER,
                        task_id INTEGER NOT NULL,
                        application_id INTEGER NOT NULL,
                        user_id VARCHAR(8) NOT NULL,
                        action VARCHAR(20) NOT NULL,
                        negotiated_price NUMERIC(12,2),
                        responded_at TIMESTAMP NOT NULL,
                        ip_address VARCHAR(45),
                        user_agent TEXT,
                        CONSTRAINT fk_negotiation_log_notification FOREIGN KEY (notification_id) 
                            REFERENCES notifications(id),
                        CONSTRAINT fk_negotiation_log_task FOREIGN KEY (task_id) 
                            REFERENCES tasks(id),
                        CONSTRAINT fk_negotiation_log_application FOREIGN KEY (application_id) 
                            REFERENCES task_applications(id),
                        CONSTRAINT fk_negotiation_log_user FOREIGN KEY (user_id) 
                            REFERENCES users(id),
                        CONSTRAINT uq_negotiation_log_application_action UNIQUE (application_id, action)
                    );
                """))
                
                # MessageReadCursors 表
                connection.execute(text("""
                    CREATE TABLE IF NOT EXISTS message_read_cursors (
                        id SERIAL PRIMARY KEY,
                        task_id INTEGER NOT NULL,
                        user_id VARCHAR(8) NOT NULL,
                        last_read_message_id INTEGER NOT NULL,
                        updated_at TIMESTAMP NOT NULL,
                        CONSTRAINT fk_message_read_cursors_task FOREIGN KEY (task_id) 
                            REFERENCES tasks(id),
                        CONSTRAINT fk_message_read_cursors_user FOREIGN KEY (user_id) 
                            REFERENCES users(id),
                        CONSTRAINT fk_message_read_cursors_message FOREIGN KEY (last_read_message_id) 
                            REFERENCES messages(id),
                        CONSTRAINT uq_message_read_cursors_task_user UNIQUE (task_id, user_id)
                    );
                """))
                
                # 为新表创建索引
                new_table_indexes = [
                    ('ix_message_reads_message_id', 'message_reads', ['message_id']),
                    ('ix_message_reads_user_id', 'message_reads', ['user_id']),
                    ('ix_message_reads_task_user', 'message_reads', ['message_id', 'user_id']),
                    ('ix_message_attachments_message_id', 'message_attachments', ['message_id']),
                    ('ix_negotiation_log_notification', 'negotiation_response_logs', ['notification_id']),
                    ('ix_negotiation_log_task', 'negotiation_response_logs', ['task_id']),
                    ('ix_negotiation_log_application', 'negotiation_response_logs', ['application_id']),
                    ('ix_negotiation_log_user', 'negotiation_response_logs', ['user_id']),
                    ('ix_message_read_cursors_task_user', 'message_read_cursors', ['task_id', 'user_id']),
                    ('ix_message_read_cursors_message', 'message_read_cursors', ['last_read_message_id']),
                ]
                
                for index_name, table_name, columns in new_table_indexes:
                    cols_str = ', '.join(columns)
                    connection.execute(text(f"""
                        DO $$ 
                        BEGIN
                            IF NOT EXISTS (SELECT 1 FROM pg_indexes 
                                          WHERE indexname='{index_name}' AND tablename='{table_name}') THEN
                                CREATE INDEX {index_name} ON {table_name} ({cols_str});
                            END IF;
                        END $$;
                    """))
                
                # 提交事务
                trans.commit()
                logger.info("✅ 简化迁移完成！")
                
            except Exception as e:
                trans.rollback()
                logger.error(f"❌ 迁移失败，已回滚: {e}")
                raise
                
    except Exception as e:
        logger.error(f"❌ 数据库迁移失败: {e}")
        raise

