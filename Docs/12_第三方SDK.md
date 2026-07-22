# 第三方 SDK

## 当前依赖

| SDK/库 | 接入方式 | 用途 |
| --- | --- | --- |
| Firebase | Swift Package Manager | 初始化、Analytics、Auth、Storage、Crashlytics 等 |
| SolarEngine 海外版 1.3.2 | CocoaPods `SolarEngineSDKiOSInter` | 事件分析、广告归因、IAP、Deep Link、ATT |
| StoreKit | 系统框架 | Apple IAP |

安装或更新 CocoaPods 依赖后，应从 `iPxavno.xcworkspace` 打开和构建工程，而不是直接打开 `.xcodeproj`。`Pods/` 不提交，`Podfile`、`Podfile.lock` 与 workspace 需要提交。

## SolarEngine 配置

AppKey 通过 Xcode Target 的 User-Defined Build Setting `SOLAR_ENGINE_APP_KEY` 注入，Debug 和 Release 可分别设置；代码库不保存正式密钥。有效 AppKey 必须是 16 位，空值时 SDK 会保持关闭：

```text
SOLAR_ENGINE_APP_KEY = 待提供的16位AppKey
```

`Info.plist` 中还定义了：

| Key | 默认值 | 说明 |
| --- | --- | --- |
| `SolarEngineATTWaitingInterval` | `60` | SDK 等待 ATT 结果的秒数，代码限制为 0...120 |
| `SolarEngineGDPRArea` | `false` | GDPR 地区发布或按地区构建时设为 `true` |
| `SolarEngineEnableODMInfo` | `false` | 海外 SDK 的 ODM 信息采集开关，默认关闭 |
| `NSUserTrackingUsageDescription` | 英文用途说明 | iOS ATT 系统弹窗文案 |

## 隐私、ATT 与归因时序

1. App 启动只调用 `preInit`；没有 AppKey 时不调用 SDK。
2. 首次进入展示 App 自有的分析/广告归因同意框，拒绝不影响核心功能。
3. 用户同意后才注册归因与初始化回调并启动 SDK。
4. App 活跃时通过 SolarEngine 包装方法请求系统 ATT；归因回调在初始化前注册。
5. 登录/退出同步 SolarEngine Account ID，URL 与 Universal Link 交给 SDK 处理 Deep Link 归因。

SDK 自带 `PrivacyInfo.xcprivacy`。上线前仍需根据实际数据用途更新隐私政策、App Store App Privacy，并确认 GDPR 地区配置与 ATT 文案经过法务/产品审核。

## 事件约束

- 业务只调用统一 `AnalyticsTracking`，不直接依赖 SolarEngine SDK。
- 自定义事件采用小写下划线，长度不超过 40；属性 key 不以下划线开头。
- 禁止上报密码、token、receipt、授权 Header、邮箱、手机号和用户输入。
- SolarEngine 自动采集关闭，由统一框架提供页面和点击事件，避免重复计数。
