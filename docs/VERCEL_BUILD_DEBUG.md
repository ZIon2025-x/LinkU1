# Vercel 构建调试指南

## 问题：为什么只改了 frontend，但 admin 和 service 也在构建？

### 可能的原因

1. **Vercel "Ignore Build Step" 未配置或配置错误**
   - 如果未配置，Vercel 会在每次推送时构建所有项目
   - 如果配置错误，命令可能总是返回需要构建的结果

2. **GitHub Actions 工作流触发**
   - GitHub Actions 会为所有三个项目运行检查
   - 但每个项目会检查自己的目录是否有变化
   - 如果检查逻辑有问题，可能误判为需要构建

3. **手动触发**
   - 可能在 Vercel Dashboard 中手动触发了构建

## 检查步骤

### 1. 检查最近的提交

```bash
# 查看最近一次提交修改的文件
git show --name-only HEAD

# 只查看 frontend, admin, service 目录的文件
git show --name-only HEAD | grep -E "^(frontend|admin|service)/"
```

### 2. 检查 Vercel "Ignore Build Step" 配置

访问 Vercel Dashboard：
- Frontend: `https://vercel.com/你的账户/link2ur/settings/git`
- Admin: `https://vercel.com/你的账户/link2ur-admin/settings/git`
- Service: `https://vercel.com/你的账户/link2ur-cs/settings/git`

确认每个项目的 "Ignore Build Step" 命令是否正确配置。

### 3. 测试 "Ignore Build Step" 命令

在本地测试命令（模拟 Vercel 环境）：

```bash
# 测试 frontend 命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
echo "Exit code: $?"  # 0 = 构建, 1 = 跳过

# 测试 admin 命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
echo "Exit code: $?"  # 0 = 构建, 1 = 跳过

# 测试 service 命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
echo "Exit code: $?"  # 0 = 构建, 1 = 跳过
```

### 4. 检查 Vercel 构建日志

在 Vercel Dashboard → Deployments → 点击失败的构建 → 查看日志

查找：
- "Ignoring build step" - 说明被跳过了
- "Building..." - 说明正在构建
- 错误信息

## 正确的配置

### Frontend 项目的 "Ignore Build Step"

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

**逻辑**：
- 如果当前提交中有 `frontend/` 文件 → 返回 0 → **构建**
- 如果没有 → 返回 1 → **跳过**

### Admin 项目的 "Ignore Build Step"

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
```

### Service 项目的 "Ignore Build Step"

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
```

## 常见问题

### Q: 为什么命令总是返回需要构建？

**A:** 可能的原因：
1. 命令在错误的目录执行（应该在仓库根目录）
2. `HEAD` 指向错误的提交
3. 命令语法错误

**解决方法**：
```bash
# 确保在仓库根目录执行
cd /path/to/repo

# 检查当前提交
git log -1 --oneline

# 测试命令
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && echo "Should build" || echo "Should skip"
```

### Q: 为什么 GitHub Actions 显示构建成功，但 Vercel 没有构建？

**A:** 
- GitHub Actions 和 Vercel 是独立的系统
- GitHub Actions 的构建不影响 Vercel
- 需要分别配置两者的路径过滤

### Q: 如何强制跳过构建？

**A:** 在 "Ignore Build Step" 中返回非零退出码：
```bash
exit 1  # 总是跳过构建
```

### Q: 如何强制构建？

**A:** 在 "Ignore Build Step" 中返回 0：
```bash
exit 0  # 总是构建
```

或者清空 "Ignore Build Step" 命令框。

## 调试技巧

### 1. 添加调试输出（Vercel 不支持，但可以在本地测试）

```bash
# 在本地测试
echo "Checking frontend changes..."
if git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/"; then
  echo "Frontend has changes - should build"
  exit 0
else
  echo "Frontend has no changes - should skip"
  exit 1
fi
```

### 2. 检查 Vercel 环境

Vercel 在执行 "Ignore Build Step" 时：
- 在仓库根目录执行命令
- 使用浅克隆（`--depth=1`）
- `HEAD` 指向当前提交

### 3. 验证配置

创建一个测试提交，只修改 frontend 文件：

```bash
# 创建一个测试文件
echo "test" >> frontend/test.txt
git add frontend/test.txt
git commit -m "test: frontend only"
git push

# 检查 Vercel 是否只构建 frontend
```

## 推荐配置

### 方案 1：使用简单的路径检查（推荐）

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

### 方案 2：处理首次提交

```bash
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff HEAD^ HEAD --quiet -- frontend/ || exit 0
else
  git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
fi
```

## 验证清单

- [ ] 每个 Vercel 项目都配置了 "Ignore Build Step"
- [ ] 命令在本地测试通过
- [ ] 只修改 frontend 时，admin 和 service 被跳过
- [ ] 只修改 admin 时，frontend 和 service 被跳过
- [ ] 只修改 service 时，frontend 和 admin 被跳过
- [ ] 同时修改多个目录时，对应的项目都构建
