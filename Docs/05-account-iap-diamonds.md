# 账户、会员、IAP 与钻石

## 匿名账号与 Token

账号数据保存在 UserDefaults：

- key：`currentUserAccount`
- 模型：`Account`

`Account.isValid()` 当前逻辑是 `userId.count > 0 || accessToken.count > 0`。

启动流程：

1. 本地账号有效：直接 `fetchData()` 并配置分析账号信息。
2. 本地账号无效：调用 `/openapi/login`。
3. 登录成功保存：
   - `data.user_id`
   - `data.token_info.token`
   - 可选 `data.token_info.expire_time`

Token 刷新：

- App 进入前台会检查 token。
- `tokenExpireTime <= now` 或剩余少于 30 分钟会调 `/openapi/refresh_token`。
- 刷新失败后重新 `/openapi/login`。
- 网络响应 `code == -100` 也会触发刷新。

## Account 字段

| 字段 | 含义 |
| --- | --- |
| `accessToken` | 当前 token |
| `tokenExpireTime` | token 过期时间戳，UTC 秒 |
| `userId` | 用户 id |
| `isVip` | 是否会员 |
| `vipExpirationTime` | VIP 到期时间戳 |
| `videoTimes` | 视频次数，旧逻辑仍保留 |
| `giveAiVideosTimes` | 是否赠送过 AI 视频次数 |
| `freeVipTimes` | 免费 VIP/试用次数 |
| `diamonds` | 钻石余额 |
| `invitationInfo` | 邀请信息 |
| `displayInvitationInfo` | 邀请奖励差值展示 |
| `vipRewardInfo` | VIP 周奖励信息 |
| `userGroupMap` | AB 实验分组 |
| `user` | 用户注册时间等 |

## 会员状态刷新

接口：`GET /api/query_vip_status`

关键字段：

| 字段 | 作用 |
| --- | --- |
| `is_vip` | 大于 0 为 VIP |
| `expires_time` | VIP 到期 |
| `video_times` | 视频次数 |
| `give_ai_videos_times` | 赠送视频次数状态 |
| `free_vip_times` | 免费试用/权益次数 |
| `diamonds` | 钻石余额 |

刷新后会：

- 更新 `Account`。
- 非 VIP 时预加载 IAP 商品。
- 发送 `MembershipStateDidChanged` 通知。

## 用户信息

接口：`GET /api/query_user_info`

处理内容：

- `invite_info`：邀请信息。
- `vip_reward`：VIP 奖励弹窗信息。
- `user`：注册时间、用户 id。

邀请弹窗本地判断：

- 对比服务端邀请人数、会员天数、钻石数与本地保存值。
- 任何一个增加，生成差值 `displayInvitationInfo` 并允许弹窗。
- 发送 `invitationInfoDidUpdateResetFlag` 和 `invitationInfoDidUpdateNeedShowDialog`。

邀请码可兑换状态：

- 如果 `invited_code` 有值：已兑换。
- 如果 `user.reg_time` 距今超过 3 天：过期。
- 否则可兑换。

## AB 分组

接口：`POST /api/query_user_group_by_pos`

参数：

```json
{
  "postion_list": ["MemberShipCloseBtn", "MemberShip_Paywall"]
}
```

结果直接保存到 `Account.userGroupMap`。

当前使用：

- `MemberShipCloseBtn` 控制会员页关闭按钮策略。
- `MemberShip_Paywall` 控制会员页内容样式。
- 如果 `LaunchConfig.share.AppCanHappyShow == false`，强制使用 Normal。

## IAP 商品 ID

### 会员商品

| 常量 | Product ID |
| --- | --- |
| 新用户年会员 | `Pixnova.vip.yearly.online.nofreetrail.newfriend` |
| 新用户周会员 | `Pixnova.vip.weekly.online.nofreetrail.newfriend` |
| 限时年会员 | `Pixnova.vip.yearly.online.nofreetrail.newuserdiscount` |
| 关闭弹窗周会员 | `Pixnova.vip.weekly.449.nofreetrail` |

AB 会员商品：

