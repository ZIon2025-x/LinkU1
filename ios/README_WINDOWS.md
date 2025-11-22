# Windows 用户指南

## 📋 快速参考

### ✅ 在 Windows 上可以做什么

1. **测试后端 API**
   ```bash
   # 运行 API 测试脚本
   python test_api.py
   ```

2. **测试 WebSocket 连接**
   - 打开 `test_websocket.html` 在浏览器中测试

3. **检查代码**
   - 检查 Swift 文件语法
   - 检查项目结构
   - 检查 API 端点配置

4. **准备测试数据**
   - 准备测试账号
   - 准备测试数据

### ❌ 在 Windows 上无法做什么

- ❌ 运行 Xcode
- ❌ 运行 iOS 模拟器
- ❌ 编译 iOS 应用
- ❌ 调试 iOS 应用

## 🛠️ 测试步骤

### 1. 测试 API（推荐先做）

```bash
# 安装依赖
pip install requests

# 编辑 test_api.py，更新 API 地址和测试账号
# 然后运行
python test_api.py
```

### 2. 测试 WebSocket

1. 打开 `test_websocket.html` 文件
2. 输入 WebSocket URL 和用户ID
3. 点击"连接"测试连接
4. 发送测试消息

### 3. 检查代码

- 检查所有 Swift 文件是否存在
- 检查 API 端点路径是否正确
- 检查数据模型是否匹配后端

## 📱 实际测试 iOS 应用

要实际测试 iOS 应用，你需要：

1. **macOS 环境**（必需）
   - 真实 Mac 电脑
   - macOS 虚拟机（需要合法授权）
   - 云端 macOS 服务（MacStadium 等）

2. **Xcode**
   - 在 macOS 上安装 Xcode
   - 打开项目
   - 运行模拟器或真机

## 💡 建议

1. **先在 Windows 上测试 API**，确保后端正常工作
2. **检查代码逻辑**，减少在 Mac 上的调试时间
3. **准备测试计划**，提高测试效率
4. **使用云服务或虚拟机**进行 iOS 应用测试

## 📚 相关文档

- [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md) - 详细测试指南
- [SETUP.md](SETUP.md) - Xcode 设置指南（需要 macOS）
- [QUICK_START.md](QUICK_START.md) - 快速开始（需要 macOS）

