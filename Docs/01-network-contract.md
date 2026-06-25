# 网络接口与错误码契约

## 环境与域名

主业务域名在 `LaunchConfig.swift`：

| 环境 | `SERVER_HOST` |
| --- | --- |
| DEBUG | `https://api.pixnova.app`，代码中保留了 `https://testapi.pixnova.app` 注释 |
| ADHOC | `https://api.pixnova.app` |
| RELEASE | `https://api.pixnova.app` |

支付域名在 `IAPService.swift`：

| 环境 | Host |
| --- | --- |
| Debug | `https://pay-vmddzvrudq-df.a.run.app` |
| Release | `https://pay-mhsaciltta-wl.a.run.app` |

其他网络通道：

- Firebase Storage：默认图片上传通道，路径为 `iOS/uploadImage/yyyyMMdd/UUID`。
- OSS：通过 `/api/ali_oss/upload_sign_url` 取得签名 URL 后，对签名 URL 直接发起 `PUT`。
- Gemini SSE：`POST {SERVER_HOST}/api/chat_generation_content`，使用原生 `URLSession`，`Accept: text/event-stream`。
- 第三方 SDK：Firebase、AppsFlyer、SolarEngine、TikTok Business、Facebook、FCM。

## 统一请求 Header

`RBXServer.headers` 会为业务请求加以下字段：

| Header | 规则 |
| --- | --- |
| `Authorization` | 账号有效时：`Bearer {accessToken}` |
| `tokenId` | 账号有效时：`accessToken` |
| `uid` | 账号有效时：`userId` |
| `timezone` | 当前时区分钟数，`secondsFromGMT()/60` |
| `User-Agent` | `pixnova;{appVersion};iOS;{systemVersion};{deviceCode};Apple Store;{timezone};{languageCode}` |
| `device-id` | `UUIDManager.getUUID()` |
| `Content-Type` | 普通/下载：`application/json`；上传：`multipart/form-data` |
| `Clt-Start` | 仅 `/api/image_generation` 增加 UTC 时间，格式 `yyyy-MM-dd'T'HH:mm:ss'Z'` |

Gemini SSE 单独构造 header，少了语言码，但包含 `Authorization/tokenId/uid/timezone/User-Agent/device-id/Content-Type/Accept`。

## 统一响应与错误码

普通业务接口统一经 `APIProvider.api_request` 解析：

1. HTTP 必须是 2xx，否则返回 `.mappingError`。
2. JSON 必须能转成 `[String: Any]`，否则 `.mappingError`。
3. 非支付域名必须存在 `code: Int`。
4. `code == 0` 为成功。
5. `code == -100`：认为 token 失效，调用 `AccountManager.default.refreshToken()`，业务侧收到 `.serverError("Token Failed", -100)`。
6. 其他非 0 code：错误文案按 `description`、`desc`、`msg` 顺序读取，最后 fallback 为本地化 `request fail`。

本地错误类型：

| 错误 | 含义 | 展示文案 |
| --- | --- | --- |
| `.requestError` | Moya 请求失败 | `当前网络连接断开，请稍后再试` |
| `.mappingError` | HTTP 非 2xx、JSON/模型解析失败、缺 `code` | `当前网络连接断开，请稍后再试` |
| `.unzipError` | 预留，文件解压失败 | `文件解压失败!` |
| `.serverError(msg, code)` | 服务端业务错误 | 使用服务端 msg |

业务中特别处理的服务端 code：

| Code | 代码中含义 | 处理 |
| --- | --- | --- |
| `0` | 成功 | 进入成功解析 |
| `-100` | token 失效 | 刷新 token |
| `-101` | 会员/VIP 权益不足 | 打开会员页或 Gemini memberBlock |
| `-102` | 视频次数不足，旧逻辑 | `videoTimes = 0` |
| `-103` | 钻石不足/需购买钻石 | 刷新会员权益或打开钻石购买页 |
| `-1` | 本地默认失败码 | 参数错误、未知错误、下载失败等 |
| `99` | Firebase 上传 URL 异常 | `upload Image Failed, Check Image CDN` |

支付域名接口特殊：只要 HTTP/JSON 成功，`api_request` 不检查 `code`，直接把 JSON 回传。支付业务自己检查字段，例如 restore 校验 `state == 0`。

## API 清单

### 账户与启动

| API | Method | 参数 | 关键响应字段 | 调用点 |
| --- | --- | --- | --- | --- |
| `/openapi/login` | POST | 无 | `data.user_id`, `data.token_info.token`, `data.token_info.expire_time` | App 启动登录、刷新失败后重登 |
| `/openapi/refresh_token` | POST | 无 | `data.token_info.token`, `data.token_info.expire_time` | token 快过期、`-100` 后 |
| `/openapi/query_status_by_ver` | GET | 无 | `data.is_reviewing` | 控制 `AppCanHappyShow` 与部分 AB 展示 |
| `/api/upload_token` | POST | `token` | 无强依赖 | FCM token 上传 |
| `/api/upload_infos` | POST | `distinct_id` | 无强依赖 | SolarEngine distinctId 上传 |
| `/api/restore_user_id` | POST | `trans_id: [String]` | `data.token_info.token`, `data.token_info.expires_time` | 购买恢复后的用户权益恢复 |

### 用户、权益、分组

