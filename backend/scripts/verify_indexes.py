"""
索引验证脚本
验证任务表索引的使用情况和性能
"""
import json
import logging
from sqlalchemy import text
from app.database import sync_engine

logger = logging.getLogger(__name__)


def verify_indexes():
    """验证索引使用情况 - 稳健的 JSON 解析"""
    # 使用 sync_engine 直接连接，避免依赖 get_sync_db 的生成器
    db = sync_engine.connect()
    
    def parse_explain_result(result):
        """稳健地解析 EXPLAIN JSON 结果"""
        row = result.fetchone()
        if not row:
            return None
        
        # 解析 JSON（可能是字符串或已经是 dict）
        plan_data = row[0]
        if isinstance(plan_data, str):
            plan_data = json.loads(plan_data)
        elif isinstance(plan_data, (list, tuple)) and len(plan_data) > 0:
            plan_data = plan_data[0] if isinstance(plan_data[0], dict) else json.loads(plan_data[0])
        
        # 稳健地提取计划信息
        plan = plan_data.get('Plan', {}) if isinstance(plan_data, dict) else {}
        execution_time = plan_data.get('Execution Time', 0)
        node_type = plan.get('Node Type', 'Unknown')
        
        return {
            'node_type': node_type,
            'execution_time': execution_time,
            'full_plan': plan_data
        }
    
    logger.info("=" * 60)
    logger.info("开始验证任务表索引...")
    logger.info("=" * 60)
    
    # 测试查询1：任务详情（应该使用覆盖索引）
    logger.info("\n1. 测试任务详情查询（应该使用覆盖索引）...")
    result1 = db.execute(text("""
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        SELECT id, title, task_type, location, status, base_reward, deadline, created_at
        FROM tasks
        WHERE id = :task_id
    """), {"task_id": 1})
    
    plan1 = parse_explain_result(result1)
    if plan1:
        logger.info(f"   查询计划: {plan1['node_type']}")
        logger.info(f"   执行时间: {plan1['execution_time']}ms")
        # 打印计划要点而非直接 assert
        if plan1['node_type'] not in ['Index Scan', 'Index Only Scan']:
            logger.warning(f"   ⚠️ 警告: 未使用索引扫描，当前类型: {plan1['node_type']}")
        else:
            logger.info("   ✅ 使用了索引扫描")
    
    # 测试查询2：任务列表（应该使用复合索引）
    logger.info("\n2. 测试任务列表查询（应该使用复合索引）...")
    result2 = db.execute(text("""
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        SELECT *
        FROM tasks
        WHERE status = 'open' AND deadline > NOW()
        ORDER BY created_at DESC
        LIMIT 20
    """))
    
    plan2 = parse_explain_result(result2)
    if plan2:
        logger.info(f"   查询计划: {plan2['node_type']}")
        logger.info(f"   执行时间: {plan2['execution_time']}ms")
        plan_str = json.dumps(plan2['full_plan'], indent=2)
        if 'Index Scan' not in plan_str:
            logger.warning(f"   ⚠️ 警告: 可能未使用索引扫描")
        else:
            logger.info("   ✅ 使用了索引扫描")
    
    # 测试查询3：用户发布的任务（应该使用发布者索引）
    logger.info("\n3. 测试用户发布的任务查询（应该使用发布者索引）...")
    result3 = db.execute(text("""
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        SELECT *
        FROM tasks
        WHERE poster_id = :poster_id AND status = 'open'
        ORDER BY created_at DESC
        LIMIT 10
    """), {"poster_id": "U00001"})
    
    plan3 = parse_explain_result(result3)
    if plan3:
        logger.info(f"   查询计划: {plan3['node_type']}")
        logger.info(f"   执行时间: {plan3['execution_time']}ms")
        plan_str = json.dumps(plan3['full_plan'], indent=2)
        if 'Index Scan' not in plan_str:
            logger.warning(f"   ⚠️ 警告: 可能未使用索引扫描")
        else:
            logger.info("   ✅ 使用了索引扫描")
    
    # 查看索引统计
    logger.info("\n4. 查看索引统计信息...")
    result4 = db.execute(text("""
        SELECT
            schemaname,
            tablename,
            indexname,
            pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch,
            -- 估算膨胀：如果扫描次数少但大小大，可能有膨胀
            CASE 
                WHEN idx_scan = 0 THEN '未使用'
                WHEN pg_relation_size(indexname::regclass) > 100 * 1024 * 1024 
                     AND idx_scan < 100 THEN '可能膨胀'
                ELSE '正常'
            END AS status
        FROM pg_stat_user_indexes
        WHERE tablename = 'tasks'
        ORDER BY pg_relation_size(indexname::regclass) DESC
    """))
    
    indexes = result4.fetchall()
    if indexes:
        logger.info("   索引名称 | 大小 | 扫描次数 | 状态")
        logger.info("   " + "-" * 50)
        for idx in indexes:
            logger.info(f"   {idx[2]} | {idx[3]} | {idx[4]} | {idx[8]}")
    
    logger.info("\n" + "=" * 60)
    logger.info("索引验证完成")
    logger.info("=" * 60)
    
    # 关闭连接
    db.close()


if __name__ == "__main__":
    verify_indexes()

