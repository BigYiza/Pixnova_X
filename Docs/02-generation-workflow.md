# AI 制作统一工作流

本文档描述当前 App 内 AI 制作的统一链路。新制作页应优先继承
`BaseGenerationWorkflowViewController`，页面只负责收集输入和展示结果；资源检查、会员/钻石检查、上传、创建任务、轮询、取消和权益刷新由统一流程处理。

高级参数与钻石计算见：[16_制作参数配置与钻石计算](./16_制作参数配置与钻石计算.md)。

## 当前核心类

| 类/协议 | 职责 |
| --- | --- |
| `GenerationDraft` | 一次制作的业务输入：模板、素材、prompt、`external_args`、`combine_configs` |
| `GenerationMediaInput` | 素材输入，支持 `.empty`、`.localImage(URL)`、`.remote(URL)` |
| `GenerationWorkflowRequest` | 页面提交给统一流程的请求，包含 draft、模板、价格、输入要求、轮询配置 |
| `GenerationWorkflowInputRequirement` | 制作前输入要求，例如需要几张图片、是否需要 prompt |
| `BaseGenerationWorkflowViewController` | 制作页面基类，统一处理前置检查、缺资源引导、权益拦截、取消和回调 |
| `GenerationMediaUploading` | 把本地素材转换成远程 URL |
| `OSSGenerationMediaUploader` | 当前 OSS 上传实现，使用 `/api/ali_oss/upload_sign_url` 签名上传 |
| `GenerationWorkflowRunning` | 创建任务、轮询、取消、超时、成功后刷新权益 |
| `DefaultGenerationWorkflowRunner` | 当前 runner 实现 |
| `GenerationParameterPricing` | 高级参数选中态、联动、钻石计算、导出 `external_args` |
| `GenerationRepository` | 后端制作 API 封装 |

旧 SwiftUI 链路中的 `UploadModel`、`UploadManager`、`UploadPage` 仍可作为历史参考，但新 UIKit 制作页不应继续复制旧逻辑。

## 标准时序

1. 页面收集用户输入，组装 `GenerationDraft`。
2. 未选择的素材用 `.empty` 占位，页面不要直接抛通用错误。
3. 页面返回 `GenerationWorkflowRequest`，声明 `inputRequirement` 和 `requiredDiamonds`。
4. `BaseGenerationWorkflowViewController` 先做本地前置检查：
   - `templateID` 是否有效。
   - 必填图片/视频是否已选择。
   - 必填 prompt 是否为空。
5. 如果缺资源，基类调用 `presentGenerationMediaPicker(kind:index:)`，由页面打开对应相册/相机入口。
6. 资源满足后，基类检查会员和钻石：
   - 模板会员限制走 `MembershipHandling.membershipStatus`。
   - 钻石余额按 `request.requiredDiamonds` 校验。
7. 通过检查后进入 `GenerationWorkflowRunning.run`。
8. runner 再做一次会员/钻石防线检查。
9. `GenerationMediaUploading` 上传本地素材，输出全远程 URL 的 draft。
10. `GenerationRepository.createTask` 调 `/api/image_generation`。
11. runner 调 `/api/query_result` 轮询直到完成、失败、取消或超时。
12. 成功后刷新会员/钻石状态，并通过 `generationDidFinish` 回调页面。
13. 页面展示结果，例如用 `task.resultURL` 更新预览或跳转结果页。

## 页面接入方式

制作页继承 `BaseGenerationWorkflowViewController`，至少覆盖：

```swift
override func makeGenerationWorkflowRequest() async throws -> GenerationWorkflowRequest
```

如果页面需要引导选择资源，再覆盖：

```swift
override func presentGenerationMediaPicker(
    kind: GenerationWorkflowMediaKind,
    index: Int
) -> Bool
```

常用回调：

