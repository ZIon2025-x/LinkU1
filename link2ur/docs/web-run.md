# Flutter Web 运行说明

## 问题：Chrome 启动失败

若出现 `Failed to launch browser after 3 tries`，说明 Flutter 无法自动拉起 Chrome，可按下述方式处理。

## 方案一：使用 web-server 模式（推荐）

不自动打开浏览器，由本机启动一个本地服务，你手动在 Chrome 或 Edge 里打开地址：

```powershell
cd link2ur
flutter run -d web-server
```

终端会输出类似：

```
Launching lib/main.dart on Web Server in debug mode...
Building application for the web...
Serving web on http://localhost:xxxxx
```

在浏览器中打开该 `http://localhost:xxxxx` 即可。热重载照常可用。

## 方案二：指定 Chrome/Edge 路径

若希望 `flutter run -d chrome` 能自动打开浏览器，可设置 Chrome 或 Edge 可执行文件路径。

**PowerShell（当前会话）：**

```powershell
# 使用 Chrome（按本机实际路径修改）
$env:CHROME_EXECUTABLE = "C:\Program Files\Google\Chrome\Application\chrome.exe"

# 或使用 Edge
$env:CHROME_EXECUTABLE = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

cd link2ur
flutter run -d chrome
```

**长期生效：** 在 Windows 中为“用户环境变量”添加 `CHROME_EXECUTABLE`，值为上述路径之一。

## 方案三：直接用 Edge 设备

若已安装 Edge，可指定 Edge 设备运行（Flutter 会尝试用 Edge 代替 Chrome）：

```powershell
flutter run -d edge
```

若仍失败，改用方案一 `-d web-server` 最稳妥。