| API | Method | 参数 | 关键响应字段 |
| --- | --- | --- | --- |
| `/api/query_user_info` | GET | 无 | `data.invite_info`, `data.vip_reward`, `data.user` |
| `/api/query_user_group_by_pos` | POST | `postion_list: ["MemberShipCloseBtn", "MemberShip_Paywall"]` | `data` 作为 `userGroupMap` |
| `/api/query_vip_status` | GET | 无 | `data.is_vip`, `expires_time`, `video_times`, `give_ai_videos_times`, `free_vip_times`, `diamonds` |

### 首页与内容配置

| API | Method | 参数 | 关键响应字段 |
| --- | --- | --- | --- |
| `/api/query_home_data` | GET | `tab` | `cards`, `banners`, `pops`, `tabs`, `home_asks` |
| `/api/query_operations_data` | GET | 无 | 同 `HomePageDataSource` |
| `/api/query_cards` | GET | `category_id: 0` | `data: [Card]` |

### AI 制作与素材上传

| API | Method | 参数 | 关键响应字段 |
| --- | --- | --- | --- |
| `/api/ali_oss/upload_sign_url` | POST | `content_type`, `filename` | `data.sign_url`, `data.file_url` |
| OSS `sign_url` | PUT | binary body，`Content-Type` 为媒体类型 | HTTP 2xx |
| Firebase Storage | SDK | image/video data | download URL |
| `/api/image_generation` | POST | `urls`, `filter_id`, 可选 `prompt`, `negative_prompt`, `external_args`, `combine_configs` | `data.id` |
| `/api/query_result` | GET | `id` | 成功时 `data.aigc_url` |
| `/api/del_task_by_id` | POST | `task_id` | 删除任务 |
| `/api/query_custom_parameter` | GET | `filter_id` | `parameters`, `restricts` |
| `/api/chat_generation_content` | POST SSE | `content`, 可选 `images`, `session_id` | header `session_id`；流式 JSON：`code`, `type`, `text`, `images[].url` |

### 我的、钻石、奖励、邀请

| API | Method | 参数 | 关键响应字段 |
| --- | --- | --- | --- |
| `/api/query_my_tasks` | GET | `page_num`, `page_size` | `items`, `total` |
| `/api/query_diamonds_log` | GET | `page_num`, `page_size` | `items`, `total` |
| `/api/query_diamond_tasks` | GET | 无 | `task_list` |
| `/api/finish_diamond_task` | POST | `id` | 成功后刷新权益 |
| `/api/confirm_invite` | POST | `code` | 成功后展示奖励 |

### IAP 支付域名

| API | Method | 参数 | 关键响应字段 |
| --- | --- | --- | --- |
| `/api/v1/order/create` | POST | `name`, `description`, `product_id`, `purchase_price` | `data.order_id`, `data.order_uuid` |
| `/api/v1/order/status` | GET | `order_id` | `data.state`，`1` 表示完成 |
| `/api/v1/pay/apple/success_notify` | POST | `order_id`, `transaction_id`, `receipt_data` | 无强字段，成功即通过 |
| `/api/v1/pay/apple/restore` | POST | `original_transaction_id`, `transaction_id`, `receipt_data` | `state == 0` 表示恢复成功 |

## 模型字段契约

### Card

| 字段 | 本地字段 | 说明 |
| --- | --- | --- |
| `home_style` | `homepageStyle` | 首页展示样式 |
| `name` | `name` | 分组/卡片名 |
| `filters` | `filters` | 具体模板列表 |
| `category_id` | `CategoryID` | 对应 `AIType` |
| `card_id` | `id` | card id |
| `relation_card_id` | `relationCardID` | 生成结果页挂载视频入口 |
| `relation_card_media_desc` | `relationCardMedia` | 挂载视频预览资源 |
| `show_position` | `showPosition` | 运营位置，如图生视频、热词等 |

### FilterItem

| 字段 | 本地字段 | 说明 |
| --- | --- | --- |
| `filter_id` | `id` | 模板 id，制作时传 `filter_id` |
| `category_id` | `categoryID` | AI 类型 |
| `name` | `name` | 模板名 |
| `cover` | `coverImage` | 展示图 |
| `cover1` | `cover1Image` | 备用展示图 |
| `operations_cover` | `coverImageSource` | 视频等操作封面 |
| `vip_need` | `vipLimit` | 非 VIP 是否拦截 |
| `oss_type` | `ossType` | `ali_oss` 使用 OSS，否则 Firebase |
| `description` | `description` | 模板说明 |
| `input_require.people_numbers_one_image` | `peopleNumbersOneImage` | 单图人数要求 |
| `input_require.image_count` | `imageCount` | 需要上传图片数量 |
| `wait_seconds` | `waitSeconds` | 制作超时与 loading 估时 |
| `processing_copywritings` | `waits` | loading 过程文案 |
| `prompt` | `prompt` | 默认提示词 |
| `use_times` | `useTimes` | 使用次数展示 |
| `diamonds` | `diamonds` | 基础钻石消耗 |
| `custom_parameter` | `diamondsExpenseParam` | 高级参数/价格配置 |
| `combine_configs` | `combineConfigs` | 多图/组合生成配置 |
| `max_input_count` | `maxInputImageCount` | 多图最大输入数 |

### AIType

| rawValue | 类型 |
| --- | --- |
| 1 | filter |
| 2 | hair |
| 3 | cutout |
| 4 | photo |
| 5 | avatar |
| 6 | video |
| 7 | outfit |
| 8 | baby |
| 9 | oneImageSet |
| 10 | textToVideo |
| 11 | imageToVideo |
| 12 | makeup |
| 13 | multiImageToVideo |
| 14 | videoResolution |
| 15 | textToImage |
| 16 | imageToImage |
