"""新算法（spec §2.1 重写后）：无 winners_count cap，全员按 final_score 比例分配，floor_pence 抹零。"""
import pytest
from app.services.ai_qa_scoring import distribute_pool


class TestDistributePool:
    def test_empty_input(self):
        assert distribute_pool([], pool_pence=1000, floor_pence=10) == []

    def test_proportional_5_answers(self):
        scored = [(1, 100), (2, 50), (3, 50)]  # total 200
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 比例: 50% / 25% / 25%
        assert result[0] == (1, 500)
        assert result[1] == (2, 250)
        assert result[2] == (3, 250)
        assert sum(r[1] for r in result) == 1000

    def test_all_answers_get_share_no_cap(self):
        # 30 人答题，pool £10 = 1000p，分数均匀 [80, 79, ..., 51]，total ≈ 1965
        scored = [(i + 1, 80 - i) for i in range(30)]  # [(1, 80), (2, 79), ..., (30, 51)]
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 所有 30 个答主都进分配，没有 winners_count cap
        assert len(result) == 30
        # 所有人 reward_pence >= floor (10p)
        for aid, amt in result:
            assert amt >= 10
        # 总额 = 池子
        assert sum(r[1] for r in result) == 1000

    def test_floor_cuts_off_low_scores(self):
        # pool=100p, 5 答主, score=[100, 1, 1, 1, 1], total=104
        scored = [(1, 100), (2, 1), (3, 1), (4, 1), (5, 1)]
        result = distribute_pool(scored, pool_pence=100, floor_pence=10)
        # raw: top1≈96p, 其余各≈1p；1p < floor 10p → 抹零
        # 抹零后 4×0=0，第1名补差: 100 - 96 = 4p 给 top1 → top1=100p
        assert result[0] == (1, 100)
        for aid, amt in result[1:]:
            assert amt == 0

    def test_all_zero_scores(self):
        scored = [(1, 0), (2, 0)]
        result = distribute_pool(scored, pool_pence=1000, floor_pence=10)
        # 全 0 分，每人 0
        assert result == [(1, 0), (2, 0)]

    def test_round_diff_to_first(self):
        # round() 可能丢精度，差额自动加到第 1 名
        scored = [(1, 33), (2, 33), (3, 34)]
        result = distribute_pool(scored, pool_pence=100, floor_pence=1)
        # 必须满总额
        assert sum(r[1] for r in result) == 100

    def test_pool_larger_than_total_score(self):
        # 大 pool（含 sponsor 加注）让所有人都能拿到钱
        scored = [(1, 90), (2, 80), (3, 70), (4, 60), (5, 50)]  # total 350
        result = distribute_pool(scored, pool_pence=5500, floor_pence=10)  # £55 (含加注)
        # 比例: 90/350=25.7%, 80/350=22.9%, ...
        # 5 人都远高于 floor
        for aid, amt in result:
            assert amt >= 10
        assert sum(r[1] for r in result) == 5500
