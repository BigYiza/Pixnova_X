# 新产品重构保留清单

> 目标：后端不变，但产品、UI、素材、文案、定位、隐私与审核表达都应重新设计。下面只列“为了继续兼容后端和用户资产，建议保留或重新实现的能力”。

## 必须保留：后端契约

- 业务域名和支付域名的环境切换。
- 统一 header：
  - `Authorization`
  - `tokenId`
  - `uid`
  - `timezone`
  - `User-Agent`
  - `device-id`
  - `Content-Type`
  - `/api/image_generation` 的 `Clt-Start`
- 统一响应解析：
  - HTTP 2xx
  - `code == 0` 成功
  - `-100` 刷 token
  - `description/desc/msg` 错误文案优先级
- 支付域名不按业务 `code` 判断的特殊逻辑。
- `/api/image_generation` 创建任务 + `/api/query_result` 轮询的制作模式。
- OSS 签名 URL + PUT 上传模式。
- Gemini SSE 独立网络通道。

## 必须保留：用户资产

- Apple IAP 商品 ID 与后端订单接口。
- 购买后服务端验单。
- 购买成功后轮询订单状态并刷新权益。
- 恢复购买流程。
- 会员、钻石、免费次数、视频次数字段同步。
- 钻石不足、VIP 不足时的错误码分流。
- 制作历史与删除任务。
- 本地原图保存和作品详情原图/结果对比。

## 必须保留：内容配置驱动

- `AllDataSource` 作为所有 AI 模板的统一配置源。
- `HomePageDataSource` 用于首页、运营弹窗、banner、金刚位、新用户 Ask。
- `show_position` 驱动视频/图片页面推荐与热词。
- `FilterItem` 的 `oss_type`、`input_require`、`wait_seconds`、`custom_parameter`、`combine_configs`。
- `permeateCardIDToFilterItem()` 给 filter 回填 cardID。
- 7 天缓存策略可以保留，但建议修复 timestamp key 不一致问题。

## 必须保留：制作体验

- 上传前校验：
  - filterId 必须有效。
  - 单图/双图/多图/视频输入数量必须满足模板要求。
  - 钻石余额必须满足动态消耗。
  - VIP 模板需要权限判断。
- 制作中：
  - 上传阶段和生成阶段分离。
  - 进度模拟。
  - 超时保护。
  - 取消任务调用删除接口。
  - 支持 VIP 跳过等待/后台任务。
- 制作后：
  - 图片/视频结果下载到本地再展示。
  - 非 VIP 水印保存逻辑。
  - 权益刷新。
  - 原图本地关联保存。

## 可以重做：产品表现层

这些内容建议按新产品真实定位重做：

- App 名称、Bundle ID、图标、启动页、品牌视觉。
- 首页信息架构和 Tab。
- 模板分类命名和入口组织。
- 会员页 UI、促销表达、关闭策略和文案。
- Onboarding、引导、评分触发、弹窗策略。
- 运营素材、示例图、视频、文案。
- 埋点事件命名可以重构，但需要确保数据团队可迁移。

## 需要重新评估的合规点

- 隐私政策和 Terms 当前仍写 Pixnova/Chengdu Ledong 等信息，新产品必须重写。
- ATT、IDFA、AppsFlyer、SolarEngine、TikTok、Facebook、Firebase、FCM 的用途与披露需重新核对。
- 推送权限申请时机建议调整为用户能理解的上下文。
- 相册、相机、通知、追踪权限文案需要与新功能对应。
- IAP 商品、订阅说明、价格、试用、取消规则必须与 App Store Connect 配置一致。
- 如果新产品不需要某些 SDK，应移除，减少隐私与审核负担。

## 高风险回归点

- Token 刷新与启动数据加载的竞态。
- 首页缓存读取的 timestamp key。
- `Account.isValid()` 使用 OR 判断，可能 token/userId 半残也认为有效。
- 支付域名接口不校验 `code`，新网络层不能无意中套普通解析。
- Gemini 流式 JSON 是从文本中提取顶层 JSON 对象，不是标准逐行 SSE 解析。
- OSS 媒体类型通过文件头判断，未知类型会生成 `video/` 空后缀。
- `UploadTask` 超时后 `isTimeout` 当前没有置 true，重构时可顺手修正。
- 删除任务接口在不同场景既用于取消也用于作品删除。
- 个人中心判断视频仅用 `contentType == "video/mp4"`，其他视频 mime 可能被当成图片。

## 建议新工程模块划分

- `Core/Network`：统一请求、错误码、header、支付特殊 host、SSE。
- `Core/Account`：登录、刷新、用户信息、权益、AB 分组。
- `Core/Generation`：UploadModel、Uploader、TaskCreator、Poller、Downloader、Cancel/Background。
- `Feature/Home`：首页数据、缓存、运营位。
- `Feature/AIEditor`：filter/photo/video/image/avatar/baby/video-resolution 的 UI 组合。
- `Feature/Paywall`：会员、钻石、IAP。
- `Feature/Profile`：历史作品、详情、删除、下载、分享。
- `Feature/Reward`：奖励中心、邀请、任务领取。
- `Infra/Storage`：Firebase/OSS、本地 Documents、SQLite。
- `Infra/Analytics`：埋点适配层，避免业务直接依赖多个 SDK。

## 新产品上线前建议测试矩阵

- 首次启动：无账号登录、token 保存、首页数据、AllData 加载。
- 前台恢复：token 过期、token 30 分钟内过期、刷新失败重登。
- Filter：免费模板、VIP 模板、单图、双图、切换单双图。
- Video：单图生视频、文生视频、多图生视频、高级参数、钻石不足。
- Image：文生图、多图生图、combine_configs。
- Video Resolution：上传视频、参数倍率、下载结果。
- Avatar/Baby/OneBigImage：prompt 是否正确传入。
- 上传：Firebase 成功/失败、OSS 签名失败、OSS PUT 失败。
- 轮询：成功、业务失败、超时、取消、后台。
- 支付：会员购买、钻石购买、取消、失败、恢复购买、订单状态轮询失败。
- 历史：成功作品、失败作品、删除、下载、分享、原图对比。
- 奖励：任务列表、本地完成、领取、刷新钻石。
- 邀请：成功、失败、过期/已兑换状态。
