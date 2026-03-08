"""
Redis 工具函数单元测试

测试覆盖:
- scan_keys: SCAN 替代 KEYS
- delete_by_pattern: SCAN + DELETE 替代 KEYS + DELETE

运行方式:
    pytest tests/test_redis_utils.py -v
"""

import pytest
from unittest.mock import MagicMock, call

from app.redis_utils import scan_keys, delete_by_pattern


class TestScanKeys:
    """SCAN 替代 KEYS 测试"""

    def test_single_iteration(self):
        """单次迭代即完成（cursor 返回 0）"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, ["key:1", "key:2", "key:3"])

        result = scan_keys(mock_redis, "key:*")

        assert result == ["key:1", "key:2", "key:3"]
        mock_redis.scan.assert_called_once_with(0, match="key:*", count=100)

    def test_multiple_iterations(self):
        """多次迭代（cursor 不为 0 直到最后一次）"""
        mock_redis = MagicMock()
        mock_redis.scan.side_effect = [
            (42, ["key:1", "key:2"]),     # 第一次，cursor=42，继续
            (100, ["key:3"]),             # 第二次，cursor=100，继续
            (0, ["key:4", "key:5"]),      # 第三次，cursor=0，结束
        ]

        result = scan_keys(mock_redis, "key:*")

        assert result == ["key:1", "key:2", "key:3", "key:4", "key:5"]
        assert mock_redis.scan.call_count == 3

    def test_no_matches(self):
        """无匹配键"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, [])

        result = scan_keys(mock_redis, "nonexistent:*")

        assert result == []

    def test_custom_count(self):
        """自定义 count 参数"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, ["key:1"])

        scan_keys(mock_redis, "key:*", count=500)

        mock_redis.scan.assert_called_once_with(0, match="key:*", count=500)

    def test_redis_error_returns_empty(self):
        """Redis 异常时返回空列表"""
        mock_redis = MagicMock()
        mock_redis.scan.side_effect = Exception("Connection lost")

        result = scan_keys(mock_redis, "key:*")

        assert result == []

    def test_partial_results_on_error(self):
        """部分迭代后出错，返回已获取的结果"""
        mock_redis = MagicMock()
        mock_redis.scan.side_effect = [
            (42, ["key:1", "key:2"]),
            Exception("Connection lost"),
        ]

        result = scan_keys(mock_redis, "key:*")

        assert result == ["key:1", "key:2"]


class TestDeleteByPattern:
    """SCAN + DELETE 测试"""

    def test_delete_matching_keys(self):
        """删除匹配的键"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, ["cache:1", "cache:2", "cache:3"])
        mock_redis.delete.return_value = 3

        deleted = delete_by_pattern(mock_redis, "cache:*")

        assert deleted == 3
        mock_redis.delete.assert_called_once_with("cache:1", "cache:2", "cache:3")

    def test_delete_no_matches(self):
        """无匹配键时不调用 delete"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, [])

        deleted = delete_by_pattern(mock_redis, "nonexistent:*")

        assert deleted == 0
        mock_redis.delete.assert_not_called()

    def test_delete_multiple_iterations(self):
        """多次迭代删除"""
        mock_redis = MagicMock()
        mock_redis.scan.side_effect = [
            (42, ["key:1", "key:2"]),
            (0, ["key:3"]),
        ]
        mock_redis.delete.side_effect = [2, 1]

        deleted = delete_by_pattern(mock_redis, "key:*")

        assert deleted == 3
        assert mock_redis.delete.call_count == 2

    def test_delete_redis_error(self):
        """Redis 异常时返回 0"""
        mock_redis = MagicMock()
        mock_redis.scan.side_effect = Exception("Connection lost")

        deleted = delete_by_pattern(mock_redis, "key:*")

        assert deleted == 0

    def test_delete_custom_count(self):
        """自定义 count 参数"""
        mock_redis = MagicMock()
        mock_redis.scan.return_value = (0, ["key:1"])
        mock_redis.delete.return_value = 1

        delete_by_pattern(mock_redis, "key:*", count=200)

        mock_redis.scan.assert_called_once_with(0, match="key:*", count=200)
