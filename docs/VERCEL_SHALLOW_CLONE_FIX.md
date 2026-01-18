# Vercel 浅克隆问题修复

## 问题

配置了正确的 "Ignore Build Step" 命令：
```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

但所有项目都在构建，即使只修改了其他目录的文件。

## 根本原因

Vercel 使用**浅克隆**（`--depth=1`）来克隆仓库，这可能导致：
1. `git diff --name-only HEAD` 在浅克隆中可能无法正常工作
2. `HEAD` 可能指向错误的提交
3. 命令执行失败，Vercel 默认构建所有项目

## 解决方案：使用 `git show` 代替 `git diff`

### 为什么 `git show` 更可靠？

- `git show HEAD` 只查看当前提交，不依赖历史
- 在浅克隆中也能正常工作
- 更简单，更可靠

### 正确的配置命令

#### Frontend 项目

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
```

#### Admin 项目

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" || exit 1
```

#### Service 项目

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" || exit 1
```

## 测试命令

在本地测试（模拟 Vercel 环境）：

```bash
# 测试 frontend
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" && echo "BUILD" || echo "SKIP"

# 测试 admin
git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" && echo "BUILD" || echo "SKIP"

# 测试 service
git show --name-only --pretty=format:"" HEAD | grep -q "^service/" && echo "BUILD" || echo "SKIP"
```

## 更新 Vercel 配置

### 步骤

1. **Frontend 项目**
   - 访问：`https://vercel.com/你的账户/link2ur/settings/git`
   - 找到 "Ignore Build Step"
   - 替换为：`git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1`
   - 保存

2. **Admin 项目**
   - 访问：`https://vercel.com/你的账户/link2ur-admin/settings/git`
   - 替换为：`git show --name-only --pretty=format:"" HEAD | grep -q "^admin/" || exit 1`
   - 保存

3. **Service 项目**
   - 访问：`https://vercel.com/你的账户/link2ur-cs/settings/git`
   - 替换为：`git show --name-only --pretty=format:"" HEAD | grep -q "^service/" || exit 1`
   - 保存

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
- ⏭️ Admin 应该跳过（显示 "Canceled by Ignored Build Step"）
- ⏭️ Service 应该跳过（显示 "Canceled by Ignored Build Step"）

## 命令对比

### 旧命令（可能有问题）

```bash
git diff --name-only --diff-filter=ACMRT HEAD | grep -q "^frontend/" || exit 1
```

**问题**：
- 在浅克隆中可能无法正常工作
- `git diff HEAD` 需要完整的 Git 历史

### 新命令（推荐）

```bash
git show --name-only --pretty=format:"" HEAD | grep -q "^frontend/" || exit 1
```

**优势**：
- 在浅克隆中也能正常工作
- 只查看当前提交，不依赖历史
- 更简单，更可靠

## 如果还是不行

1. **检查 Vercel 构建日志**
   - 查看 "Ignore Build Step" 的执行结果
   - 检查是否有错误信息

2. **尝试更简单的命令**
   ```bash
   # 最简版本
   git show --name-only HEAD | grep "^frontend/" > /dev/null || exit 1
   ```

3. **联系 Vercel 支持**
   - 提供构建日志
   - 说明使用的命令
   - 说明期望的行为
