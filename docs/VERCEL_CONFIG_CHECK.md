# Vercel 配置检查清单

## 项目配置验证

### ✅ Frontend 项目

**package.json**:
- ✅ 有 `build` 脚本: `"build": "react-scripts build"`
- ✅ 输出目录: `build` (react-scripts 默认)

**vercel.json**:
- ✅ 定义了 `builds` 配置
- ✅ `distDir: "build"` 正确
- ✅ 使用 `@vercel/static-build`

**状态**: ✅ 配置正确，不会出现 "Missing public directory" 或 "Missing build script" 错误

### ✅ Admin 项目

**package.json**:
- ✅ 有 `build` 脚本: `"build": "react-scripts build"`
- ✅ 输出目录: `build` (react-scripts 默认)

**vercel.json**:
- ✅ 定义了 `builds` 配置
- ✅ `distDir: "build"` 正确
- ✅ 使用 `@vercel/static-build`

**状态**: ✅ 配置正确

### ✅ Service 项目

**package.json**:
- ✅ 有 `build` 脚本: `"build": "react-scripts build"`
- ✅ 输出目录: `build` (react-scripts 默认)

**vercel.json**:
- ✅ 定义了 `builds` 配置
- ✅ `distDir: "build"` 正确
- ✅ 使用 `@vercel/static-build`

**状态**: ✅ 配置正确

## 常见错误检查

### 1. Missing public directory ✅

**检查结果**: 所有项目都正确配置了输出目录

- Frontend: `distDir: "build"` ✅
- Admin: `distDir: "build"` ✅
- Service: `distDir: "build"` ✅

**react-scripts build** 会自动创建 `build` 目录，所以不会出现此错误。

### 2. Missing build script ✅

**检查结果**: 所有项目都有 build 脚本

- Frontend: `"build": "react-scripts build"` ✅
- Admin: `"build": "react-scripts build"` ✅
- Service: `"build": "react-scripts build"` ✅

### 3. Unused build and development settings ⚠️

**说明**: 由于所有项目都在 `vercel.json` 中定义了 `builds` 配置，Vercel Dashboard 中的 "Build & Development Settings" 会被忽略。

**这是正常的**，因为：
- `vercel.json` 中的配置优先级更高
- 配置已经在 `vercel.json` 中明确定义

**如果需要修改构建配置**，请直接编辑 `vercel.json`，而不是在 Dashboard 中修改。

### 4. Invalid route source pattern ✅

**检查结果**: 所有路由配置都使用了正确的 path-to-regexp 语法

**示例**（frontend/vercel.json）:
```json
{
  "source": "/(.*)",
  "destination": "/en/$1"
}
```

✅ 语法正确，不会出现 "Invalid route source pattern" 错误。

## Vercel Dashboard 设置建议

### Frontend 项目设置

在 Vercel Dashboard 中，建议配置：

1. **Root Directory**: `frontend`
2. **Build Command**: (留空，使用 package.json 中的脚本)
3. **Output Directory**: (留空，使用 vercel.json 中的 distDir)
4. **Install Command**: `npm ci` (可选，默认是 `npm install`)

**注意**: 由于 `vercel.json` 中定义了 `builds`，这些设置会被忽略，但建议保持一致。

### Admin 项目设置

1. **Root Directory**: `admin`
2. **Build Command**: (留空)
3. **Output Directory**: (留空)
4. **Install Command**: `npm ci`

### Service 项目设置

1. **Root Directory**: `service`
2. **Build Command**: (留空)
3. **Output Directory**: (留空)
4. **Install Command**: `npm ci`

## Ignore Build Step 配置

每个项目都应该配置 "Ignore Build Step"：

### Frontend
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && exit 1 || exit 0
```

### Admin
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && exit 1 || exit 0
```

### Service
```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && exit 1 || exit 0
```

## 环境变量配置

确保在 Vercel Dashboard 中为每个项目配置了必要的环境变量：

### Frontend
- `REACT_APP_API_URL` = `https://api.link2ur.com`
- `REACT_APP_WS_URL` = `wss://api.link2ur.com`
- `REACT_APP_MAIN_SITE_URL` = `https://www.link2ur.com`

### Admin
- `REACT_APP_API_URL` = `https://api.link2ur.com`
- `REACT_APP_WS_URL` = `wss://api.link2ur.com`
- `REACT_APP_MAIN_SITE_URL` = `https://www.link2ur.com`

### Service
- `REACT_APP_API_URL` = `https://api.link2ur.com`
- `REACT_APP_WS_URL` = `wss://api.link2ur.com`
- `REACT_APP_MAIN_SITE_URL` = `https://www.link2ur.com`

**注意**: `vercel.json` 中的 `env` 配置只用于本地开发，生产环境需要在 Dashboard 中配置。

## 总结

✅ **所有项目配置都正确**，不会出现以下错误：
- ❌ Missing public directory
- ❌ Missing build script
- ❌ Invalid route source pattern

⚠️ **注意事项**:
- Build & Development Settings 会被 `vercel.json` 中的 `builds` 配置覆盖（这是正常的）
- 环境变量需要在 Vercel Dashboard 中单独配置
- Ignore Build Step 需要正确配置以避免不必要的构建

## 如果遇到部署错误

1. **检查构建日志**: 查看 Vercel 部署日志中的具体错误信息
2. **本地测试**: 运行 `npm run build` 确保本地构建成功
3. **检查环境变量**: 确保所有必需的环境变量都已配置
4. **检查 Ignore Build Step**: 确保命令逻辑正确
5. **检查 Root Directory**: 确保在 Vercel Dashboard 中设置了正确的根目录
