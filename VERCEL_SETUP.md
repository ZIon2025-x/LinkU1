# Vercel 部署配置指南

## 概述

Frontend、Admin 和 Service 三个子项目需要配置为独立的 Vercel 项目，并设置路径过滤，只在对应文件夹有更改时才构建和部署。

## 配置步骤

### 1. 在 Vercel 中创建三个独立项目

#### Frontend 项目配置
1. 在 Vercel Dashboard 创建新项目
2. 连接到你的 GitHub 仓库
3. **Root Directory**: 设置为 `frontend`
4. **Framework Preset**: React
5. **Build Command**: `npm run build`
6. **Output Directory**: `build`
7. **Install Command**: `npm install`

#### Admin 项目配置
1. 在 Vercel Dashboard 创建新项目
2. 连接到你的 GitHub 仓库
3. **Root Directory**: 设置为 `admin`
4. **Framework Preset**: React
5. **Build Command**: `npm run build`
6. **Output Directory**: `build`
7. **Install Command**: `npm install`

#### Service 项目配置
1. 在 Vercel Dashboard 创建新项目
2. 连接到同一个 GitHub 仓库
3. **Root Directory**: 设置为 `service`
4. **Framework Preset**: React
5. **Build Command**: `npm run build`
6. **Output Directory**: `build`
7. **Install Command**: `npm install`

### 2. 配置 Ignore Build Step（路径过滤）

这是关键步骤！需要在 Vercel 项目设置中配置，让项目只在对应文件夹有更改时才构建。

#### Frontend 项目的 Ignore Build Step

在 Vercel Dashboard → Frontend 项目 → Settings → Git → Ignore Build Step

添加以下命令（推荐版本，最可靠）：

```bash
# 使用 git show 检查当前提交的文件（不依赖上一个提交，适用于浅克隆）
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
```

**说明**：
- 如果当前提交中有 `frontend/` 文件夹的文件变化，命令返回 0 → **构建**
- 如果没有变化，命令返回 1 → **跳过构建**
- 使用 `git show` 而不是 `git diff`，因为 Vercel 使用浅克隆，`git diff` 可能无法正常工作

**备选方案**（如果上面的命令不工作）：

```bash
# 检查是否有上一个提交，如果有则比较，如果没有则检查当前提交
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff HEAD^ HEAD --quiet -- frontend/
else
  git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/"
  exit $((1 - $?))
fi
```

#### Admin 项目的 Ignore Build Step

在 Vercel Dashboard → Admin 项目 → Settings → Git → Ignore Build Step

添加以下命令：

```bash
# 使用 git show 检查当前提交的文件（最可靠）
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" || exit 1
```

#### Service 项目的 Ignore Build Step

在 Vercel Dashboard → Service 项目 → Settings → Git → Ignore Build Step

添加以下命令：

```bash
# 使用 git show 检查当前提交的文件（最可靠）
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" || exit 1
```

### 3. 环境变量配置

在 Vercel Dashboard 中为每个项目设置环境变量：

#### Frontend 项目环境变量
```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
```

#### Admin 项目环境变量
```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
```

#### Service 项目环境变量
```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
```

## 工作原理

### 自动部署流程

1. **推送代码到 GitHub**
   ```bash
   git push origin main
   ```

2. **Vercel 检测到推送**
   - Vercel 通过 GitHub webhook 收到通知

3. **执行 Ignore Build Step**
   - Vercel 运行你配置的 `git diff` 命令
   - 检查对应文件夹是否有更改

4. **决定是否构建**
   - 有更改 → 执行构建和部署
   - 无更改 → 跳过构建（节省构建时间）

### 示例场景

#### 场景 1：只修改 frontend
```bash
# 修改 frontend/src/App.tsx
git commit -m "Update frontend"
git push
```
→ **Frontend 项目**: 检测到更改 ✅ 构建部署
→ **Admin 项目**: 无更改 ⏭️ 跳过构建
→ **Service 项目**: 无更改 ⏭️ 跳过构建

