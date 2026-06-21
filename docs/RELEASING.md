# 移动端自动发布

推送形如 `v1.2.3` 的 Git Tag 后，`.github/workflows/release.yml` 会分别构建
已签名的 Android APK 和 iOS IPA，并将两个文件添加到同一个 GitHub Release。
只有 Android 和 iOS 都构建成功，工作流才会创建 Release。

## 前置条件

- Android：需要自己长期保管的 JKS 签名密钥。
- iOS：需要加入 Apple Developer Program，并准备 Apple Distribution 证书、
  Provisioning Profile 和 Xcode 导出的 `ExportOptions.plist`。
- GitHub：需要将上述文件和密码保存为 Repository Actions Secrets。

证书和私钥不能提交到 Git 仓库。`.gitignore` 已排除常见签名文件。

## 配置 GitHub Secrets

进入 GitHub 仓库的 **Settings > Secrets and variables > Actions**，选择
**New repository secret**，逐项添加以下配置。

### Android 签名

需要添加四个 Secrets：

- `ANDROID_KEYSTORE_BASE64`：JKS 文件经过 Base64 编码后的内容。
- `ANDROID_KEY_ALIAS`：生成密钥时指定的别名。
- `ANDROID_KEY_PASSWORD`：密钥密码。
- `ANDROID_STORE_PASSWORD`：JKS 密钥库密码。

在 macOS 上生成一个新的长期发布密钥：

```bash
keytool -genkeypair -v \
  -keystore release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias wakareeru
```

命令会询问密钥库密码、姓名和组织等信息。生成后，将文件转换为可粘贴到
GitHub Secret 的单行 Base64 文本：

```bash
base64 -i release.jks | tr -d '\n' | pbcopy
```

将剪贴板内容保存为 `ANDROID_KEYSTORE_BASE64`。`release.jks`、别名和两个
密码必须另外保存在密码管理器中。丢失密钥后，将无法继续更新使用该密钥签名的
Android 应用。

### iOS 签名

需要添加五个 Secrets：

- `IOS_CERTIFICATE_BASE64`：Apple Distribution `.p12` 文件的 Base64 内容。
- `IOS_CERTIFICATE_PASSWORD`：从钥匙串导出 `.p12` 时设置的密码。
- `IOS_PROVISION_PROFILE_BASE64`：与 `com.wakareeru.app` 对应的
  `.mobileprovision` 文件的 Base64 内容。
- `IOS_EXPORT_OPTIONS_PLIST_BASE64`：Xcode 导出的 `ExportOptions.plist`
  的 Base64 内容。
- `IOS_KEYCHAIN_PASSWORD`：CI 临时钥匙串使用的随机强密码，不需要对应现有账号密码。

证书、Profile、Xcode 项目里的 Team 和 Bundle Identifier 必须属于同一个
Apple Developer Team。当前 Bundle Identifier 是 `com.wakareeru.app`。

准备好文件后，在 macOS 上分别编码并保存到对应 Secret：

```bash
base64 -i distribution.p12 | tr -d '\n' | pbcopy
base64 -i Wakareeru.mobileprovision | tr -d '\n' | pbcopy
base64 -i ExportOptions.plist | tr -d '\n' | pbcopy
```

Profile 和 `ExportOptions.plist` 的分发方式应保持一致：

- 上传 TestFlight/App Store：使用 App Store Connect Distribution。
- 给已登记 UDID 的设备直接安装：使用 Ad Hoc Distribution。

App Store Connect 签名的 IPA 可以上传到 App Store Connect，但不能直接从
GitHub Release 安装到普通 iPhone。iOS 不存在类似 Android APK 的任意安装方式。

## 发布新版本

先运行检查和测试，再创建语义化版本 Tag：

```bash
flutter analyze
flutter test
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Tag 中的 `1.2.3` 会成为应用版本号，GitHub Actions 的递增运行编号会成为
构建号。进入 GitHub 仓库的 **Actions** 页面可以查看构建进度和失败日志。

当前工作流只创建 GitHub Release 并上传 APK/IPA，不会自动提交 Google Play
或 App Store Connect。
