# Vercel 部署失败修复指南

## 问题：GitHub CI 一直显示 "Vercel – link2ur - Deployment failed"

### 可能的原因

1. **⚠️ vercel.json 路由语法错误（最常见）**
   - 使用了正则表达式语法 `(.*)` 而不是 path-to-regexp 语法
   - 使用了转义语法 `\\.` 而不是 path-to-regexp 语法
   - 错误信息：`Invalid route source pattern - The source property follows the syntax from path-to-regexp, not the RegExp syntax`

2. **Vercel "Ignore Build Step" 配置错误**
   - 命令逻辑反了（返回 0 应该跳过，但配置成了构建）
   - 命令语法错误
   - 命令在错误的目录执行

3. **Vercel 项目配置不正确**
   - Root Directory 设置错误
   - Build Command 或 Output Directory 配置错误
   - 环境变量缺失

4. **构建过程出错**
   - 依赖安装失败
   - TypeScript 编译错误
   - 构建命令执行失败

5. **GitHub 集成问题**
   - Vercel GitHub App 权限不足
   - Webhook 配置错误

## 诊断步骤

### 0. ⚠️ 检查 vercel.json 路由语法（优先检查）

如果看到错误信息 `Invalid route source pattern`，说明 `vercel.json` 中使用了错误的路由语法。

**常见错误**：
- ❌ `"source": "/static/(.*\\.(js|css|png))"` - 使用了正则表达式转义语法
- ❌ `"source": "/api/(.*)"` - 使用了正则表达式语法 `(.*)`
- ✅ `"source": "/api/:path*"` - 正确的 path-to-regexp 语法

**修复方法**：
- 将所有 `(.*)` 改为 `:path*`
- 将所有 `\\.` 改为 `.` 或使用 path-to-regexp 语法
- 在 destination 中使用 `:path*` 而不是 `$1`

**已修复的问题**（在 `frontend/vercel.json` 中）：
- ✅ 修复了 `/static/(.*\\.(js|css|...))` → `/static/:path*`
- ✅ 修复了 `/api/(.*)` → `/api/:path*`
- ✅ 修复了 `/uploads/(.*)` → `/uploads/:path*`
- ✅ 修复了 `/(.*)` → `/:path*`

### 1. 检查 Vercel 项目配置

访问 Vercel Dashboard → 项目 → Settings → General

确认以下配置：

#### Frontend 项目（link2ur）
- **Root Directory**: `frontend` ✅
- **Framework Preset**: React
- **Build Command**: `npm run build`
- **Output Directory**: `build`
- **Install Command**: `npm install`

#### Admin 项目（如果存在）
- **Root Directory**: `admin` ✅
- **Build Command**: `npm run build`
- **Output Directory**: `build`

#### Service 项目（如果存在）
- **Root Directory**: `service` ✅
- **Build Command**: `npm run build`
- **Output Directory**: `build`

### 2. 检查 "Ignore Build Step" 配置

访问 Vercel Dashboard → 项目 → Settings → Git → Ignore Build Step

#### ⚠️ 重要：Vercel 的 "Ignore Build Step" 逻辑

根据 Vercel 官方说明：
- **退出码 1** → **需要新构建**（Build needed）
- **退出码 0** → **不需要构建**（Skip build）

**注意**：如果禁用了 "Ignore Build Step" 或命令返回 0，Vercel 会显示 "Ignored Build Step"，并且如果该 SHA 之前已部署过，不会触发新构建。

#### 正确的配置

**Frontend 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
```

**逻辑说明**：
- `grep -q "^frontend/"` 找到文件时返回 0，没找到时返回非0
- `&& exit 1`：找到 frontend 文件时退出码为 1 → **需要构建** ✅
- `|| exit 0`：没找到 frontend 文件时退出码为 0 → **跳过构建** ✅

**Admin 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && exit 1 || exit 0
```

**Service 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && exit 1 || exit 0
```

#### 更清晰的版本（推荐）

**Frontend 项目：**
```bash
if git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/"; then
  exit 1  # 有 frontend 文件变化，需要构建
else
  exit 0  # 没有 frontend 文件变化，跳过构建
fi
```

所以正确的配置应该是：

**Frontend 项目：**
```bash
# 如果有 frontend 文件变化，返回非0（构建）
# 如果没有变化，返回0（跳过）
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
```

或者使用更可靠的方式：
```bash
# 检查当前提交中是否有 frontend 文件
if git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/"; then
  exit 1  # 有变化，需要构建
else
  exit 0  # 无变化，跳过构建
