# Vercel 构建问题修复指南

## 问题诊断

如果 CI 成功但 Vercel 没有构建，可能的原因：

1. **"Ignore Build Step" 命令逻辑错误**
2. **首次提交时 `HEAD^` 不存在**
3. **命令在错误的目录执行**

## 解决方案

### 方案 1：修复 "Ignore Build Step" 命令（推荐）

在 Vercel Dashboard → 项目 → Settings → Git → Ignore Build Step

#### Frontend 项目

使用以下命令（处理首次提交的情况）：

```bash
# 检查是否有上一个提交，如果有则比较，如果没有则检查当前提交
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff HEAD^ HEAD --quiet -- frontend/
else
  # 首次提交，检查当前提交是否有 frontend 文件
  git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/"
  exit $((1 - $?))  # 反转退出码：有文件返回0（构建），无文件返回1（跳过）
fi
```

或者更简单的版本（如果工作流已通过路径过滤触发）：

```bash
# 如果工作流被触发，说明有相关文件变化，应该构建
# 检查当前提交中是否有 frontend 文件
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

#### Admin 项目

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
```

#### Service 项目

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
```

### 方案 2：临时禁用 "Ignore Build Step"（用于测试）

1. 进入 Vercel Dashboard → 项目 → Settings → Git
2. 找到 "Ignore Build Step" 选项
3. **暂时清空或注释掉命令**，让所有提交都触发构建
4. 测试构建是否正常
5. 如果构建正常，再恢复 "Ignore Build Step" 命令

### 方案 3：手动触发构建

1. 进入 Vercel Dashboard → 项目 → Deployments
2. 点击右上角的 **"Redeploy"** 按钮
3. 选择最新的提交
4. 点击 **"Redeploy"**

## 验证步骤

### 1. 检查 Vercel 项目配置

确认以下设置：

- **Root Directory**: `frontend`（对于 frontend 项目）
- **Build Command**: `npm run build`
- **Output Directory**: `build`
- **Install Command**: `npm install`

### 2. 测试 "Ignore Build Step" 命令

在本地测试命令：

```bash
# 测试 frontend 命令
cd /path/to/repo
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && echo "Should build" || echo "Should skip"

# 测试 admin 命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" && echo "Should build" || echo "Should skip"

# 测试 service 命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" && echo "Should build" || echo "Should skip"
```

### 3. 检查 Vercel 构建日志

1. 进入 Vercel Dashboard → 项目 → Deployments
2. 点击最新的部署
3. 查看构建日志，确认：
   - 是否执行了 "Ignore Build Step"
   - 命令的退出码是什么
   - 是否有错误信息

## 推荐的 "Ignore Build Step" 命令

### 最简版本（推荐）

**Frontend:**
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

**Admin:**
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
```

**Service:**
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
```

### 说明

- `git diff --name-only --diff-filter=ACMRT HEAD`: 获取当前提交中新增、修改、重命名、类型变更的文件
- `grep -q "^frontend/"`: 检查是否有 frontend 目录下的文件
- `|| exit 1`: 如果没有匹配，退出码为 1（Vercel 会跳过构建）
- 如果有匹配，退出码为 0（Vercel 会构建）

## 常见问题

### Q: 为什么使用 `HEAD` 而不是 `HEAD^ HEAD`？

A: 
- `HEAD^ HEAD` 需要上一个提交存在，首次提交会失败
- `HEAD` 检查当前提交的文件，更可靠
- 由于 GitHub Actions 已经通过路径过滤触发，说明有相关文件变化

### Q: 为什么使用 `--diff-filter=ACMRT`？

A: 只检查实际变化的文件（Added, Copied, Modified, Renamed, Type changed），忽略删除的文件。

### Q: 如果还是不行怎么办？

A: 
1. 临时禁用 "Ignore Build Step"，测试构建是否正常
2. 检查 Vercel 构建日志中的错误信息
3. 确认 Root Directory 设置正确
4. 手动触发一次构建测试
