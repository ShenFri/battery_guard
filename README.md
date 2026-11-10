# Battery Guard(iOS 电量检测与优化 · 初稿)

Flutter 工程,可在 Windows 上开发,iOS 打包走云端 Mac(Codemagic)。

## 功能
- 实时电量环、充电 / 放电 / 充满状态
- 低电量模式状态
- 设备热状态(通过 Swift 原生通道读取 `ProcessInfo.thermalState`)
- 近 24 小时电量曲线(本地存储,App 运行期间每分钟采样)
- 根据当前状态给出省电建议;可自定义"充电上限 / 低电量"本地通知提醒

## iOS 的能力边界(重要)
- 无法读取电池健康度、循环次数、其他 App 的耗电量
- 无法清理后台进程或"一键优化"
- App 被系统挂起后无法持续采样与提醒,历史曲线只包含 App 运行时段
  (想做后台采样需要研究 Background Tasks,但系统不保证执行频率)
- 宣传时避免"一键加速/清理"之类表述,App Store 审核会拒绝

## 一、Windows 环境准备
1. 安装 Flutter SDK(https://docs.flutter.dev/get-started/install/windows),把 `flutter\bin` 加入 PATH
2. 安装 VS Code + Flutter 插件;安装 Git
3. `flutter doctor` 检查(iOS 相关项在 Windows 显示为不可用属正常)

## 二、初始化工程(只需一次)
在本目录的**上一级**执行,让 Flutter 生成 `ios/` 目录:

```bash
cd battery_guard
flutter create . --platforms=ios --org com.example --project-name battery_guard
flutter pub get
```

然后:
1. 用 `ios_native/AppDelegate.swift` **覆盖** `ios/Runner/AppDelegate.swift`
2. 打开 `ios/Podfile`,确认顶部为 `platform :ios, '13.0'`(或更高)
3. 在 `ios/Runner/Info.plist` 中无需额外权限(本地通知权限由运行时弹窗申请)

## 三、开发与调试
- Windows 上无法运行 iOS 模拟器。UI 调试可用 Chrome / Windows 桌面:`flutter run -d chrome`
  (电量读取与热状态在非 iOS 会降级,界面仍可预览)
- 真机验证:通过 Codemagic 构建后用 TestFlight 安装到 iPhone

## 四、云端构建并上架
1. 注册 Apple Developer 账号(99 美元/年)
2. 在 App Store Connect 创建 App,拿到 Bundle ID;生成 App Store Connect API Key
3. 代码推到 GitHub,在 https://codemagic.io 关联仓库
4. 在 Codemagic 的 Integrations 添加 API Key,名称与 `codemagic.yaml` 中的 `BatteryGuardKey` 保持一致
5. 修改 `codemagic.yaml` 里的 `bundle_identifier`,触发构建,产物会自动上传 TestFlight

## 目录
```
lib/
  main.dart
  theme.dart                    深色主题与配色
  screens/home_screen.dart      主界面、提醒逻辑、建议
  services/battery_service.dart 电量 / 低电量模式 / 热状态
  services/history_store.dart   24h 历史存储
  services/notification_service.dart 本地通知
  widgets/battery_ring.dart     渐变发光电量环
ios_native/AppDelegate.swift    热状态原生通道
codemagic.yaml                  云构建配置
```

## 后续迭代建议
充电速度估算、桌面小组件(WidgetKit)、Live Activity 显示充电进度、App 图标与启动页、隐私政策页面(上架必需)。