fi
```

### 3. 检查构建日志

访问 Vercel Dashboard → 项目 → Deployments → 点击失败的部署

查看日志中的错误信息：
- 依赖安装错误
- 构建命令错误
- TypeScript 编译错误
- 环境变量缺失

### 4. 检查环境变量

访问 Vercel Dashboard → 项目 → Settings → Environment Variables

确认以下环境变量已设置：

```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
```

### 5. 测试本地构建

在本地测试构建是否正常：

```bash
cd frontend
npm install
npm run build
```

如果本地构建失败，需要先修复构建错误。

## 解决方案

### 方案 0：修复 vercel.json 路由语法（如果看到 "Invalid route source pattern" 错误）

**问题**：`vercel.json` 中使用了正则表达式语法，但 Vercel 要求使用 path-to-regexp 语法。

**修复步骤**：

1. **检查 vercel.json 文件**
   - 查找所有使用 `(.*)` 的地方
   - 查找所有使用 `\\.` 转义的地方

2. **修复语法**
   - `(.*)` → `:path*`
   - `\\.` → `.` 或使用 path-to-regexp 语法
   - destination 中的 `$1` → `:path*`

3. **示例修复**：

```json
// ❌ 错误
{
  "source": "/static/(.*\\.(js|css|png))",
  "destination": "/static/$1"
}

// ✅ 正确
{
  "source": "/static/:path*",
  "destination": "/static/:path*"
}
```

```json
// ❌ 错误
{
  "source": "/api/(.*)",
  "destination": "https://api.example.com/api/$1"
}

// ✅ 正确
{
  "source": "/api/:path*",
  "destination": "https://api.example.com/api/:path*"
}
```

4. **验证修复**
   - 提交更改
   - 查看 Vercel 部署日志，确认不再有 "Invalid route source pattern" 错误

### 方案 1：修复 "Ignore Build Step" 配置

#### ⚠️ 重要：配置差异问题

如果你看到 "Configuration Settings in the current Production deployment differ from your current Project Settings"，说明：
- **Production Overrides**：当前生产环境使用的配置
- **Project Settings**：项目设置中的配置

**解决方法**：
1. 检查 Production Overrides 和 Project Settings 的差异
2. 确保两者一致，或者使用 Project Settings 覆盖 Production Overrides

#### 步骤 1：检查配置差异

访问 Vercel Dashboard → 项目 → Settings → General

查看是否有 "Production Overrides" 警告，如果有：
1. 点击查看差异详情
2. 确认哪些配置不一致（Root Directory、Build Command、Output Directory 等）
3. 统一配置

#### 步骤 2：使用正确的 "Ignore Build Step" 命令

**Frontend 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
```

或者更清晰的版本：
```bash
if git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/"; then
  exit 1  # 有 frontend 文件变化，需要构建
else
  exit 0  # 没有 frontend 文件变化，跳过构建
fi
```

**Admin 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && exit 1 || exit 0
```

**Service 项目：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && exit 1 || exit 0
```

**逻辑说明**：
- Vercel 逻辑：退出码 1 = 需要构建，退出码 0 = 跳过构建
- `grep -q "^frontend/"` 找到文件时返回 0，没找到时返回非0
- `&& exit 1`：找到文件时退出码为 1 → **需要构建** ✅
- `|| exit 0`：没找到文件时退出码为 0 → **跳过构建** ✅

#### 步骤 3：临时测试（如果仍有问题）

1. 访问 Vercel Dashboard → 项目 → Settings → Git
2. 找到 "Ignore Build Step" 选项
3. **暂时清空命令框**（禁用 Ignore Build Step）
4. 注意：清空后，如果该 SHA 之前已部署过，Vercel 会显示 "Ignored Build Step" 且不会构建
5. 手动触发一次部署测试（Redeploy）
6. 如果构建成功，说明问题在 "Ignore Build Step" 配置

### 方案 2：检查并修复项目配置

1. **确认 Root Directory**
   - Frontend 项目：`frontend`
   - Admin 项目：`admin`
   - Service 项目：`service`

2. **确认 Build Command**
   - 所有项目都应该是：`npm run build`

3. **确认 Output Directory**
   - 所有项目都应该是：`build`

### 方案 3：手动触发部署测试

1. 访问 Vercel Dashboard → 项目 → Deployments
2. 点击右上角的 **"Redeploy"** 按钮
3. 选择最新的提交
4. 点击 **"Redeploy"**
5. 查看构建日志，找出具体错误

### 方案 4：检查 GitHub 集成

1. 访问 Vercel Dashboard → 项目 → Settings → Git
2. 确认 GitHub 仓库连接正常
3. 检查是否有权限问题
4. 如果需要，重新连接 GitHub 仓库

## 推荐的最终配置

### Frontend 项目（link2ur）

**Settings → General:**
- Root Directory: `frontend`
- Build Command: `npm run build`
- Output Directory: `build`
- Install Command: `npm install`

**Settings → Git → Ignore Build Step:**
```bash
if git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/"; then
  exit 1  # 有 frontend 文件变化，需要构建
else
  exit 0  # 没有 frontend 文件变化，跳过构建
fi
```

**或者简化版本：**
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
```

**Settings → Environment Variables:**
```
REACT_APP_API_URL=https://api.link2ur.com
REACT_APP_WS_URL=wss://api.link2ur.com
REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
```

## 验证步骤

### 1. 测试 "Ignore Build Step" 命令

在本地测试命令：

```bash
# 测试 frontend 命令
cd /path/to/repo
if git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/"; then
  echo "Exit code: 1 (需要构建)"
  exit 1
else
  echo "Exit code: 0 (跳过构建)"
  exit 0
