"""一次性回填 tasks / task_expert_services / experts / activities 四表的 city_canonical 列。

用法（在 backend/ 目录下）：
    python scripts/backfill_city_canonical.py             # 实际执行
    python scripts/backfill_city_canonical.py --dry-run   # 仅预览，不写库

需要先跑过 migration 233（列已存在）。复用 app.utils.city_filter_utils.resolve_city_canonical
（与运行时事件钩子完全同一个函数，保证一致）。

不会处理 location 已为空的行（city_canonical 留 NULL）。
"""

import argparse
import os
import sys
from collections import Counter
from pathlib import Path

# 让 `from app.X` 找得到
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root / "backend"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true",
                        help="仅打印计划写入的统计，不实际更新")
    args = parser.parse_args()

    # 注：from app import models 会通过 models.py 末尾的 import 链自动注册
    # 事件钩子。脚本手动 row.city_canonical = canonical，commit 时钩子也会
    # 重新算一遍（结果一致，仅多一次 CPU 调用，无正确性影响）。
    from app import models
    from app.database import sync_engine
    from app.models_expert import Expert
    from app.utils.city_filter_utils import resolve_city_canonical
    from sqlalchemy.orm import sessionmaker

    env = os.getenv("RAILWAY_ENVIRONMENT", "local")
    print(f"环境: {env}")
    print(f"模式: {'DRY-RUN（不写库）' if args.dry_run else '实际写入'}")
    print("=" * 60)

    Session = sessionmaker(bind=sync_engine)
    session = Session()

    targets = [
        ("tasks", models.Task, "location"),
        ("task_expert_services", models.TaskExpertService, "location"),
        ("experts", Expert, "location"),
        ("activities", models.Activity, "location"),
    ]

    grand_totals = Counter()
    for table_name, model, loc_attr in targets:
        print(f"\n→ {table_name}")
        rows = session.query(model).filter(
            getattr(model, loc_attr).isnot(None),
            getattr(model, loc_attr) != "",
        ).all()
        total = len(rows)
        print(f"  待处理 {total} 行（location 非空）")

        stats = Counter()
        unresolved_samples = []
        BATCH = 500  # 每 500 行 commit 一次，避免单大事务 + 中断后能续上
        for i, row in enumerate(rows, 1):
            location = getattr(row, loc_attr)
            canonical = resolve_city_canonical(location)
            stats[canonical or "(unresolved)"] += 1
            if canonical is None and len(unresolved_samples) < 10:
                unresolved_samples.append(location)
            if not args.dry_run:
                row.city_canonical = canonical
            if i % BATCH == 0:
                if not args.dry_run:
                    session.commit()
                print(f"  ... 处理 {i}/{total}")

        if not args.dry_run:
            session.commit()
            print(f"  ✅ commit 完成 ({total} 行)")
        else:
            session.rollback()
            print(f"  (dry-run, 已 rollback)")

        # 统计
        print(f"  分布:")
        for city, cnt in sorted(stats.items(), key=lambda x: -x[1]):
            print(f"    {city}: {cnt}")
        if unresolved_samples:
            print(f"  无法识别样本（前 10 条）:")
            for s in unresolved_samples:
                print(f"    {s!r}")
        grand_totals.update({f"{table_name}.{k}": v for k, v in stats.items()})

    print("\n" + "=" * 60)
    print("总计:")
    for k, v in sorted(grand_totals.items(), key=lambda x: (x[0].split('.')[0], -x[1])):
        print(f"  {k}: {v}")

    session.close()


if __name__ == "__main__":
    main()
