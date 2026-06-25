# 个人中心、历史作品、奖励与邀请

## 我的制作历史

接口：`GET /api/query_my_tasks`

参数：

```json
{
  "page_num": 1,
  "page_size": 20
}
```

响应模型：

| 字段 | 说明 |
| --- | --- |
| `items` | 任务列表 |
| `total` | 总数 |
| `items[].create_time` | 创建时间 |
| `items[].filter` | FilterItem |
| `items[].msg` | 失败文案 |
| `items[].result` | 结果 |
| `items[].state` | 状态：0 待执行；1/4 执行待返回；2 成功；3 失败 |
| `items[].task_id` | 任务 id |
| `result.aigc_action_type` | AIGC 动作类型 |
| `result.aigc_content_type` | 内容类型，如 `image/png`, `video/mp4` |
| `result.aigc_url` | 结果 URL |
| `result.aigc_urls` | 结果 URL 列表，当前主要用单个 |

加载策略：

- 首次、刷新、加载更多三种 loading 状态独立。
- `dataSource.count < totalTasks` 时可加载下一页。

## 作品详情

`MineDisplayView` 支持：

- 图片/视频展示。
- 失败任务展示模板封面 + 失败提示。
- 非 VIP 图片结果添加水印。
- 图片支持原图对比，前提是本地能根据 `taskId` 找到原图。
- 下载：
  - 视频：下载到本地后保存相册。
  - 图片：非 VIP 保存带水印渲染图；VIP 保存原图。
- 分享：
  - 图片用 `ShareLink`。
  - 视频先下载本地，再系统分享。
- Use Template：根据 `filterItem.aiType` 跳回对应制作页。

## 历史作品本地关联

数据库：

- 文件：Documents 下 `pixnova.sqlite`
- 表：`filter_background`

字段：

| 字段 | 说明 |
| --- | --- |
| `local_id` | 自增 id |
| `task_id` | 后端任务 id |
| `create_time` | 制作开始时间戳 |
| `filter_id` | 模板 id |
| `generate_url` | 生成结果 URL |

保存规则：

- 制作完成后保存。
- 如果同 `create_time` 已存在则跳过。
- 非视频类型额外保存原图到 Documents：`origin_images/{localId}/{index}.jpg`。

## 删除作品

接口：`POST /api/del_task_by_id`

参数：

```json
{
  "task_id": "..."
}
```

用途：

- 用户在作品详情删除。
- 制作中取消任务。

删除成功后：

- 从列表移除。
- 返回上一页。

## 奖励中心

接口：

- `GET /api/query_diamond_tasks`
- `POST /api/finish_diamond_task`

任务模型字段：

| 字段 | 说明 |
| --- | --- |
| `id` | 任务 id |
| `name` | 名称 |
| `description` | 描述 |
| `diamonds` | 奖励钻石 |
| `sub_type` | 子类型，如 `login`, `rate`, `download`, `follow` |
| `task_type` | `daily_task` 或 `one_time_task` |
| `value` | 动作参数，如 URL |
| `completed` | 服务端是否已完成/已领取 |

任务状态：

| 状态 | 条件 | UI |
| --- | --- | --- |
| notCompleted | 服务端未完成，本地也未标记 | 箭头 |
| readyToClaim | 本地已完成但服务端未领取 | Claim |
| completed | 服务端 `completed == true` | 勾选 |

本地完成标记：

- key：`reward_task_completed_{taskId}`
- 用于用户完成外部动作后等待领取奖励。

领取奖励：

```json
{
  "id": 123
}
```

成功后：

- 本地任务置完成。
- 重新请求任务列表。
- 刷新会员状态同步钻石。

## 邀请码

接口：`POST /api/confirm_invite`

参数：

```json
{
  "code": "INVITE_CODE"
}
```

成功：

- 展示奖励成功弹窗。
- 当前 UI 写死展示 3 天会员和 30 钻石。

失败：

- 默认 `Invitation code verification failed`。
- 如果服务端返回 `.serverError(msg, code)`，展示服务端 msg。

邀请信息来自 `/api/query_user_info` 的 `invite_info`：

| 字段 | 说明 |
| --- | --- |
| `already_get_member_days` | 已获得会员天数 |
| `already_get_diamonds` | 已获得钻石 |
| `already_invite_person_count` | 已邀请人数 |
| `invite_code` | 我的邀请码 |
| `show_invite_info_dialog` | 是否显示邀请信息弹窗 |
| `invite_logs` | 邀请日志 |
| `invited_code` | 已兑换的邀请码 |

## 推送

FCM token：

- AppDelegate 收到 token 后调 `/api/upload_token`。
- 参数：`token`。

通知点击：

- 如果 `userInfo["custom_data"]` 是字典，会发本地通知 `push_message`。
- 代码中制作跳过等待也发同名通知，`action_type = "task"`。

## 相册与评分

保存图片/视频成功后会调用 `goodReview()`：

- 使用 `UserDefaults["2_9_0_good_review_count"]` 计数。
- 第 0 次和第 2 次保存成功后触发 `AppStore.requestReview`。

新产品重构时需要重新评估评分触发时机，避免影响用户体验。