| 方法 | 场景 |
| --- | --- |
| `generationDidStart(task:request:)` | 后端任务已创建，可切换按钮为 Generating |
| `generationDidUpdate(task:request:)` | 轮询中更新进度或文案 |
| `generationDidFinish(task:request:)` | 制作完成，展示 `aigc_url` |
| `generationDidCancel()` | 本地取消 |
| `generationDidFail(error:)` | 失败展示 |
| `presentMembershipPaywall(reason:)` | 会员拦截 |
| `presentDiamondPurchase(required:available:)` | 钻石不足 |

## 制作前检查

### 资源选择

`GenerationMediaInput.empty` 表示用户还没有选择资源。页面应把空位保留在 draft 中，让基类知道缺的是哪个 slot。

单图：

```swift
let input: GenerationMediaInput = selectedURL.map { .localImage($0) } ?? .empty
```

双图：

```swift
let inputs = selectedImages.map { image -> GenerationMediaInput in
    guard let url = image?.localURL else { return .empty }
    return .localImage(url)
}
```

request 里声明资源要求：

```swift
GenerationWorkflowRequest(
    kind: .customVideo,
    template: template,
    draft: draft,
    inputRequirement: GenerationWorkflowInputRequirement(requiredMediaCount: 2),
    requiredDiamonds: pricing.expense
)
```

缺资源时，基类会抛 `GenerationWorkflowPreflightError.missingMedia` 并调用：

```swift
presentGenerationMediaPicker(kind: .image, index: firstMissingIndex)
```

页面返回 `true` 表示已处理，例如打开第 `index` 个图片 slot 的相册/相机选择器。

### 会员

会员检查统一在基类和 runner 中处理：

```swift
membership.access(to: request.template)
```

如果模板需要会员而当前用户没有权限，抛：

```swift
GenerationWorkflowBlockError.membership(reason)
```

基类默认用 `presentMembershipPaywall(reason:)` 处理，具体页面可覆盖打开正式会员页。

### 钻石

钻石检查使用 `request.requiredDiamonds`。

- 普通模板默认取 `template.diamondCost`。
- 有高级参数的页面应传 `GenerationParameterPricing.expense`。

余额不足时抛：

```swift
GenerationWorkflowBlockError.insufficientDiamonds(required:available:)
```

基类默认用 `presentDiamondPurchase(required:available:)` 处理，具体页面可覆盖打开钻石购买页。

### Prompt

文本生成类页面可声明：

```swift
GenerationWorkflowInputRequirement(
    requiredMediaCount: 0,
    requiresPrompt: true
)
```

基类会检查 `draft.prompt` 去掉空白后是否为空。

## Draft 字段

| 字段 | 含义 |
| --- | --- |
| `templateID` | 后端 `filter_id` |
| `mediaInputs` | `.empty`、本地素材或远程素材 |
| `prompt` | 正向提示词；模板视频页当前使用模板下发 prompt |
| `negativePrompt` | 负向提示词 |
| `externalArguments` | 高级参数，最终传 `external_args` |
| `combineConfigs` | 多图/图生图组合配置，最终传 `combine_configs` |

`externalArguments` 和 `combineConfigs` 使用 `JSONValue`，保留后端需要的字符串、数字、布尔、对象、数组和 null 类型。

## API

### 创建制作任务

接口：`POST /api/image_generation`

请求：

```json
{
  "urls": ["https://cdn.example.com/input.jpeg"],
  "filter_id": 123,
  "prompt": "optional prompt",
  "negative_prompt": "optional negative prompt",
  "external_args": {
    "resolution": "720p",
    "duration": "5"
  },
  "combine_configs": {
    "function_configs": []
  }
}
```

字段说明：

| 字段 | 必填 | 来源 |
| --- | --- | --- |
| `urls` | 是 | uploader 输出的远程素材 URL；文生类可以为空数组 |
| `filter_id` | 是 | `GenerationDraft.templateID` |
| `prompt` | 否 | `GenerationDraft.prompt` |
| `negative_prompt` | 否 | `GenerationDraft.negativePrompt` |
| `external_args` | 否 | `GenerationDraft.externalArguments`，为空时不传 |
| `combine_configs` | 否 | `GenerationDraft.combineConfigs`，空对象时不传 |

成功响应：

```json
{
  "data": {
    "task_id": "task_id"
  }
}
```

