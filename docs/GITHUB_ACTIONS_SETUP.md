# GitHub Actions 启用和检查指南

## 如何检查 GitHub Actions 是否已启用

### 方法 1：通过 GitHub 网页界面检查

1. **进入仓库设置**
   - 打开你的 GitHub 仓库
   - 点击仓库顶部的 **Settings**（设置）标签

2. **检查 Actions 设置**
   - 在左侧菜单中找到 **Actions** → **General**
   - 或者直接访问：`https://github.com/你的用户名/你的仓库名/settings/actions`

3. **查看 Actions permissions**
   - 在 "Actions permissions" 部分，应该看到：
     - ✅ **Allow all actions and reusable workflows**（推荐）
     - 或 **Allow local actions and reusable workflows**
     - 或 **Allow only actions created by GitHub**
   - 如果显示 **Disable Actions**，说明 Actions 被禁用了

### 方法 2：检查工作流运行历史

1. **查看 Actions 标签**
   - 在仓库顶部点击 **Actions** 标签
   - 如果能看到工作流运行历史，说明 Actions 已启用
   - 如果显示 "Workflows are disabled" 或类似提示，说明未启用

2. **检查工作流文件**
   - 确认 `.github/workflows/` 目录下有工作流文件
   - 文件格式应该是 `.yml` 或 `.yaml`

### 方法 3：通过仓库设置检查

1. **检查仓库可见性**
   - 私有仓库默认启用 Actions
   - 公开仓库需要手动启用（如果之前被禁用）

2. **检查组织/账户设置**
   - 如果是组织仓库，检查组织级别的 Actions 设置
   - 路径：组织设置 → Actions → General

## 如何启用 GitHub Actions

### 如果 Actions 被禁用：

1. **启用 Actions**
   - 进入仓库 Settings → Actions → General
   - 在 "Actions permissions" 部分，选择：
     - **Allow all actions and reusable workflows**（推荐用于 CI/CD）
   - 点击 **Save** 保存

2. **检查工作流权限**
   - 在 "Workflow permissions" 部分，选择：
     - **Read and write permissions**（如果需要推送代码）
     - 或 **Read repository contents and packages permissions**（只读，推荐）

### 如果 Actions 已启用但工作流不运行：

1. **检查工作流文件语法**
   ```bash
   # 在本地验证 YAML 语法
   yamllint .github/workflows/*.yml
   ```

2. **检查触发条件**
   - 确认文件路径匹配（`frontend/**`, `admin/**`, `service/**`）
   - 确认分支名称正确（`main`, `develop`）

3. **手动触发测试**
   - 在 GitHub Actions 页面，点击工作流名称
   - 点击右侧的 **Run workflow** 按钮
   - 选择分支并运行

4. **查看工作流日志**
   - 点击失败的工作流运行
   - 查看错误信息
   - 检查每个步骤的输出

## 常见问题排查

### 问题 1：工作流文件存在但不运行

**可能原因：**
- 文件路径不正确
- 触发条件不匹配
- YAML 语法错误

**解决方法：**
```bash
# 检查工作流文件是否存在
ls -la .github/workflows/

# 验证 YAML 语法
cat .github/workflows/frontend-admin-service-ci.yml | yamllint
```

### 问题 2：工作流运行但显示 "Skipped"

**可能原因：**
- 路径过滤导致工作流被跳过
- 没有匹配的文件变化

**解决方法：**
- 检查提交中是否包含 `frontend/`, `admin/`, `service/` 目录下的文件
- 使用 `workflow_dispatch` 手动触发测试

### 问题 3：权限错误

**可能原因：**
- 工作流权限不足
- 缺少必要的 secrets

**解决方法：**
- 在 Settings → Actions → General 中设置工作流权限
- 在 Settings → Secrets and variables → Actions 中添加必要的 secrets

## 验证 Actions 是否正常工作

### 测试步骤：

1. **创建一个测试提交**
   ```bash
   # 修改 frontend 目录下的任意文件
   echo "# Test" >> frontend/README.md
   git add frontend/README.md
   git commit -m "test: trigger frontend CI"
   git push
   ```

2. **检查 Actions 页面**
   - 进入仓库的 Actions 标签
   - 应该能看到新的工作流运行
   - 点击运行查看详细日志

3. **验证构建结果**
   - 检查构建是否成功
   - 查看是否有错误信息

## 快速检查清单

- [ ] 仓库 Settings → Actions → General 中 Actions 已启用
- [ ] `.github/workflows/` 目录存在且包含工作流文件
- [ ] 工作流文件语法正确（YAML 格式）
- [ ] 触发条件配置正确（分支、路径）
- [ ] 工作流权限设置正确
- [ ] 必要的 secrets 已配置（如果需要）
- [ ] 最近有推送到匹配的分支

## 相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [工作流语法参考](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [启用和禁用 Actions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
