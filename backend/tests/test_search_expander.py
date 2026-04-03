"""搜索扩展器 + 分词 单元测试"""

import pytest
from app.utils.tokenizer import tokenize_query
from app.utils.search_expander import expand_keyword, build_keyword_filter


class TestTokenizeQuery:
    def test_chinese_sentence(self):
        tokens = tokenize_query("伯明翰便宜中餐")
        assert "伯明翰" in tokens
        assert "中餐" in tokens
        assert "便宜" in tokens

    def test_english_sentence(self):
        tokens = tokenize_query("cheap Chinese food Birmingham")
        assert "cheap" in tokens
        assert "chinese" in tokens
        assert "food" in tokens
        assert "birmingham" in tokens

    def test_stop_words_filtered(self):
        tokens = tokenize_query("我想找一个家教")
        assert "家教" in tokens
        assert "我" not in tokens
        assert "找" not in tokens

    def test_empty_input(self):
        assert tokenize_query("") == []
        assert tokenize_query("   ") == []

    def test_only_stop_words(self):
        tokens = tokenize_query("的了在是")
        assert tokens == []


class TestExpandKeyword:
    def test_chinese_to_english(self):
        variants = expand_keyword("中餐")
        assert "中餐" in variants
        assert any("Chinese food" in v for v in variants)

    def test_city_name(self):
        variants = expand_keyword("伯明翰")
        assert "伯明翰" in variants
        assert any("Birmingham" in v for v in variants)

    def test_no_expansion(self):
        variants = expand_keyword("随便什么词")
        assert variants == ["随便什么词"]


class TestBuildKeywordFilter:
    """测试 build_keyword_filter 生成的 SQL 表达式结构"""

    def test_returns_none_for_empty(self):
        from sqlalchemy import Column, String
        cols = [Column("title", String)]
        assert build_keyword_filter(cols, "", use_similarity=False) is None
        assert build_keyword_filter(cols, "   ", use_similarity=False) is None

    def test_returns_expression_for_valid_keyword(self):
        from sqlalchemy import Column, String
        cols = [Column("title", String)]
        result = build_keyword_filter(cols, "中餐", use_similarity=False)
        assert result is not None

    def test_tokenized_multi_word_search(self):
        """多词搜索应该生成 AND 连接的条件"""
        from sqlalchemy import Column, String
        cols = [Column("title", String)]
        result = build_keyword_filter(cols, "伯明翰便宜中餐", use_similarity=False)
        assert result is not None
        expr_str = str(result.compile(compile_kwargs={"literal_binds": True}))
        assert "AND" in expr_str
