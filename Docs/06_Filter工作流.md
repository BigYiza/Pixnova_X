# Filter 工作流

## 状态机

| 状态 | 含义 |
| --- | --- |
| `choose` | 未选图 |
| `upload` | 已选图，待生成 |
| `display` | 已生成结果 |

## 初始化

1. 根据入口传入的 `preferredFilter` 找到 AIType。
2. 从 AllData 中筛选同 AIType 的 cards。
3. 根据 `cardID` 和 `filter_id` 定位模板。
4. 没有命中则默认第一个模板。
5. 回填 `cards`、`segmentTitles`、`selectedTab`。

## 选图

单图：

- `FilterActionSheetPage`
- 输出到 `originImage`

双图：

- `FilterTwoPhotoSheetPage`
- 输出到 `twoSelectedPhotos`
- 两张齐全后转成 `originImages`

## 权限判断

- Cutout 非 VIP 禁用。
- `vip_need == true` 且非 VIP 禁用。
- `freeVipTimes` 决定是否弹试用弹窗。

## 生成

点击生成时：

- 设置 `uploadType`。
- 记录 `start_filter_time`。
- `isUploading = true`。
- 进入 `UploadPage`。

## 结果

结果页能力：

- 生成图展示。
- 原图按压对比。
- 非 VIP 水印。
- 重新选图。
- 点击模板重做。
- 挂载视频模板跳转。
- 去水印按钮跳会员。

## 本地保存

生成成功后保存：

- `task_id`
- `filter_id`
- `create_time`
- `generate_url`
- 原图文件

用于个人中心详情恢复原图对比。
