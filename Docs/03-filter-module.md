# Filter 模块工作流

## 涉及文件

- `Views/FilterPage/FilterPage.swift`
- `Views/FilterPage/FilterModel.swift`
- `Views/FilterPage/FilterOperateChooseView.swift`
- `Views/FilterPage/FilterOperateUploadView.swift`
- `Views/FilterPage/FilterOperateDisplayView.swift`
- `Views/FilterPage/FilterOperateListView.swift`
- `Views/FilterPage/FilterTwoPhotoSheetPage.swift`
- `Views/OneBigImage/UploadPage.swift`
- `BasicBundle/UploadManager/*`

## 页面状态机

`FilterModel.stage` 有三态：

| 状态 | UI | 进入条件 |
| --- | --- | --- |
| `.choose` | 选择照片，引导用户上传 | 初始状态 |
| `.upload` | 已选择原图，展示原图 + 模板预览，按钮为 Generate | 选择完照片 |
| `.display` | 展示生成结果，支持对比、重新选图、重做、跳转视频 | 制作成功 |

## 初始化数据

1. 页面传入 `preferredFilter`。
2. 根据 `preferredFilter.categoryID` 设定 `filterModel.aiType`。
3. 从 `AllDataSource.cards` 过滤同 AIType 的卡片。
4. 如果传入了 `cardID`，优先定位该卡片；否则遍历查找 `filter_id`。
5. 如果仍未命中，默认第一个卡片的第一个 filter。
6. `segmentTitles = cards.map { card.name }`。
7. `selectedTab` 对齐当前 filter 所属 card。
8. 每个 `FilterItem` 会由 `permeateCardIDToFilterItem()` 回填 `cardID`。

特殊：`AIType.cutout` 不展示普通 filter tab，而是从 cutout 卡片中取第一个 filter，并把展示名改成“抠图”。

## 选图流程

### 单图

1. 点击 Choose a photo。
2. 展示 `FilterActionSheetPage`。
3. 用户选择相册或相机。
4. `PhotoModel.uiImage` 更新。
5. `filterModel.originImage = image`。
6. 清空 `filterUrl`，状态变为 `.upload`。

### 双图

条件：`selectedFilter.imageCount == 2`。

1. 点击 Choose two photos。
2. 展示 `FilterTwoPhotoSheetPage`。
3. 依次填入 `twoSelectedPhotos.0`、`twoSelectedPhotos.1`。
4. 两张都存在后：
   - `filterModel.originImages = [first, second]`
   - 关闭选择弹窗
   - 清空 `filterUrl`
   - 状态变为 `.upload`

### 切换模板时图片数量变化

- 从单图模板切到双图模板：`twoSelectedPhotos = (originImage, nil)`，要求补第二张。
- 从双图模板切到单图模板：清空 `originImage` 和 `twoSelectedPhotos`，要求重新选择。

## 会员拦截

`startUpload()` 先调用 `canFilter()`：

- Cutout：非 VIP 一律不可制作。
- 其他类型：如果当前 filter `vip_need == true` 且用户非 VIP，不可制作。

不可制作时：

| 用户状态 | 行为 |
| --- | --- |
| `freeVipTimes > 1` | 弹会员样式 1，可“试用效果”或去 VIP |
| `freeVipTimes == 1` | 弹会员样式 2 |
| `freeVipTimes == 0` | 直接打开会员页 |

可以制作时：

- 单图必须 `originImage != nil`。
- 双图必须两张都存在。
- 否则 toast：`Please select picture`。

## 制作请求

点击 Generate 后：

1. 记录埋点“开始应用滤镜”。
2. 保存 `UserDefaults["start_filter_time"]`。
3. 设置上传通道：

```swift
uploadType = (selectedFilter.ossType ?? "ali_oss") == "ali_oss" ? .ali : .firebase
```

4. `filterModel.isUploading = true`。
5. `UploadPage` 展示并开始 `UploadTask.upload()`。
6. 最终走统一 `/api/image_generation` + `/api/query_result`。

## 结果页能力

制作成功后进入 `.display`：

- 展示生成图。
- 非 VIP 图片叠加水印资源 `filter_watch_mark`。
- 非 VIP 显示 `No Watermark` 按钮，点击打开会员页。
- 单图支持按住对比原图。
- 可重新选图。
- 可点击当前 filter 重做。
- 如果当前 card 配了 `relation_card_id` 和 `relation_card_media_desc`：
  - 展示“制作视频”按钮。
  - 首次展示视频气泡，点击后用 `hasClickedRelationVideoBubble` 持久化隐藏。
  - 跳转 `videoVerticalLists(cardId: relationCardID, presetVideoImage: generateImage)`。

## 制作完成后的本地保存

`UploadPage` 在 `.done` 时，如果类型是 filter/avatar/hair/cutout/photo/outfit/video：

1. 创建 `FilterBackground`：
   - `createTime = uploadModel.startDate`
   - `filterId = filterItem.id`
   - `generateUrl = genenrateUrl`
   - `taskId = taskId`
2. 保存到 FMDB 表 `filter_background`。
3. 非视频类型会把原图保存到 Documents：
   - `origin_images/{localId}/1.jpg`
   - `origin_images/{localId}/2.jpg`

这个机制支撑个人中心作品详情的原图/结果对比，重构时建议保留。

## Filter 模块必须保留的后端字段

- `card_id`
- `category_id`
- `filters`
- `filter_id`
- `vip_need`
- `oss_type`
- `input_require.image_count`
- `input_require.people_numbers_one_image`
- `wait_seconds`
- `processing_copywritings`
- `relation_card_id`
- `relation_card_media_desc`
- `custom_parameter`
- `combine_configs`
- `max_input_count`
