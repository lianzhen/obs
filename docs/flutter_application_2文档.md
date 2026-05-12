# Flutter Application 2 — 环境配置说明（Windows）

## 一、Android SDK 与 `local.properties`

本工程 Android 构建依赖本机已安装的 **Android SDK** 与 **Flutter SDK**，路径由 `android/local.properties` 提供（此文件**勿提交**到版本库，各开发者本机不同）。

1. 安装 [Android Studio](https://developer.android.com/studio) 或仅安装 [Command-line tools](https://developer.android.com/studio#command-tools)，在 SDK Manager 中安装 **Android SDK**。
2. 在仓库中**复制** `android/local.properties.example` 为 `android/local.properties`。
3. 将 `sdk.dir` 改为你本机 Android SDK 目录（Windows 路径用 `\\` 或 `/` 转义，见示例文件内说明）。
4. 将 `flutter.sdk` 改为你本机 Flutter SDK 根目录（与下节「查询 Flutter 路径」一致）。

可选：在系统环境变量中配置 `ANDROID_HOME` 指向同一 SDK 目录，便于命令行工具使用。

---

## 二、Flutter SDK 路径配置（Cursor / VS Code）

当 Cursor / VS Code **无法识别 Flutter SDK**（分析报错、无法跳转、`Flutter: Doctor` 异常）时，可为编辑器指定 Flutter 安装路径。

### 1. 查询本机 Flutter SDK 路径

在 **PowerShell** 或 **CMD** 中执行：

```bash
where flutter
```

示例输出：

```text
D:\dev\flutter\flutter\bin\flutter
D:\dev\flutter\flutter\bin\flutter.bat
```

则 Flutter SDK 根目录为去掉 `\bin\flutter`（或 `\bin\flutter.bat`）后的路径，例如：**`D:\dev\flutter\flutter`**。

macOS / Linux 可使用：

```bash
which flutter
```

### 2. 在 Cursor 中设置 `dart.flutterSdkPath`

1. 打开 Cursor **命令面板**：`Ctrl + Shift + P`。
2. 输入并选择：**Preferences: Open User Settings (JSON)**（打开用户级 `settings.json`）。
3. 在 JSON 根对象中增加或合并如下字段（将路径换为你的 SDK 根目录，注意 JSON 转义）：

```json
{
  "dart.flutterSdkPath": "D:\\dev\\flutter\\flutter"
}
```

4. 保存后**重启 Cursor** 或执行 **Developer: Reload Window**，再运行 **Flutter: Doctor** 验证。

> **说明**：若使用**工作区级别**配置，可将同一键写入项目下的 `.vscode/settings.json`，仅在本仓库生效（路径仍为各人本机路径，团队仓库慎用提交绝对路径）。

---

## 三、验证

```bash
flutter doctor -v
flutter pub get
flutter run
```
