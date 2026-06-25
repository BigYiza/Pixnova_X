# 第三方 SDK

## SDK 清单

| SDK/库 | 用途 |
| --- | --- |
| Firebase Core | Firebase 初始化 |
| Firebase RemoteConfig | 远程配置 |
| Firebase Storage | 图片上传 |
| Firebase Messaging | FCM 推送 |
| Firebase Analytics | 埋点 |
| AppsFlyer | 归因和购买事件 |
| SolarEngine | 归因、ATT、Remote Config |
| TikTok Business SDK | 广告归因/事件 |
| FacebookCore | Facebook 初始化/跳转支持 |
| Moya | 网络请求 |
| Alamofire | Reachability |
| ObjectMapper | JSON 模型映射 |
| Kingfisher | 图片下载缓存 |
| ToastUI | SwiftUI toast |
| SnapKit | UIKit 约束 |
| Lottie | Gemini loading |
| APNGKit | APNG 动画 |
| FMDB / SQLite3 | 本地数据库 |
| Down | Markdown 渲染 |
| YYText | 富文本和图片 attachment |
| StoreKit | Apple IAP |

## 初始化位置

| SDK | 初始化 |
| --- | --- |
| Firebase | `LaunchConfig.firebaseConfigure()` |
| AppsFlyer | `LaunchConfig.appsFlyerConfigure()` |
| SolarEngine | `LaunchConfig.InitSolarEngine()` |
| TikTok | `LaunchConfig.initTikTok()` |
| Facebook | `AppDelegate.didFinishLaunching` |
| FCM | `AppDelegate.registerNotification()` |

## 当前硬编码标识

| 项 | 值 |
| --- | --- |
| AppsFlyer DevKey | `2o84PsQnbv9B6FSjXibMeJ` |
| Apple App ID | `6695729339` |
| SolarEngine AppKey | `3afd5a68e1f2b3a4` |
| TikTok appId | `6695729339` |
| TikTok tiktokAppId | `7425241391091040274` |
| CodoonAnalytics APP_ID | `pixnova` |

新产品应重新申请/替换这些标识，避免数据混淆和合规风险。

## ATT

当前：

- AppsFlyer 等待 ATT 60 秒。
- SolarEngine 请求 ATT。
- 授权后把 IDFA 写入 CodoonAnalytics preset properties。

新工程需要：

- 明确 ATT 弹窗触发时机。
- 隐私说明中披露追踪用途。
- 用户拒绝时功能不应受阻。

## 移除建议

新产品如果不需要：

- Facebook 社交跳转。
- TikTok Business。
- SolarEngine。
- 自研埋点。
- Gemini Markdown/YYText。

应直接移除，减少包体、隐私项和审核解释成本。
