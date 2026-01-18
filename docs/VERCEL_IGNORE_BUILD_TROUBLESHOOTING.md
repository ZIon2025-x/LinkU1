# Vercel "Ignore Build Step" 故障排查

## 问题：所有项目都在构建，即使只改了 service/README.md

### 可能的原因

1. **"Ignore Build Step" 未配置**
   - 检查每个项目的 Settings → Git → Ignore Build Step
   - 如果命令框是空的，Vercel 会构建所有提交

2. **命令执行失败**
   - 如果命令有语法错误，Vercel 可能默认构建
   - 检查 Vercel 构建日志中的错误信息

3. **命令逻辑错误**
   - 命令可能返回了错误的退出码
   - 需要确保：有变化返回 0（构建），无变化返回 1（跳过）

4. **Vercel 缓存问题**
   - 可能需要清除 Vercel 的缓存
   - 或者重新配置项目

## 正确的配置命令

### Frontend 项目

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

### Admin 项目

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
```

### Service 项目

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
```

## 测试命令

在本地测试命令（模拟 Vercel 环境）：

```bash
# 测试当前提交
cd /path/to/repo

# 测试 frontend
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && echo "Frontend: BUILD (exit 0)" || echo "Frontend: SKIP (exit 1)"

# 测试 admin
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" && echo "Admin: BUILD (exit 0)" || echo "Admin: SKIP (exit 1)"

# 测试 service
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" && echo "Service: BUILD (exit 0)" || echo "Service: SKIP (exit 1)"
```

## 调试步骤

### 1. 检查 Vercel 构建日志

进入 Vercel Dashboard → Deployments → 点击构建 → 查看日志

查找：
- "Ignoring build step" - 说明被正确跳过
- "Building..." - 说明正在构建
- 错误信息 - 说明命令执行失败

### 2. 验证命令语法

确保命令格式正确：
- ✅ 正确：`git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1`
- ❌ 错误：`git diff HEAD^ HEAD --quiet -- frontend/`（首次提交会失败）

### 3. 检查 Root Directory

确保每个项目的 Root Directory 设置正确：
- Frontend: `frontend`
- Admin: `admin`
- Service: `service`

### 4. 重新配置项目

如果配置正确但仍然构建，尝试：

1. **清空 "Ignore Build Step"**
   - 保存
   - 等待一次构建
   - 重新输入命令
   - 保存

2. **重新连接 GitHub 仓库**
   - 断开连接
   - 重新连接
   - 重新配置 "Ignore Build Step"

## 常见错误

### 错误 1：命令总是返回需要构建

**原因**：命令逻辑反了

**错误示例**：
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && exit 1
```

**正确示例**：
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

### 错误 2：使用 HEAD^ HEAD

**原因**：首次提交时 HEAD^ 不存在

**错误示例**：
```bash
git diff HEAD^ HEAD --quiet -- frontend/
```

**正确示例**：
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

### 错误 3：命令在错误的目录执行

**原因**：Vercel 在仓库根目录执行命令，但命令假设在其他目录

**解决**：确保命令在仓库根目录执行（Vercel 默认如此）

## 验证清单

- [ ] 每个项目都配置了 "Ignore Build Step"
- [ ] 命令语法正确
- [ ] 命令在本地测试通过
- [ ] Root Directory 设置正确
- [ ] 没有其他配置冲突

## 如果还是不行

1. **联系 Vercel 支持**
   - 提供构建日志
   - 说明配置的命令
   - 说明期望的行为

2. **使用环境变量控制**
   - 在 Vercel 中设置环境变量 `SKIP_BUILD=true`
   - 在 "Ignore Build Step" 中检查：`[ "$SKIP_BUILD" = "true" ] && exit 1 || exit 0`

3. **使用 Vercel CLI 测试**
   ```bash
   vercel --prod
   # 查看输出，确认是否执行了 "Ignore Build Step"
   ```
