# Vercel "Ignore Build Step" 快速检查指南

## 问题诊断

如果只修改了 `frontend/`，但 `admin` 和 `service` 也在 Vercel 构建，说明 "Ignore Build Step" 可能未配置或配置错误。

## 快速检查步骤

### 1. 检查 Vercel 项目配置

访问以下链接检查每个项目的 "Ignore Build Step" 配置：

**Frontend 项目：**
```
https://vercel.com/你的账户/link2ur/settings/git
```
- 找到 "Ignore Build Step" 选项
- 应该配置了：`git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1`

**Admin 项目：**
```
https://vercel.com/你的账户/link2ur-admin/settings/git
```
- 应该配置了：`git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1`

**Service 项目：**
```
https://vercel.com/你的账户/link2ur-cs/settings/git
```
- 应该配置了：`git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1`

### 2. 如果未配置，立即配置

#### Frontend 项目
1. 进入 Settings → Git
2. 找到 "Ignore Build Step"
3. 输入：
   ```bash
   git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
   ```
4. 保存

#### Admin 项目
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" || exit 1
```

#### Service 项目
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" || exit 1
```

### 3. 验证配置

创建一个测试提交，只修改 frontend：

```bash
# 创建一个测试文件
echo "test" >> frontend/test-vercel.txt
git add frontend/test-vercel.txt
git commit -m "test: verify Vercel ignore build step"
git push
```

然后检查 Vercel Dashboard：
- Frontend 项目应该构建 ✅
- Admin 项目应该显示 "Canceled by Ignored Build Step" ⏭️
- Service 项目应该显示 "Canceled by Ignored Build Step" ⏭️

## 命令说明

### 命令逻辑

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

**工作流程：**
1. `git diff --name-only --diff-filter=ACMRT HEAD` - 获取当前提交中变化的文件列表
2. `grep -q "^frontend/"` - 检查是否有 `frontend/` 开头的文件
3. `|| exit 1` - 如果没有匹配，退出码为 1（Vercel 跳过构建）

**结果：**
- 有 `frontend/` 文件变化 → 退出码 0 → Vercel **构建**
- 没有 `frontend/` 文件变化 → 退出码 1 → Vercel **跳过**

## 常见错误

### ❌ 错误配置 1：命令反了

```bash
# 错误：这样会总是跳过构建
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && exit 1
```

### ❌ 错误配置 2：使用 HEAD^ HEAD

```bash
# 错误：首次提交会失败
git diff HEAD^ HEAD --quiet -- frontend/
```

### ✅ 正确配置

```bash
# 正确：检查当前提交的文件
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

## 调试技巧

### 在本地测试命令

```bash
# 测试 frontend
cd /path/to/repo
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" && echo "Should BUILD" || echo "Should SKIP"

# 测试 admin
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^admin/" && echo "Should BUILD" || echo "Should SKIP"

# 测试 service
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^service/" && echo "Should BUILD" || echo "Should SKIP"
```

### 检查 Vercel 构建日志

在 Vercel Dashboard → Deployments → 点击构建 → 查看日志

查找：
- `"Ignoring build step"` - 被正确跳过
- `"Building..."` - 正在构建（可能配置错误）

## 如果还是不行

1. **临时禁用 "Ignore Build Step"**
   - 清空命令框
   - 保存
   - 测试构建是否正常

2. **检查 Root Directory 设置**
   - Frontend: `frontend`
   - Admin: `admin`
   - Service: `service`

3. **联系 Vercel 支持**
   - 如果配置正确但仍然构建，可能是 Vercel 的 bug
