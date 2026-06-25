# Pixnova 重构交接文档索引

> 说明：本文档由当前 iOS 工程代码反向梳理而来，重点记录“后端不变时，新工程必须继续兼容的契约与流程”。文档不包含规避平台审核或绕过封禁的做法；重构时请以合规的新产品定位、界面、文案、素材、隐私披露和能力边界重新设计。

## 文档列表

- [01-网络接口与错误码契约](./01-network-contract.md)
- [02-AI 制作统一工作流](./02-generation-workflow.md)
- [03-Filter 模块工作流](./03-filter-module.md)
- [04-首页与内容数据源](./04-homepage-datasource.md)
- [05-账户、会员、IAP 与钻石](./05-account-iap-diamonds.md)
- [06-个人中心、历史作品、奖励与邀请](./06-history-reward-invite.md)
- [07-新产品重构保留清单](./07-rebuild-preserve-checklist.md)

## 当前工程核心架构

- App 类型：SwiftUI + UIKit 混合 iOS App。
- 网络层：Moya 封装在 `Pixnova/BasicBundle/Network`，特殊接口包括 Gemini SSE、Firebase Storage 上传、OSS 签名 URL + PUT 上传、Apple IAP 支付域名。
- 数据模型：ObjectMapper 映射，主要模型在 `Pixnova/DataSource/Model`、`Account`、`MineViewModel`、`RewardModels`。
- AI 制作：所有图片/视频/滤镜/头像/Baby/视频增强大多复用 `UploadModel` + `UploadManager` + `UploadTask` + `UploadPage`。
- 本地持久化：UserDefaults 保存账号、缓存数据、引导状态、任务状态；FMDB 保存作品任务与原图本地关联；Documents 保存原图文件。

## 重构原则

- 后端字段、路径、错误码、鉴权 header、任务轮询方式应保持兼容。
- 产品外观、包名、品牌、文案、素材、功能叙事、隐私说明、审核信息应做成真实的新产品，而不是简单替换壳。
- 支付、订阅、钻石、权益、邀请、任务奖励等涉及用户资产的逻辑应优先回归测试。
- 新工程应显式梳理第三方 SDK 和隐私权限，避免继承无关或高风险的老代码。
