## Summary
- Phase A of the TaskExpert legacy unification (spec v1.10, 10-round reviewed)
- Adds migration **210** (single atomic DO block) syncing TE/FTE fields to Expert / FeaturedExpertV2, plus `ALTER TABLE experts ADD COLUMN success_rate`
- Switches all Phase A read + write paths (10 functional groups, ~15 files, 21+ code points) from TaskExpert/FeaturedTaskExpert to Expert/FeaturedExpertV2
- Preserves all Phase B/C references (admin routes, model definitions, dead code) per spec §7.6

## Commit Structure (13 commits)

Per spec §7 functional groups:
1. `4fd3c748e` feat(expert): helpers (`is_user_expert_sync`, `get_user_primary_expert_sync`)
2. `4064e1667` feat(migration): 210 sync expert fields + `Expert.success_rate` ORM field
3. `d224f18d9` refactor(expert): 统一 is_expert 判断 (3 文件 5 处)
4. `f13c1f24f` refactor(discovery): JOIN 切到 Expert 团队
5. `23429bbcf` refactor(official): 官方账户读路径
6. `7fa7cc6ee` refactor(follow-feed): FTE → Expert + FeaturedExpertV2
7. `b5ddad4d1` refactor(service-app): 用 new_expert_id 列
8. `c641786b3` refactor(ai-tools): 4 个 tool JOIN 换到 Expert
9. `000de3567` refactor(official): setup_official_account 单写 Expert
10. `a789d5d73` refactor(crud/user): sync_user_task_stats 写 Expert
11. `a6ee9314d` refactor(crud/task_expert): 聚合 + 定时任务改造
12. `b11bd4a9c` refactor(crud/admin_ops): 删 admin 检查 FeaturedExpertV2
13. `440472eac` refactor(cleanup): 化简 service_images 清理

## Rollout

**Migration 210 runs automatically at Railway startup** via `db_migrations.run_migrations`.

### CRITICAL: 部署后强制检查步骤

- [ ] **T+0.1**：Staging 部署后查 backend logs 确认 `210 complete: orphans=0, ...` NOTICE 出现
- [ ] **T+0.2**：查 Celery worker logs 30s，搜 `column experts.success_rate does not exist`；若出现说明 worker 快于 backend migration，Celery 内置重试（3× 60s）通常自动恢复
- [ ] 若看到 `RAISE EXCEPTION` → **人工修复数据（不 revert code）** — migration 可重跑（幂等）

### Rollback
- Migration 失败 → 单 DO 块回滚，`ALTER TABLE ... IF NOT EXISTS` 幂等
- 代码 bug → `git revert` + redeploy；数据无损（TE 表仍在）

## Test Plan

- [x] helper 6 unit tests pass
- [x] migration 210 tests (8 cases) pass on PG: stats / completion_rate / success_rate / FV2 backfill / bio_en COALESCE / newer-updated-at / idempotence / orphan EXCEPTION
- [x] static grep: 无 Phase A scope 代码残留 TE/FTE 活引用 (全部在 §7.6 Phase B/C 范围)
- [x] Phase A 修改的模块 import clean
- [ ] **Staging smoke test (spec §8.2 5 流程)**:
  - [ ] Flutter 登录已知 TaskExpert 用户 → `/api/profile` 返回 `is_expert=true`
  - [ ] Admin 设置用户为官方账号 → `experts.is_official=true` + `expert_members(owner)`；`task_experts` 不再被写入
  - [ ] Flutter 首页达人服务 tab → 返回数据与 `experts` 表一致
  - [ ] 关注 featured 达人 → Follow Feed 展示正确
  - [ ] 用户完成任务被评 5 星 → Expert.rating 更新；TaskExpert 不再被写入
- [ ] full-stack-consistency-check pass

## Known Risks (spec §10)

- **R10**: Migration 210 DO block 失败但 ALTER 已 commit → 人工修数据（见 T+0.1）
- **R11**: `setup_official_account` 对已是其他团队 owner 的 user 会创建第二个团队（既有 bug，Phase A 不修）
- **R12**: Celery worker/backend 启动时序可能瞬时失败（Celery 自动重试 cover）
- **R13**: Migration step 4/5 无 `IS DISTINCT FROM` 过滤，重跑会 bump `updated_at`（非正确性问题）

## Documentation

- Spec: `docs/superpowers/specs/2026-04-19-expert-unification-design.md` (v1.10, 10 rounds of review)
- Plan: `docs/superpowers/plans/2026-04-19-expert-unification-phase-a.md`

## Next Phases (not in this PR)

- **Phase B**: admin_task_expert_routes.py (845 行) 下线 + admin 前端 ExpertManagement.tsx 迁移到 `/api/admin/experts/*`
- **Phase C**: DROP 4 张 legacy 表 + 删除模型类
- **Phase D**: Flutter/Web 命名清理

🤖 Generated with [Claude Code](https://claude.com/claude-code)
