# AI 制作统一工作流

## 核心类

| 类 | 职责 |
| --- | --- |
| `UploadModel` | 保存一次制作的输入、模板、参数、上传状态、错误、结果 |
| `UploadManager` | 上传素材、创建后端任务、轮询结果、下载最终资源、取消/后台任务 |
| `UploadTask` | 包装制作进度、超时、成功/失败回调 |
| `UploadPage` | 制作中的弹层 UI，展示上传/生成进度、取消、VIP 跳过等待 |

## UploadModel 关键字段

| 字段 | 含义 |
| --- | --- |
| `originImage` | 单图输入 |
| `originImages` | 多图输入 |
| `originVideos` | 视频输入，视频增强使用 |
| `selectedFilter` / `filterId` | 当前模板，最终传给后端 `filter_id` |
| `prompt` | 正向提示词 |
| `negativePrompt` | 负向提示词 |
| `externalArgs` | 高级参数，最终传 `external_args` |
| `combineConfigs` | 多图组合配置，最终传 `combine_configs` |
| `aiType` | 本地展示/下载逻辑判断 |
| `uploadType` | `.ali` 或 `.firebase` |
| `canBackground` | 是否支持生成后跳过等待/后台通知 |
| `taskId` | 后端任务 id |
| `filterUrl` | 后端生成资源 URL |
| `generateImage` / `videoUrl` | 本地下载后的最终结果 |
| `errorCode/errorMsg/showError` | 失败展示 |

## 标准制作时序

1. 页面根据用户输入组装 `UploadModel`。
2. 如果模板 `oss_type == "ali_oss"`，走 OSS；否则走 Firebase Storage。
3. 图片会压成 JPEG，`compressionQuality = 0.8`；视频读取本地 URL 的 Data。
4. 上传完成后得到素材 URL 列表。
5. 调 `/api/image_generation` 创建任务：

```json
{
  "urls": ["https://..."],
  "filter_id": 123,
  "prompt": "optional",
  "negative_prompt": "optional",
  "external_args": {},
  "combine_configs": {}
}
```

6. 成功后读取 `data.id` 作为 `taskId`。
7. 每 0.5 秒调 `/api/query_result?id={taskId}`。
8. 如果响应 `data.aigc_url` 存在，认为后端制作完成。
9. 图片结果：Kingfisher 下载，失败最多重试 3 次。
10. 视频结果：`VideoDownloadManager` 下载到本地。
11. `UploadTask` 触发 `.done`，页面跳转结果页，并刷新会员/钻石权益。

## 进度与超时

- 创建任务前 UI 显示 Uploading。
- `finishQueryTask` 后进入 Generating，开始进度模拟。
- 进度阶段：
  - 轮询阶段上限 95%。
  - 资源下载阶段上限 99%。
  - 完成后到 100%。
- 超时时间：`selectedFilter.waitSeconds ?? 120`。
- 超时后展示 `Generate timeout`，停止本次任务。

## 上传通道

### Firebase

- 方法：`StorageManager.uploadImageToStorage`
- 路径：`iOS/uploadImage/{yyyyMMdd}/{UUID}`
- metadata：`image/jpeg`
- 返回：Firebase download URL。

### OSS

1. 根据二进制头判断媒体类型：jpg/png/mp4/mov/avi/mkv/webm/flv/wmv/m4v/mpeg/mpg。
2. 调 `/api/ali_oss/upload_sign_url`：

```json
{
  "content_type": "image/jpeg",
  "filename": "{UUID}.jpeg"
}
```

3. 后端返回：

```json
{
  "data": {
    "sign_url": "https://...",
    "file_url": "https://..."
  }
}
```

4. 对 `sign_url` 发 `PUT`，body 为原始 data，header `Content-Type` 为媒体类型。
5. HTTP 2xx 后把 `file_url` 作为素材 URL 传入制作接口。

## 取消与后台

### 取消

- `UploadManager.cancel()` 会标记 `isCanceled = true`。
- 如果已有 `taskId`，调用 `/api/del_task_by_id`。
- 删除失败最多递归重试，`cancelCounts` 默认按 3 次处理。

### 后台/跳过等待

- 仅 `canBackground == true` 且已经创建任务后展示。
- VIP 用户点击后：
  - `UploadManager.background()` 保存 `taskId` 到 `UserDefaults[kBackgroundTasksKey]`。
  - 标记 `isBackground = true`，停止前台轮询。
  - 发通知 `push_message`，`userInfo["action_type"] = "task"`。
- 非 VIP 点击进入会员页。

## 错误分流

| 场景 | 处理 |
| --- | --- |
| `filterId <= 0` | `Parameter error`, code `-1` |
| 创建任务失败 | 服务端 msg 或 `Failed to obtain taskId` |
| `-101` | 打开会员页 |
| `-102` | 清空 `videoTimes` |
| `-103` | 刷新会员状态或打开钻石购买 |
| 轮询失败 | 服务端 msg 或 `Failed to obtain url` |
| 下载资源失败 | `Failed to download image` |
| 上传失败 | `Failed to upload image/video` |

## 各模块参数组装

| 模块 | 输入 | 特殊参数 |
| --- | --- | --- |
| Filter/Hair/Photo/Outfit/Cutout | 单图或双图 | `imageCount == 2` 时传 `originImages` |
| Avatar | 单图 + 风格 prompt + 用户 prompt | `aiType = .avatar` |
| Baby | 父母两张图 | `prompt` 由性别、年龄、像谁、RemoteConfig 模板组合 |
| AI Video 老入口 | 单图或双人合成图 | 双人时先把左右图横向合成并 resize |
| Text/Image/Multi Image To Video | 文本、单图、多图 | `prompt`, `combine_configs`, `external_args` |
| Video Resolution | 视频文件 | `originVideos`, `external_args` |
| Text/Image To Image | 文本、多图 | `prompt`, `combine_configs`, `external_args` |
| OneBigImage | 单图 | 使用通用制作 |
| Gemini | 文本 + 可选图片 | 不走 `/api/image_generation`，走 SSE |

## 高级参数与钻石

- 后端在 `FilterItem.custom_parameter` 或 `/api/query_custom_parameter` 提供 `DiamondsExpenseModel`。
- `parameters` 用于 UI 选择。
- `restricts` 用于参数联动。
- 最终选择会生成：

```json
{
  "external_args": {
    "{param.key}": "{selected.value}"
  }
}
```

- 费用计算：基础 `filterItem.diamonds ?? 10` 乘以各参数 `times`。
- 视频增强特殊计算：`calculate_method == "current and ugc duration multiplier"` 时，再乘 `duration_times` 和视频时长参数。