fi
```

**验证逻辑**：
- 如果当前提交有 frontend 文件变化 → 应该返回退出码 1（需要构建）
- 如果没有 frontend 文件变化 → 应该返回退出码 0（跳过构建）

### 2. 创建测试提交

```bash
# 只修改 frontend 文件
echo "test" >> frontend/test.txt
git add frontend/test.txt
git commit -m "test: frontend only"
git push
```

然后检查 Vercel：
- Frontend 项目应该构建 ✅
- Admin 和 Service 项目应该跳过 ⏭️

### 3. 检查构建日志

访问 Vercel Dashboard → Deployments → 查看最新部署的日志

确认：
- 构建过程正常
- 没有错误信息
- 部署成功

## 常见错误和解决方法

### 错误 0：配置差异警告

**症状**：看到 "Configuration Settings in the current Production deployment differ from your current Project Settings"

**原因**：
- Production Overrides（生产环境覆盖）和 Project Settings（项目设置）不一致
- 可能是之前手动部署时使用了不同的配置

**解决方法**：
1. 访问 Vercel Dashboard → 项目 → Settings → General
2. 查看 "Production Overrides" 和 "Project Settings" 的差异
3. 统一配置：
   - 确保 Root Directory 一致
   - 确保 Build Command 一致
   - 确保 Output Directory 一致
4. 如果需要，使用 Project Settings 覆盖 Production Overrides
5. 重新部署以应用新配置

### 错误 1：Build Command 失败

**症状**：日志显示 `npm run build` 失败

**解决方法**：
1. 在本地运行 `npm run build` 测试
2. 检查 TypeScript 错误
3. 检查依赖是否正确安装
4. 检查环境变量是否设置

### 错误 2：找不到 package.json

**症状**：日志显示 `package.json not found`

**解决方法**：
1. 确认 Root Directory 设置为 `frontend`（不是根目录）
2. 确认 `frontend/package.json` 文件存在

### 错误 3：输出目录不存在

**症状**：日志显示 `Output Directory "build" not found`

**解决方法**：
1. 确认 Build Command 是 `npm run build`
2. 确认 `package.json` 中的 build 脚本正确
3. 检查构建是否真的生成了 `build` 目录

### 错误 4：环境变量未定义

**症状**：构建成功但运行时出错，提示环境变量未定义

**解决方法**：
1. 在 Vercel Dashboard 中设置所有必需的环境变量
2. 确认环境变量名称正确（`REACT_APP_` 前缀）
3. 重新部署

### 错误 5：显示 "Ignored Build Step" 但未构建

**症状**：禁用了 "Ignore Build Step" 或命令返回 0，Vercel 显示 "Ignored Build Step"，但没有构建

**原因**：
- Vercel 会检查 SHA，如果该 SHA 之前已部署过，不会触发新构建
- 这是 Vercel 的正常行为，用于避免重复构建相同的提交

**解决方法**：
1. 如果需要强制构建，使用 "Redeploy" 功能
2. 或者创建一个新的提交（即使是很小的改动）
3. 或者修改 "Ignore Build Step" 命令，确保在有相关文件变化时返回退出码 1

## 快速修复清单

- [ ] 检查 Vercel 项目 Root Directory 设置
- [ ] 检查 Build Command 和 Output Directory
- [ ] 修复 "Ignore Build Step" 配置
- [ ] 设置所有必需的环境变量
- [ ] 在本地测试构建
- [ ] 手动触发一次部署测试
- [ ] 查看构建日志找出具体错误
- [ ] 如果问题持续，临时禁用 "Ignore Build Step" 测试

## 联系支持

如果以上方法都无法解决问题：

1. 查看 Vercel 构建日志的完整错误信息
2. 检查 Vercel Status 页面（https://vercel-status.com）
3. 联系 Vercel 支持（support@vercel.com）

## 总结

### 关键要点

1. **Vercel "Ignore Build Step" 逻辑**：
   - 退出码 **1** → **需要构建**（Build needed）
   - 退出码 **0** → **跳过构建**（Skip build）

2. **配置差异问题**：
   - 如果看到 "Configuration Settings differ" 警告，需要统一 Production Overrides 和 Project Settings
   - 确保 Root Directory、Build Command、Output Directory 一致

3. **正确的 "Ignore Build Step" 配置**：
   ```bash
   git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
   ```
   - 有 frontend 文件变化 → 返回 1 → 构建 ✅
   - 没有 frontend 文件变化 → 返回 0 → 跳过 ✅

4. **"Ignored Build Step" 显示**：
   - 如果禁用了 "Ignore Build Step" 或命令返回 0，Vercel 会显示 "Ignored Build Step"
   - 如果该 SHA 之前已部署过，不会触发新构建（这是正常行为）
   - 需要强制构建时，使用 "Redeploy" 功能

### 如果问题仍然存在

1. 检查 Production Overrides 和 Project Settings 是否一致
2. 查看完整的构建日志找出具体错误
3. 在本地测试构建命令：`cd frontend && npm run build`
4. 临时禁用 "Ignore Build Step" 测试构建是否正常
5. 使用 "Redeploy" 功能手动触发构建