#### 场景 2：只修改 admin
```bash
# 修改 admin/src/App.tsx
git commit -m "Update admin"
git push
```
→ **Admin 项目**: 检测到更改 ✅ 构建部署
→ **Service 项目**: 无更改 ⏭️ 跳过构建

#### 场景 3：只修改 service
```bash
# 修改 service/src/App.tsx
git commit -m "Update service"
git push
```
→ **Admin 项目**: 无更改 ⏭️ 跳过构建
→ **Service 项目**: 检测到更改 ✅ 构建部署

#### 场景 4：修改其他文件
```bash
# 修改 backend/app/main.py
git commit -m "Update backend"
git push
```
→ **Frontend 项目**: 无更改 ⏭️ 跳过构建
→ **Admin 项目**: 无更改 ⏭️ 跳过构建
→ **Service 项目**: 无更改 ⏭️ 跳过构建

## 验证配置

### 测试 Ignore Build Step

你可以在本地测试 git diff 命令：

```bash
# 测试 frontend 是否有更改
git diff HEAD^ HEAD --quiet -- frontend/
echo $?  # 0 = 无更改, 非0 = 有更改

# 测试 admin 是否有更改
git diff HEAD^ HEAD --quiet -- admin/
echo $?  # 0 = 无更改, 非0 = 有更改

# 测试 service 是否有更改
git diff HEAD^ HEAD --quiet -- service/
echo $?  # 0 = 无更改, 非0 = 有更改
```

### 在 Vercel 中查看构建日志

1. 进入 Vercel Dashboard
2. 选择项目
3. 查看 Deployments
4. 点击某个部署查看日志
5. 检查 "Ignored" 或 "Building" 状态

## 注意事项

1. **首次部署**: 首次连接项目时，即使 Ignore Build Step 返回 0，Vercel 也会构建一次

2. **Fetch Depth**: Vercel 默认会获取足够的提交历史来执行 `HEAD^`，通常不需要特别配置

3. **多个项目**: 如果同一个仓库有多个 Vercel 项目（frontend、admin、service），每个项目都需要单独配置 Ignore Build Step

4. **Pull Request**: PR 合并到 main 分支时，Vercel 会重新检查并部署

## 总结

✅ **GitHub Actions**: 用于 CI 测试（已配置，包含 frontend、admin、service 的路径过滤）
✅ **Vercel 自动部署**: 通过 GitHub 集成自动触发
✅ **路径过滤**: 在 Vercel Dashboard 为每个项目配置 Ignore Build Step
❌ **不需要修改 vercel.json**: 现有配置已经足够

**关键点**: Vercel 的 Ignore Build Step 配置是自动的，一旦设置好，每次推送都会自动检查并决定是否构建。

## 快速配置清单

### Frontend 项目
- [ ] 创建 Vercel 项目，Root Directory: `frontend`
- [ ] 配置 Ignore Build Step: `git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0`
- [ ] 设置环境变量（REACT_APP_API_URL, REACT_APP_WS_URL, REACT_APP_MAIN_SITE_URL）

### Admin 项目
- [ ] 创建 Vercel 项目，Root Directory: `admin`
- [ ] 配置 Ignore Build Step: `git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && exit 1 || exit 0`
- [ ] 设置环境变量（REACT_APP_API_URL, REACT_APP_WS_URL, REACT_APP_MAIN_SITE_URL）

### Service 项目
- [ ] 创建 Vercel 项目，Root Directory: `service`
- [ ] 配置 Ignore Build Step: `git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && exit 1 || exit 0`
- [ ] 设置环境变量（REACT_APP_API_URL, REACT_APP_WS_URL, REACT_APP_MAIN_SITE_URL）

**重要说明**：Vercel 的 "Ignore Build Step" 逻辑是：
- 命令返回 **0** → **跳过构建**
- 命令返回 **非0** → **构建**

命令逻辑：
- `grep -q "^service/"` 找到文件时返回0，没找到时返回非0
- `&& exit 1`：找到文件时退出码为1 → **构建**
- `|| exit 0`：没找到文件时退出码为0 → **跳过**