### 查询任务结果

接口：`GET /api/query_result?id={task_id}`

完成响应：

```json
{
  "data": {
    "task_id": "task_id",
    "state": "completed",
    "aigc_url": "https://cdn.example.com/result.mp4"
  }
}
```

runner 每 `request.pollInterval` 秒轮询一次，默认 `0.5s`。超过 `request.timeout` 后抛 `Generate timeout.`。

### 取消任务

接口：`POST /api/del_task_by_id`

```json
{
  "task_id": "task_id"
}
```

`BaseGenerationWorkflowViewController.cancelGenerationWorkflow(deleteRemoteTask:)` 会取消本地 task；如果已有 `activeTaskID` 且 `deleteRemoteTask == true`，会调用后端取消。

### OSS 上传签名

接口：`POST /api/ali_oss/upload_sign_url`

```json
{
  "content_type": "image/jpeg",
  "filename": "{UUID}.jpg"
}
```

成功后客户端对 `sign_url` 发 `PUT`，再把 `file_url` 写入创建任务请求的 `urls`。

## 高级参数与钻石

`CreativeTemplate.customParameter` 解码后交给 `GenerationParameterPricing`：

- `parameters` 控制 UI 可选参数。
- `restricts` 控制参数联动。
- `selected`、`value` 支持字符串和数字混用。
- 默认值比较会做字符串化和大小写兼容。
- `expense` = 模板基础钻石数乘以参数倍率。
- `externalArguments()` 导出后端需要的 `external_args`。

示例：

```swift
let pricing = GenerationParameterPricing(template: template)
let draft = GenerationDraft(
    templateID: template.id,
    mediaInputs: imageInputs,
    prompt: template.prompt,
    negativePrompt: nil,
    externalArguments: pricing.externalArguments(),
    combineConfigs: template.combineConfigs
)
```

## 已接入页面

### 模板视频页

类：`TemplateVideoGenerationViewController`

- 单图模板声明 1 张图片。
- 双图模板声明 2 张图片。
- 未选择图片时 draft 对应 slot 为 `.empty`。
- 点击 Generate 后，基类发现缺图会打开缺失 slot 的相册/相机选择器。
- 参数卡片由 `GenerationParameterPricing` 维护。
- 生成成功后用 `task.resultURL` 更新视频预览。

### 滤镜页

类：`FilterGenerationViewController`

- 声明 1 张图片。
- 未选图时传 `.empty`。
- 基类缺图回调会打开相册/相机选择器。
- 生成流程走同一套 uploader、runner 和 repository。

## 新业务接入清单

1. 页面继承 `BaseGenerationWorkflowViewController`。
2. 把未选择资源表示为 `.empty`。
3. 在 `GenerationWorkflowRequest` 中声明 `inputRequirement`。
4. 有高级参数时使用 `GenerationParameterPricing` 作为唯一价格来源。
5. 页面不直接调用上传、创建任务、轮询、取消 API。
6. 页面覆盖会员/钻石弹窗方法，接入真实购买页。
7. 页面只在 `generationDidFinish` 中处理展示或跳转。

## 历史链路迁移说明

旧 `UploadModel / UploadManager / UploadPage` 链路中的字段可按下表迁移：

| 旧字段/能力 | 新位置 |
| --- | --- |
| `filterId` / `selectedFilter` | `GenerationDraft.templateID` / `GenerationWorkflowRequest.template` |
| `originImage` / `originImages` | `GenerationDraft.mediaInputs` |
| `prompt` / `negativePrompt` | `GenerationDraft.prompt` / `negativePrompt` |
| `externalArgs` | `GenerationDraft.externalArguments` |
| `combineConfigs` | `GenerationDraft.combineConfigs` |
| `diamondsExpensenHandler` | `GenerationParameterPricing` |
| `UploadManager` 上传 | `GenerationMediaUploading` |
| `UploadManager` 创建和轮询 | `GenerationWorkflowRunning` + `GenerationRepository` |
| `UploadPage` 等待 UI | 页面基类回调 + 后续统一等待页 |