- Normal：
  - `Pixnova.vip.weekly.online.nofreetrail`
  - `Pixnova.vip.yearly.online.nofreetrail`
  - `Pixnova.vip.yearly.online.3daysfree`
- Close 3 秒：
  - `Pixnova.vip.yearly.online.3daysfree.abtesting.closebtn.3sshow`
  - `Pixnova.vip.yearly.online.nofreetrail.abtesting.closebtn.3sshow`
  - `Pixnova.vip.weekly.online.nofreetrail.abtesting.closebtn.3sshow`
- Never Close：
  - `Pixnova.vip.yearly.online.3daysfree.abtesting.closebtn.none`
  - `Pixnova.vip.yearly.online.nofreetrail.abtesting.closebtn.none`
  - `Pixnova.vip.weekly.online.nofreetrail.abtesting.closebtn.none`

### 钻石商品

| 数量/用途 | Product ID |
| --- | --- |
| 10 | `Pixnova.10.diamonds.online.` |
| 15 | `Pixnova.15.diamonds.online.` |
| 50 | `Pixnova.50.diamonds.online.` |
| 50 原价 | `Pixnova.50.diamonds.online.orgprice` |
| 60 | `Pixnova.60.diamonds.online.` |
| 200 | `Pixnova.200.diamonds.online.` |
| 200 原价 | `Pixnova.200.diamonds.online.orgprice` |
| 240 | `Pixnova.240.diamonds.online.` |
| 500 | `Pixnova.500.diamonds.online.` |
| 500 原价 | `Pixnova.500.diamonds.online.orgprice` |
| 600 | `Pixnova.600.diamonds.online.` |
| 1000 | `Pixnova.1000.diamonds.online.` |
| 1000 原价 | `Pixnova.1000.diamonds.online.orgprice` |
| 1000 列表价 | `Pixnova.1000.diamonds.online.listprice` |
| 1200 | `Pixnova.1200.diamonds.online.` |
| 1200 原价 | `Pixnova.1200.diamonds.online.orgprice` |
| 1200 列表价 | `Pixnova.1200.diamonds.online.listprice` |

## 支付流程

1. `IAPManager.loadProducts` 从 Apple 拉取商品。
2. 用户点击购买。
3. 调支付域名 `/api/v1/order/create` 创建订单：

```json
{
  "name": "{localizedTitle}",
  "description": "{localizedDescription}",
  "product_id": "{productIdentifier}",
  "purchase_price": "{localizedPrice}"
}
```

4. 后端返回 `order_id` 与 `order_uuid`。
5. 用 `order_uuid` 作为 `SKMutablePayment.applicationUsername`。
6. Apple 支付成功后读取 App Store receipt。
7. 调 `/api/v1/pay/apple/success_notify`：

```json
{
  "order_id": "...",
  "transaction_id": "...",
  "receipt_data": "base64"
}
```

8. 成功后 `finishTransaction`。
9. 轮询 `/api/v1/order/status?order_id=...`，最多 5 次。
10. `state == 1` 时发送 `IAPPurchaseSucceed` 并刷新会员状态。

## 恢复购买

1. `SKPaymentQueue.restoreCompletedTransactions()`。
2. 取 restored 或 purchased 交易。
3. 调 `/api/v1/pay/apple/restore`：

```json
{
  "original_transaction_id": "...",
  "transaction_id": "...",
  "receipt_data": "base64 or empty"
}
```

4. `state == 0` 认为恢复成功。
5. 必要时调用 `/api/restore_user_id`，参数 `trans_id`。

## 钻石消耗

- 模板基础消耗：`filterItem.diamonds ?? 10`。
- 高级参数由 `DiamondsExpenseHandler` 计算倍数。
- 生成前如果 `Account.diamonds < expense`，打开钻石购买页。
- 生成成功或购买成功后刷新 `/api/query_vip_status`，同步钻石。

## 钻石流水

接口：`GET /api/query_diamonds_log`

参数：

```json
{
  "page_num": 1,
  "page_size": 20
}
```

响应：

| 字段 | 说明 |
| --- | --- |
| `items[].create_time` | 时间 |
| `items[].description` | 描述 |
| `items[].diamonds` | 数量，字符串 |
| `total` | 总数 |
