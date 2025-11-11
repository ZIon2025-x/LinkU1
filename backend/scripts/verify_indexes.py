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
        
        # 递归查找所有节点类型，检查是否有索引扫描
        def find_index_scans(plan_node):
            """递归查找索引扫描节点"""
            index_scans = []
            if isinstance(plan_node, dict):
                node_type = plan_node.get('Node Type', '')
                if 'Index' in node_type or 'Index Scan' in node_type or 'Index Only Scan' in node_type:
                    index_scans.append(node_type)
                # 递归检查子节点
                for key, value in plan_node.items():
                    if isinstance(value, (dict, list)):
                        index_scans.extend(find_index_scans(value))
            elif isinstance(plan_node, list):
                for item in plan_node:
                    index_scans.extend(find_index_scans(item))
            return index_scans
        
        index_scans = find_index_scans(plan_data)
        
        return {
            'node_type': node_type,
            'execution_time': execution_time,
            'full_plan': plan_data,
            'has_index_scan': len(index_scans) > 0,
            'index_scan_types': index_scans
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
        # 检查是否有索引扫描（包括子节点）
        if plan1.get('has_index_scan'):
            logger.info(f"   ✅ 使用了索引扫描: {', '.join(plan1.get('index_scan_types', []))}")
        elif plan1['node_type'] in ['Index Scan', 'Index Only Scan']:
            logger.info("   ✅ 使用了索引扫描")
        else:
            logger.warning(f"   ⚠️ 警告: 未使用索引扫描，当前类型: {plan1['node_type']}（可能是数据量太小，PostgreSQL选择了全表扫描）")
    
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
        # 检查是否有索引扫描（包括子节点）
        if plan2.get('has_index_scan'):
            logger.info(f"   ✅ 使用了索引扫描: {', '.join(plan2.get('index_scan_types', []))}")
        else:
            plan_str = json.dumps(plan2['full_plan'], indent=2)
            if 'Index Scan' in plan_str or 'Index Only Scan' in plan_str:
                logger.info("   ✅ 使用了索引扫描")
            else:
                logger.warning(f"   ⚠️ 警告: 可能未使用索引扫描（可能是数据量太小，PostgreSQL选择了全表扫描）")
    
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
        # 检查是否有索引扫描（包括子节点）
        if plan3.get('has_index_scan'):
            logger.info(f"   ✅ 使用了索引扫描: {', '.join(plan3.get('index_scan_types', []))}")
        else:
            plan_str = json.dumps(plan3['full_plan'], indent=2)
            if 'Index Scan' in plan_str or 'Index Only Scan' in plan_str:
                logger.info("   ✅ 使用了索引扫描")
            else:
                logger.warning(f"   ⚠️ 警告: 可能未使用索引扫描（可能是数据量太小，PostgreSQL选择了全表扫描）")
    
    # 查看索引统计
    logger.info("\n4. 查看索引统计信息...")
    try:
        result4 = db.execute(text("""
            SELECT
                schemaname,
                relname AS tablename,
                indexrelname AS indexname,
                pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
                idx_scan,
                idx_tup_read,
                idx_tup_fetch,
                -- 估算膨胀：如果扫描次数少但大小大，可能有膨胀
                CASE 
                    WHEN idx_scan = 0 THEN '未使用'
                    WHEN pg_relation_size(indexrelid) > 100 * 1024 * 1024 
                         AND idx_scan < 100 THEN '可能膨胀'
                    ELSE '正常'
                END AS status
            FROM pg_stat_user_indexes
            WHERE relname = 'tasks'
            ORDER BY pg_relation_size(indexrelid) DESC
        """))
    
        indexes = result4.fetchall()
        if indexes:
            logger.info("   索引名称 | 大小 | 扫描次数 | 状态")
            logger.info("   " + "-" * 50)
            for idx in indexes:
                logger.info(f"   {idx[2]} | {idx[3]} | {idx[4]} | {idx[8]}")
        else:
            logger.warning("   未找到任务表的索引统计信息")
    except Exception as e:
        logger.warning(f"   获取索引统计信息失败: {e}")
        # 尝试使用替代查询
        try:
            result4_alt = db.execute(text("""
                SELECT
                    indexname,
                    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
                FROM pg_indexes
                WHERE tablename = 'tasks'
                ORDER BY pg_relation_size(indexname::regclass) DESC
            """))
            indexes_alt = result4_alt.fetchall()
            if indexes_alt:
                logger.info("   索引名称 | 大小")
                logger.info("   " + "-" * 30)
                for idx in indexes_alt:
                    logger.info(f"   {idx[0]} | {idx[1]}")
        except Exception as e2:
            logger.warning(f"   替代查询也失败: {e2}")
    
    logger.info("\n" + "=" * 60)
    logger.info("索引验证完成")
    logger.info("=" * 60)
    
    # 关闭连接
    db.close()


if __name__ == "__main__":
    verify_indexes()

