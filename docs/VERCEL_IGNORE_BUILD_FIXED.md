# Vercel "Ignore Build Step" 修复方案

## 问题

提交 7 只修改了 `service/README.md`，但所有前端项目（frontend、admin、service）都在 Vercel 构建。

## 根本原因

Vercel 在执行 "Ignore Build Step" 时使用**浅克隆**（`--depth=1`），这可能导致：
1. `git diff` 命令无法正常工作
2. `HEAD^` 不存在
3. 命令执行失败，Vercel 默认构建

## 解决方案：使用更健壮的命令

### Frontend 项目的 "Ignore Build Step"

```bash
# 方案 1：使用 git show 检查当前提交的文件（推荐）
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
```

或者更简单的版本：

```bash
# 方案 2：检查当前提交的文件变化（如果支持）
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

如果还是不行，使用这个最健壮的版本：

```bash
# 方案 3：最健壮版本（处理所有情况）
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  # 有上一个提交，比较变化
  git diff HEAD^ HEAD --name-only --diff-filter=ACMRT | grep -q "^frontend/" || exit 1
else
  # 没有上一个提交，检查当前提交的文件
  git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
fi
```

### Admin 项目的 "Ignore Build Step"

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" || exit 1
```

### Service 项目的 "Ignore Build Step"

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" || exit 1
```

## 推荐配置（最简单可靠）

### Frontend

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
```

### Admin

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" || exit 1
```

### Service

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" || exit 1
```

## 为什么使用 `git show` 而不是 `git diff`？

1. **`git show`** 只查看当前提交，不依赖上一个提交
2. **`git diff HEAD^ HEAD`** 需要上一个提交存在，浅克隆可能没有
3. **`git diff --name-only HEAD`** 在浅克隆中可能无法正常工作

## 测试命令

在本地测试（模拟 Vercel 环境）：

```bash
# 测试 frontend
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && echo "Should BUILD" || echo "Should SKIP"

# 测试 admin
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && echo "Should BUILD" || echo "Should SKIP"

# 测试 service（当前提交7）
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && echo "Should BUILD" || echo "Should SKIP"
```

对于提交 7（只修改了 `service/README.md`），应该显示：
- Frontend: Should SKIP
- Admin: Should SKIP
- Service: Should BUILD（因为确实有 service 文件变化）

## 如果只想检查代码文件，忽略文档

如果你想忽略 README.md 等文档文件，可以使用：

```bash
# Frontend（忽略文档文件）
git show --name-only --pretty=format:"" HEAD | grep "^frontend/" | grep -v -E '\.(md|txt)$|README' | head -1 | grep -q . || exit 1
```

但这个命令比较复杂，如果只是 README.md 变化，建议直接构建（因为可能影响文档站点）。

## 配置步骤

1. **进入 Vercel Dashboard**
   - Frontend: `Settings → Git → Ignore Build Step`
   - Admin: `Settings → Git → Ignore Build Step`
   - Service: `Settings → Git → Ignore Build Step`

2. **输入对应的命令**（使用上面的推荐配置）

3. **保存**

4. **测试**
   - 创建一个只修改 frontend 的提交
   - 检查 Vercel 是否只构建 frontend

## 验证

创建一个测试提交：

```bash
# 只修改 frontend
echo "test" >> frontend/test.txt
git add frontend/test.txt
git commit -m "test: frontend only"
git push
```

检查 Vercel：
- ✅ Frontend 应该构建
- ⏭️ Admin 应该跳过
- ⏭️ Service 应该跳过
