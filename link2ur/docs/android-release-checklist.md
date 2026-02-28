# Android 发布清单

发布或上架 Android 前按本清单逐项完成。涉及密码与密钥的步骤需你本机执行，不能由他人代填。

---

## 一、Release 签名（上架或对外发正式包必做）

### 1. 生成 keystore（只需做一次）

在终端进入 `link2ur/android` 目录，执行：

```powershell
cd link2ur/android
keytool -genkey -v -keystore link2ur-release.keystore -alias link2ur -keyalg RSA -keysize 2048 -validity 10000
```

按提示输入 keystore 密码、key 密码、姓名/组织等。生成后得到 `link2ur-release.keystore`，放在 `link2ur/android/` 下（不要提交到 Git，已由 `.gitignore` 排除）。

### 2. 创建 keystore.properties

在 `link2ur/android/` 下新建 `keystore.properties`（不要提交，已忽略），内容：

```properties
storePassword=你的_keystore_密码
keyPassword=你的_key_密码
keyAlias=link2ur
storeFile=link2ur-release.keystore
```

若 keystore 放在 `android/` 上一级目录，则 `storeFile=../link2ur-release.keystore`。

### 3. 验证签名

在 `link2ur/` 下执行（测试公钥即可验证构建是否用 release 签名）：

```powershell
flutter build appbundle --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx
```

成功则得到 `build/app/outputs/bundle/release/app-release.aab`。

---

## 二、正式构建时传入的密钥（dart-define）

正式包构建需在命令中传入（勿写进仓库或提交）：

| 参数 | 用途 |
|------|------|
| `STRIPE_PUBLISHABLE_KEY_LIVE` | 正式 Stripe 支付（Stripe Dashboard → 正式公钥 pk_live_xxx） |
| `MOBILE_APP_SECRET` | 与后端一致的移动端签名密钥 |

示例（在 `link2ur/` 下）。一行写法（PowerShell / cmd 通用）：

```powershell
flutter build appbundle --dart-define=STRIPE_PUBLISHABLE_KEY_LIVE=pk_live_你的正式公钥 --dart-define=MOBILE_APP_SECRET=与后端一致的密钥
```

PowerShell 多行写法（行末反引号 `` ` `` 表示续行；cmd 下用 `^` 续行）：

```powershell
flutter build appbundle `
  --dart-define=STRIPE_PUBLISHABLE_KEY_LIVE=pk_live_你的正式公钥 `
  --dart-define=MOBILE_APP_SECRET=与后端一致的密钥
```

仅内测可用 `STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx`。详见 `stripe-keys-setup.md`、`mobile-app-secret.md`。

---

## 三、地图 API Key（MAPS_API_KEY）

地图选点需要 Google Maps API Key。本机在 `link2ur/android/local.properties` 中配置（该文件已 gitignore）：

```properties
MAPS_API_KEY=你的_Google_Maps_Android_API_Key
```

CI 或他人机器需在构建前生成/写入 `local.properties`（含 `sdk.dir` 与 `MAPS_API_KEY`），或从环境变量注入。

---

## 四、可选：App Links（https 链接直接打开 App）

若希望 `https://link2ur.com/...` 在浏览器中点击时直接打开 App：

1. 在 link2ur.com 提供：`https://link2ur.com/.well-known/assetlinks.json`
2. 用 release keystore 的 SHA-256 指纹生成 assetlinks 内容：
   ```powershell
   keytool -list -v -keystore link2ur/android/link2ur-release.keystore -alias link2ur
   ```
   在输出中复制 SHA256，填入 assetlinks.json 的 `sha256_cert_fingerprints`。package 名为 `com.link2ur`。

不做此项时，`link2ur://` 自定义 scheme 仍可用。

---

## 五、发布前自检

| 项目 | 完成 |
|------|------|
| 已生成 `link2ur-release.keystore` 并创建 `keystore.properties` | ☐ |
| 正式构建命令已带 `STRIPE_PUBLISHABLE_KEY_LIVE` 与 `MOBILE_APP_SECRET` | ☐ |
| 本机或 CI 已配置 `MAPS_API_KEY`（`local.properties` 或环境变量） | ☐ |
| 需要 https 直开 App 时已部署 `assetlinks.json` | ☐ |

---

## 相关文档

- 签名示例：`link2ur/android/keystore.properties.example`
- Stripe / 密钥传入方式：`link2ur/docs/stripe-keys-setup.md`
- 移动端签名：`link2ur/docs/mobile-app-secret.md`
