# 首页视频 Cell 展示、播放与本地缓存

## 1. 文档范围

本文从 `HomepageItemsCollectionView` 入口向下追踪首页视频卡片的实际实现，覆盖：

- 视频类 `Card` 如何选择 Cell；
- 外层纵向列表、内层横向列表和单个视频 Cell 的 UI 布局；
- 封面图与真实视频 URL 的字段来源；
- 视频下载、落盘、命中与尺寸缓存；
- `AVPlayer` 初始化、播放、暂停、恢复、循环和 Cell 复用；
- 应用前后台、音频中断和页面 Tab 切换时的当前行为；
- 现有实现中的边界问题与优化方向。

> 本文中“本地化”指视频文件的本地缓存，不是多语言本地化。

## 2. 关键文件与职责

| 文件 | 职责 |
| --- | --- |
| `Views/HomePage/List/HomepageItemsCollectionView.swift` | 首页外层纵向 CollectionView，根据 `home_style` 选择 Cell，在整行离屏时暂停可见视频 |
| `Views/HomePage/List/HomepageCardStyle.swift` | `home_style` 到 Cell 类型、高度的映射 |
| `Views/HomePage/Cells/HomepageVideoBigRowCell.swift` | 视频卡片行，内嵌横向 CollectionView，负责下载触发、播放和内层离屏暂停 |
| `Views/VideoPage/VideoPlayCell.swift` | 单个视频的封面、标题、渐变、`AVPlayer` 和生命周期处理 |
| `Views/VideoPage/VideoDownloadManager.swift` | 下载队列、任务去重、文件落盘、本地命中检查和尺寸缓存 |
| `BasicBundle/Util/CommonUtil.swift` | 通过 `AVAsset` 读取本地视频原始尺寸 |
| `BasicBundle/Extension/String+Ex.swift` | 用 CryptoKit 将视频 URL 计算为 MD5 缓存键 |
| `DataSource/Model/DataSource.swift` | `Card.homepageStyle`、`Card.filters`、`FilterItem.cover`、`operations_cover` 的模型映射 |
| `Views/HomePage/HomePageContrainer.swift` | SwiftUI 首页 Tab 切换，用于判断整页离开时的播放行为 |

## 3. 整体层级

```text
HomePageContrainer (SwiftUI，按 currentType 切 Tab)
└─ HomepageItemsCollectionViewRepresentable
   └─ HomepageItemsCollectionView
      └─ 外层 UICollectionView（纵向）
         └─ HomepageVideoBigRowCell（每个 Card 占一个 section/一个 item）
            └─ 内层 UICollectionView（横向）
               └─ VideoPlayCell × Card.filters.count
                  ├─ UIImageView（封面）
                  ├─ AVPlayerLayer（本地视频）
                  ├─ 视频图标
                  ├─ 底部渐变
                  └─ 标题 / Use 按钮
```

视频卡片不是外层列表直接播放，而是“纵向页面 + 横向卡片行 + 单个播放 Cell”三层结构。

## 4. 数据字段与 Cell 选择

### 4.1 视频样式映射

`Card.homepageStyle` 由接口字段 `home_style` 映射。下列三种样式共用 `HomepageVideoBigRowCell`：

| `home_style` | 枚举 | 含义 | 外层行高 |
| --- | --- | --- | --- |
| `3` | `.videoHorizontal` | 横版视频 | `154` |
| `6` | `.videoSmallVertical` | 竖版小视频 | 根据屏幕宽度计算 |
| `7` | `.videoBigVertical` | 竖版大视频 | `226` |

`HomepageItemsCollectionView.cellForItemAt` 先用 `HomepageCardStyle.cellIdentifier` dequeue，再对 `HomepageVideoBigRowCell` 调用 `configure(with:indexPath:contentOffsetDict:)`。

### 4.2 封面与视频地址不是同一字段

`FilterItem` 中与本流程相关的字段：

| 模型属性 | 接口字段 | 首页视频 Cell 用途 |
| --- | --- | --- |
| `coverImageSource` | `operations_cover` | 取第一个 URL，交给 Kingfisher 显示静态封面 |
| `coverImage` | `cover` | 作为真实视频 URL，用于查本地缓存、下载和创建 `AVPlayerItem` |
| `name` | `name` | Cell 底部标题 |

因此，首帧展示成功不代表视频可播放；`operations_cover` 可用但 `cover` 为空、URL 非法或下载失败时，Cell 会保留静态封面。

## 5. UI 布局

### 5.1 外层页面

`HomepageItemsCollectionView` 内部是纵向 `UICollectionViewFlowLayout`：

- `minimumLineSpacing = 0`；
- `minimumInteritemSpacing = 0`；
- CollectionView 贴满容器；
- 每个 section 只有 `1` 个 item；
- 普通 Card section 头高 `40`，section inset 为 `top: 15, bottom: 40`；
- 外层 Cell 宽度为 CollectionView 宽度，高度由 `HomepageCardStyle.cellHeight` 决定。

视频行离开外层可见区域时，外层 `didEndDisplaying` 会调用 `HomepageVideoBigRowCell.pauseAllPlay()`。

### 5.2 视频卡片行

`HomepageVideoBigRowCell` 内嵌一个贴满 `contentView` 的横向 CollectionView：

- 滚动方向：水平；
- 子 Cell 间距：`12 pt`；
- 左右 inset：`20 pt`；
- 隐藏水平滚动条；
- 背景透明。

三种视频子 Cell 尺寸：

| 样式 | 子 Cell 尺寸 |
| --- | --- |
| 横版视频 | `206 × (206 × 157 / 210)`，约 `206 × 154` |
| 竖版大视频 | `(226 × 157 / 210) × 226`，约 `169 × 226` |
| 竖版小视频 | `width = (screenWidth - 20 - 3 × 12) / 7 × 2`，`height = ceil(width × 131 / 99)` |

`configure` 会把当前横向 `contentOffset` 保存到外层的 `[IndexPath: CGPoint]`，Cell 复用到其他 section 时再恢复该 section 之前的横向滚动位置。

### 5.3 `VideoPlayCell` 视图叠放

`contentView` 圆角为 `12 pt`并裁剪超出内容。从底到顶的主要层级为：

1. `imageView`：贴满 Cell，`.scaleAspectFill`，显示 `operations_cover.first`；
2. `AVPlayerLayer`：贴满 Cell，`.resizeAspectFill`，初始隐藏；
3. `videoIconView`：右上 `6 pt`，`20 × 20`；
4. `gradientLayer`：底部 `60 pt` 高，由深色向透明过渡；
5. `useButton`：右下 `47 × 24`，首页调用默认隐藏；
6. `titleLabel`：左右 `12 pt`，底部 `16 pt`，Rubik `16 pt`，可缩放至 `0.7`。

封面图始终在 `AVPlayerLayer` 下方。`stop()` 会隐藏播放层，因而显示封面；`pause()` 只暂停不隐藏播放层，因而保留暂停时的视频画面。

### 5.4 什么时候显示图片，什么时候显示视频

这里没有删除或替换 `imageView`。封面图一直位于 Cell 底层，显示图片还是视频取决于上层 `AVPlayerLayer.isHidden`：

```text
playerLayer.isHidden == true   -> 看到 imageView 封面图
playerLayer.isHidden == false  -> 看到 AVPlayerLayer 视频画面
```

完整显示条件如下：

| 时机/状态 | 执行的关键代码 | `playerLayer` | 用户看到的内容 |
| --- | --- | --- | --- |
| Cell 刚初始化 | `playerLayer.isHidden = true` | 隐藏 | 封面容器，此时可能还没有图片 |
| `cellForItemAt` 配置 Cell | `imageView.kf.setImage(...)` 后 `stop()` | 隐藏 | Kingfisher 异步加载的 `operations_cover.first` |
| 封面图正在下载 | Kingfisher 尚未回填 | 隐藏 | `imageView` 当前内容；首次加载可能短暂为空 |
| 视频本地缓存未命中 | `fetch` 正在下载，尚未调 `play()` | 隐藏 | 继续显示封面图 |
| `cover` 为空或无法生成 URL | `resumePlay` 的 guard 条件不成立 | 隐藏 | 始终显示封面图 |
| 视频下载失败 | `fetch` 回调 `nil`，不再递归 `resumePlay` | 隐藏 | 始终显示封面图，没有失败 UI |
| 本地文件已就绪 | `update(localUrl:)`，但尚未 `play()` | 仍隐藏 | 仍显示封面图 |
| 就绪后延迟 `0.2s` | `play()` 先显示 layer，再 `player.play()` | 显示 | 切换为视频画面 |
| 横向或纵向离屏 | `pause()` | 保持显示 | 保留视频暂停帧，不退回封面 |
| App 进入后台/音频中断 | `pause()` | 保持显示 | 保留视频暂停帧 |
| App 恢复活跃 | layer 未隐藏时 `play()` | 显示 | 从暂停点继续视频 |
| Cell 复用 | `prepareForReuse()` 调 `stop()` 并清空 `imageView.image` | 隐藏 | 旧视频被遮住，旧封面被清空；等待新封面 |
| 新数据配置到复用 Cell | 再次 `kf.setImage` + `stop()` | 隐藏 | 显示新封面，之后重走视频缓存流程 |

从视觉上看，状态转换是：

```text
创建/复用
  -> 静态封面
  -> 本地视频检查
       -> 缓存未命中：保持封面，后台下载
       -> 缓存命中：创建 AVPlayerItem，仍保持封面
  -> 延迟 0.2 秒调 play
  -> 显示视频
       -> pause：显示暂停帧
       -> play：继续视频
       -> prepareForReuse/stop：隐藏视频层，回到封面层
```

需特别区分“图片封面”和“暂停帧”：离屏、进后台或音频中断调的是 `pause()`，因此播放层没有隐藏，如果此时再看到 Cell，展示的是最后一帧视频，不是 `operations_cover` 封面。只有 `stop()` 才明确退回封面层。

另外，封面图使用的是 Kingfisher 的图片下载/缓存体系，视频使用的是项目自定义 `VideoDownloadManager`。两套缓存相互独立：封面命中不代表视频命中，视频命中也不要求封面已加载完成。

## 6. 本地缓存逻辑

### 6.1 缓存何时启动

视频缓存是按需触发，不是在首页数据返回后一次性预加载所有视频。

1. 外层视频行进入屏幕，内层 CollectionView 开始创建可见 `VideoPlayCell`；
2. `cellForItemAt` 只配置封面和文案，不启动视频下载；
3. 内层 `collectionView(_:willDisplay:forItemAt:)` 调用 `resumePlay`；
4. `resumePlay` 首次访问 `VideoDownloadManager.shared`时，单例按需初始化，创建下载队列并确保缓存目录存在；
5. 只有已触发 `willDisplay` 的 Cell 才会查缓存或发起下载。

当前没有根据可见比例设置阈值，`willDisplay` 一触发就开始。因此同一行内多个即将可见的 Cell 可以同时查缓存和下载。

### 6.2 缓存目录初始化

`VideoDownloadManager.shared` 第一次初始化时确保以下目录存在：

```text
Application Sandbox/Documents/video/
```

使用的 Foundation API：

```swift
let fileManager = FileManager.default
let documentsDirectory = fileManager.urls(
    for: .documentDirectory,
    in: .userDomainMask
).first!
let dirPath = documentsDirectory.appending(path: "video")

if !fileManager.fileExists(atPath: dirPath.path()) {
    try fileManager.createDirectory(
        at: dirPath,
        withIntermediateDirectories: true
    )
}
```

- `FileManager.default`：访问 App 沙盒文件系统；
- `urls(for:in:)`：获取当前 App 的 Documents 目录；
- `appending(path:)`：拼接 `video` 子目录；
- `fileExists(atPath:)`：检查目录是否已存在；
- `createDirectory(at:withIntermediateDirectories:)`：目录不存在时创建。

目录初始化只是单例 init 中的一次性动作。视频文件是持久化文件，App 重启后仍能通过同一 URL 命中，直到文件被手动删除或 App 被卸载。

### 6.3 URL 转缓存 key 和文件名

文件名格式：

```text
MD5(httpUrl.absoluteString).mp4
```

项目在 `String.md5` 中使用 CryptoKit：

```swift
let inputData = Data(url.absoluteString.utf8)
let hashed = Insecure.MD5.hash(data: inputData)
let cacheKey = hashed.map { String(format: "%02x", $0) }.joined()
let fileURL = dirPath.appendingPathComponent(cacheKey + ".mp4")
```

- `url.absoluteString`：使用完整 URL 字符串，query 参数也参与计算；
- `Data(string.utf8)`：转成待哈希的字节；
- `CryptoKit.Insecure.MD5.hash(data:)`：生成 MD5 digest；
- `String(format: "%02x", byte)`：转成小写十六进制文件名；
- `appendingPathComponent`：组合完整本地文件 URL。

示例：

```text
远程：https://cdn.example.com/demo/video?id=10
key：  MD5(上述完整字符串)
本地：.../Documents/video/{32位md5}.mp4
```

不同 URL 会生成不同文件。如果远程内容变了但 URL 不变，仍会命中旧文件。本地统一强制使用 `.mp4` 扩展名，`getVideoFormat(from:)` 虽已定义，当前下载流程没有使用它。

### 6.4 同步检查本地是否命中

`resumePlay` 首先调用 `exsitVideo(httpUrl:)`（源码拼写为 `exsit`）。该方法不发起网络请求，只同步构造本地路径并检查：

```swift
let filePath = dirPath.appending(
    path: httpUrl.absoluteString.md5 + ".mp4"
)

if FileManager.default.fileExists(atPath: filePath.path()) {
    return filePath
}
return nil
```

返回值含义：

- 返回本地 `URL`：认为缓存命中，后续不会请求远程视频；
- 返回 `nil`：认为未命中，进入 `fetch`。

命中标准只是“路径上有文件”。当前不会在这一步校验文件大小、HTTP 缓存头、MIME type、视频轨道或是否可解码。

### 6.5 `fetch` 的二次命中检查

`fetch(httpUrl:completion:)` 内部会再调一次 `exsitVideo`。这样即使调用方没有先检查，或者在两次调用间文件已经落盘，也能直接返回本地结果：

```swift
if let fileUrl = exsitVideo(httpUrl: httpUrl) {
    completion((httpUrl.absoluteString.md5, fileUrl))
    return
}
addDownload(httpUrl: httpUrl, completion: completion)
```

completion 成功值是 `(cacheKey: String, localURL: URL)`，失败值是 `nil`。

### 6.6 下载队列和同 URL 任务管理

`VideoDownloadManager` 使用以下 API 管理下载：

- `OperationQueue`：承载 `VideoDownloadOperation`；
- `maxConcurrentOperationCount = 3`：同时最多执行 3 个下载 Operation；
- `[URL: VideoDownloadOperation]`：`activeDownloads` 记录正在下载的 URL；
- `NSLock`：保护 `activeDownloads` 的检查、新增和删除；
- `operationQueue.addOperation(...)`：将新任务加入队列。

`addDownload` 在锁内先检查 `activeDownloads[httpUrl]`：

- 已有相同 URL：不创建第二个网络请求；
- 没有相同 URL：创建 `VideoDownloadOperation` 并存入字典。

设计目的是同 URL 去重。但当前通过重设 `existingOperation.completionBlock` 接收后来请求，会覆盖原 completion，不是正确的多订阅者实现，详见风险章节。

### 6.7 实际网络请求和文件落盘

`fetch(httpUrl:)` 的流程：

```text
收到远程 URL
  ├─ 本地文件已存在 → 立即回调 (md5, localURL)
  └─ 本地不存在
       ├─ activeDownloads 已有同 URL 任务 → 复用已有 Operation
       └─ 无同 URL 任务 → 新建 VideoDownloadOperation
            └─ URLSession.shared.dataTask
                 └─ 整个 Data 写入 Documents/video/{md5}.mp4
```

单个 `VideoDownloadOperation.main()` 使用的 API 和执行顺序：

1. `URLRequest(url:)` 根据远程视频 URL 创建 GET 请求；
2. `URLSession.shared.dataTask(with:completionHandler:)` 创建 `URLSessionDataTask`；
3. `task.resume()` 启动网络请求；
4. `DispatchSemaphore(value: 0)` + `wait()` 让当前 Operation 等待 URLSession 回调；
5. URLSession 回调中在 `err == nil` 时计算目标路径；
6. `Data.write(to:)` 将完整响应一次性写入目标文件；
7. 设置 Operation 的 `fileUrl` 和 `fileName`；
8. `semaphore.signal()` 结束等待，Operation 进入 completionBlock。

实现类似：

```swift
let request = URLRequest(url: url)
let semaphore = DispatchSemaphore(value: 0)

task = URLSession.shared.dataTask(with: request) { data, response, error in
    if error == nil {
        let fileURL = videoDirectory
            .appendingPathComponent(url.absoluteString.md5 + ".mp4")
        try data?.write(to: fileURL)
    }
    semaphore.signal()
}

task?.resume()
semaphore.wait()
```

这不是边下载边播放：`dataTask` 先把完整视频收到 `Data`，完整写入后才通知 Cell，`AVPlayer` 不会直接播放远程 URL。

当 Cell 离屏时只暂停 `AVPlayer`，不会取消已开始的下载，因此快速滚动经过的视频仍可能继续下载并落盘。

### 6.8 视频尺寸元数据缓存

下载写入成功后，`CommonUtil.getVideoSize` 用 `AVAsset` 读取视频轨的 `naturalSize`，然后写入 `UserDefaults`：

```text
key   = MD5(httpUrl.absoluteString)
value = "{width}-{height}"
```

`getVideoSize(httpUrl:)` 优先读 `UserDefaults`；没有命中时再从本地文件读取，文件不存在则返回默认 `335 × 250`。

尺寸读取用到的 AVFoundation API：

```swift
let asset = AVAsset(url: localURL)
let track = try await asset.loadTracks(withMediaType: .video).first
let size = try await track?.load(.naturalSize)
```

- `AVAsset(url:)`：用本地文件创建媒体资产；
- `loadTracks(withMediaType: .video)`：异步读取视频轨；
- `track.load(.naturalSize)`：获取原始宽高；
- `UserDefaults.standard.set(_:forKey:)`：保存尺寸字符串；
- `UserDefaults.standard.string(forKey:)`：下次快速读取。

在 `HomepageVideoBigRowCell.resumePlay` 中，回调的 `size` 并未参与布局，`getVideoSize` 目前只相当于创建播放项前的一个异步门闩。卡片尺寸完全由 `home_style` 决定。

### 6.9 下载完成后如何切换到本地播放

下载 Operation 完成后：

1. completionBlock 从 `activeDownloads` 移除该 URL；
2. 将 `(md5, localURL)` 回调给 `HomepageVideoBigRowCell`；
3. 调用方通过 `DispatchQueue.main.async` 切到主线程；
4. 检查 `cell.indexPath == indexPath`，避免将下载结果设置给已复用成其他数据的 Cell；
5. 重新调用 `resumePlay`，不直接使用 completion 中的 localURL；
6. 第二次 `resumePlay` 通过 `exsitVideo` 命中刚落盘的文件；
7. `cell.update(localUrl:)` 创建 `AVPlayerItem(url: localURL)`；
8. `AVPlayer.replaceCurrentItem(with:)` 把本地播放项放入已有播放器；
9. 延迟 `0.2s` 后 `AVPlayer.play()`。

这里用到的播放 API：

| API | 用途 |
| --- | --- |
| `AVPlayerItem(url: localURL)` | 把沙盒内视频文件封装为播放项 |
| `AVPlayer.replaceCurrentItem(with:)` | 替换 Cell 之前的视频 |
| `AVPlayerLayer(player:)` | 将 `AVPlayer` 画面显示到 Cell |
| `AVPlayerLayer.videoGravity = .resizeAspectFill` | 按填充方式裁剪视频 |
| `AVPlayer.play()` / `pause()` | 开始和暂停本地播放 |
| `NotificationCenter.addObserver(...AVPlayerItemDidPlayToEndTime...)` | 监听播放结束并循环 |
| `AVPlayer.seek(to: .zero)` | 回到开头重播 |

`AVPlayerItem` 收到的是 `file://.../Documents/video/...mp4` 本地 URL，不是 HTTP URL。所以首次必须等整个文件下载完成，后续命中才能直接播放。

### 6.10 缓存生命周期

当前实现没有：

- 最大磁盘占用限制；
- LRU 淘汰；
- TTL/过期时间；
- 服务端内容变更后的版本校验；
- 下载失败的重试和退避；
- 统一清理入口。

因为文件位于 `Documents` 而非 `Library/Caches`，它们不会像标准 Cache 目录那样由系统按缓存策略自动清理。

### 6.11 本地缓存相关 API 汇总

| 分类 | API | 在当前实现中的作用 |
| --- | --- | --- |
| 封面图 | `imageView.kf.setImage(with:)` | Kingfisher 下载/缓存 `operations_cover.first` |
| 沙盒路径 | `FileManager.urls(for:in:)` | 获取 Documents 目录 |
| 目录管理 | `fileExists` / `createDirectory` | 检查并创建 `Documents/video` |
| 缓存键 | `CryptoKit.Insecure.MD5.hash` | 将完整 HTTP URL 转成 32 位文件名 |
| 并发队列 | `OperationQueue` / `Operation` | 管理最多 3 个同时下载 |
| 并发保护 | `NSLock` | 保护正在下载字典 |
| 网络 | `URLRequest` / `URLSession.shared.dataTask` | 请求完整视频数据 |
| Operation 等待 | `DispatchSemaphore` | 让 Operation 等待 dataTask 回调 |
| 文件写入 | `Data.write(to:)` | 将完整 Data 落盘为 `{md5}.mp4` |
| 元数据 | `AVAsset` / `loadTracks` / `load(.naturalSize)` | 读取本地视频尺寸 |
| 尺寸缓存 | `UserDefaults` | 以同一 MD5 key 保存 `width-height` |
| 主线程回填 | `DispatchQueue.main.async` | 下载完成后回到 UI 线程 |
| 延迟播放 | `DispatchQueue.main.asyncAfter` | 延迟 0.2 秒显示播放层 |
| 本地播放 | `AVPlayerItem` / `AVPlayer` / `AVPlayerLayer` | 从落盘文件创建播放画面 |

## 7. 播放初始化与状态

### 7.1 Cell 初始化

`VideoPlayCell.init` 中完成：

1. 创建封面图、标题、图标和渐变 UI；
2. 创建一个暂无 `currentItem` 的 `AVPlayer`；
3. 设置 `player.volume = 0`，首页预览全程静音；
4. 创建 `AVPlayerLayer`，设置 `.resizeAspectFill` 并初始隐藏；
5. 注册 App 前后台与音频中断通知。

`cellForItemAt` 紧接着调用 `update(imageUrl:title:indexPath:itemSize:)`：

- 设置封面、标题和 `indexPath`；
- 设置渐变 frame；
- 调用 `stop()`，保证初始仅显示静态封面。

### 7.2 开始播放时序

内层 CollectionView 的 `willDisplay` 是自动播放入口：

```text
willDisplay(VideoPlayCell)
  → resumePlay(indexPath, cell)
     → 读取 filter.cover 作为视频 URL
        ├─ 已有本地文件
        │    → getVideoSize
        │    → cell.update(localUrl)
        │       → 清理旧结束通知观察者
        │       → 暂停旧播放项
        │       → AVPlayerItem(localURL)
        │       → 监听 AVPlayerItemDidPlayToEndTime
        │       → replaceCurrentItem
        │    → 延迟 0.2 秒
        │    → cell.play()
        │       → 显示 playerLayer
        │       → player.play()
        └─ 无本地文件
             → fetch 下载
             → 切回主线程
             → 若 cell.indexPath 仍匹配，递归调用 resumePlay
```

延迟 `0.2` 秒是为了等待 Cell 布局稳定，避免播放层出现“画面由大变小”的缩放过程。

### 7.3 播放、暂停与停止的区别

| 方法 | `AVPlayer` | `AVPlayerLayer` | 视觉结果 | 后续恢复 |
| --- | --- | --- | --- | --- |
| `play()` | `play` | 显示 | 显示视频 | 从当前 time 继续 |
| `pause()` | `pause` | 保持当前状态 | 停在当前视频帧 | 再调 `play()` 从暂停点继续 |
| `stop()` | `pause` | 隐藏 | 退回静态封面 | 不归零，再播放仍从当前 time 继续 |

注意：`stop()` 并没有 `seek(to: .zero)`，所以它是“隐藏并暂停”，不是严格意义上的重置。

### 7.4 离屏、再次上屏和循环

- 内层子 Cell 横向离屏：`didEndDisplaying` 调用 `pause()`；
- 整个视频行纵向离屏：外层 `didEndDisplaying` 调用 `pauseAllPlay()`；
- 再次上屏：`willDisplay` 再次进入 `resumePlay`。若本地 URL 没变，`update(localUrl:)` 不替换播放项，然后 `play()` 从暂停点继续；
- 播放到结尾：收到 `.AVPlayerItemDidPlayToEndTime` 后 `seek(to: .zero)` 并立即 `play()`，实现循环。

当前策略会让内层所有可见 `VideoPlayCell` 同时自动播放，也可能让外层同时可见的多个视频 section 一起播放；没有“只播放可见比例最高的一个”这类焦点选择策略。

## 8. 恢复播放与生命周期

### 8.1 App 前后台

`VideoPlayCell` 在初始化时监听：

- `UIApplication.willResignActiveNotification`：调用 `pause()`；
- `UIApplication.didBecomeActiveNotification`：若 `playerLayer.isHidden == false`，调用 `play()`。

`playerLayer` 的隐藏状态在这里被当作“该 Cell 是否应该播放”的标记。因为 `pause()` 不隐藏播放层，App 从后台回到前台时会自动从原进度继续。

### 8.2 音频中断

- 中断开始 `.began`：`pause()`；
- 中断结束 `.ended`：仅在 options 包含 `.shouldResume` 且播放层未隐藏时 `play()`。

虽然首页视频已经设为静音，Cell 仍统一处理音频会话中断。

### 8.3 Cell 复用

`prepareForReuse()` 会：

1. `stop()`，隐藏播放层并暂停；
2. 移除旧 `AVPlayerItem` 的播放结束通知；
3. `currentUrl = nil`；
4. 清空封面和标题；
5. 恢复 Use 按钮隐藏、标题显示的默认状态。

它不会在复用时执行 `player.replaceCurrentItem(with: nil)`，但下一次 `update(localUrl:)` 因 `currentUrl` 已清空，会创建新 `AVPlayerItem` 并替换旧项。

### 8.4 Cell 销毁

`deinit` 会移除播放结束、App 生命周期和音频中断观察者，暂停播放，清空 `currentItem`，移除 `AVPlayerLayer` 并释放引用。

## 9. 整页 Tab 切换的当前行为

Cell 离屏暂停已实现，但整页离开暂停没有显式实现：

- `HomePageContrainer` 通过 `currentType` 条件切换不同 `HomepageItemsCollectionViewRepresentable`；
- Representable 声明了 `onAppear` / `onDisappear` 闭包，但没有使用；
- 没有实现 `dismantleUIView`，也没有向外暴露“暂停当前页全部视频”的方法；
- `contentTable` 是全局字典，会按 `HomepageType` 强引用缓存已创建的 `HomepageItemsCollectionView`。

这意味着 Tab 切换时不能依赖页面或 Cell `deinit` 停止播放。而且“整个 CollectionView 从 SwiftUI 层级移除”不等价于可靠地为每个 Cell 触发 `didEndDisplaying`。因此，当前实现存在切到其他 Tab 后原页可见 Cell 仍继续播放和解码的风险。

回到原 Tab 时，由于返回的是 `contentTable` 中同一个 UIView，纵向位置、内层横向位置和已创建的播放器对象都可能被保留，而不是重新初始化。

## 10. 当前实现的风险与建议

### P0：下载取消可能永久占用 Operation

`VideoDownloadOperation` 的 URLSession 回调在发现 `isCancelled` 时直接 `return`，没有执行 `semaphore.signal()`；`main()` 中的 `semaphore.wait()` 因此可能永久无法结束。同时 `cancelDownload` 只调用 `Operation.cancel()`，没有调用内部 `URLSessionDataTask.cancel()`。

建议改为真正的异步 Operation，或直接由 URLSession task 管理状态；任何退出路径都必须完成状态收口。

### P0：同 URL 的多个订阅者会互相覆盖

`activeDownloads` 命中已有 Operation 时，代码会重新赋值 `existingOperation.completionBlock`。这会同时覆盖第一个请求者的回调和原 completion 中清理 `activeDownloads` 的逻辑：先请求的 Cell 可能永远收不到完成事件，已完成 Operation 也可能残留在字典中。

建议将每个 URL 的 completion 保存为数组，完成后 fan-out 通知所有订阅者。

### P1：整页离开没有统一暂停

建议为 `HomepageItemsCollectionView` 增加 `pauseAllVideos()` / `resumeVisibleVideos()`，并在 SwiftUI Tab 切换或 Representable 的拆卸阶段显式调用。“是否应恢复”应使用页面可见状态和 Cell 可见比例，不应只依赖 `playerLayer.isHidden`。

### P1：延迟播放存在离屏后重新拉起的竞态

本地命中后会无条件延迟 `0.2` 秒执行 `cell.play()`。如果期间 Cell 已经离屏并被 `pause()`，延迟闭包仍可能把它再次播放。

建议保存可取消的 `DispatchWorkItem`，或在执行前检查：Cell 未复用、`indexPath` 仍匹配、Cell 仍属于 window、仍在 `indexPathsForVisibleItems` 中。

### P1：下载缺少内容校验与原子写入

当前只判断 `err == nil`，没有校验 HTTP status code、MIME type、`data` 是否为空和视频是否可解码，并且统一以 `.mp4` 为扩展名。异常响应或不完整文件可能被当成已命中缓存。

建议先写入临时文件，校验响应和 AVAsset 可用性后原子移动到正式路径；失败时删除临时文件。

### P1：没有缓存清理策略

模板视频会长期累积在 `Documents/video`。建议迁移到 `Library/Caches/video`，设置总大小上限、LRU 和 TTL，并提供手动清理入口。如果仍使用 Documents，需明确 iCloud 备份排除策略。

### P2：整文件入内存，且可见 Cell 全部同播

`URLSessionDataTask` 将整个视频作为 `Data` 载入内存；与此同时，多个可见 Cell 会同时创建解码任务。建议用 `URLSessionDownloadTask` 直接下载到临时文件，并按可见比例仅激活一个或少量播放器。

### P2：`getVideoSize` 失败时可能不回调

`CommonUtil.getVideoSize` 只在成功获取视频轨时调用 completion，没有 `catch` 和失败回调。由于首页将它作为播放前门闩，损坏文件可能导致 `cell.update(localUrl:)` 和 `cell.play()` 永远不执行。

建议尺寸获取无论成功失败都必须回调；首页不使用尺寸时，应直接创建播放项，不必等待尺寸。

## 11. 快速时序对照

| 场景 | 当前触发 | 当前结果 |
| --- | --- | --- |
| Cell 刚创建 | `init` + `update(imageUrl:...)` | 创建静音播放器，播放层隐藏，显示封面 |
| Cell 即将显示 | 内层 `willDisplay` | 查本地文件，没有则下载 |
| 视频下载中 | `URLSessionDataTask` 运行 | 播放层继续隐藏，展示 Kingfisher 封面 |
| 视频 URL 无效/下载失败 | `resumePlay` 终止/回调 `nil` | 不切换播放层，一直展示封面 |
| 本地视频就绪 | `update(localUrl:)` + 延迟 `play()` | 显示播放层并静音播放 |
| 内层横向离屏 | 内层 `didEndDisplaying` | 暂停，播放层不隐藏，保留视频帧和进度 |
| 整行纵向离屏 | 外层 `didEndDisplaying` | 暂停该行全部可见子 Cell，不切回封面 |
| Cell 重新上屏 | 内层 `willDisplay` | 本地命中后从暂停进度继续 |
| 播放结束 | `AVPlayerItemDidPlayToEndTime` | seek 到 0 并循环播放 |
| App 失去活跃 | `willResignActive` | 暂停 |
| App 恢复活跃 | `didBecomeActive` | 播放层未隐藏则继续 |
| 音频中断 | interruption began/ended | 暂停；允许恢复且层可见时继续 |
| Cell 复用 | `prepareForReuse` | 隐藏播放层、暂停、移除 item 观察者、清 UI |
| 切换首页 Tab | SwiftUI `currentType` 变化 | 没有显式全页暂停，存在原页继续播放风险 |

## 12. 源码定位

| 逻辑 | 位置 |
| --- | --- |
| 外层列表注册视频 Cell | `HomepageItemsCollectionView.swift:19-44` |
| 整行离屏暂停 | `HomepageItemsCollectionView.swift:577-580` |
| 根据 style 配置视频行 | `HomepageItemsCollectionView.swift:661-675` |
| 外层行高、section header 和 inset | `HomepageItemsCollectionView.swift:688-786` |
| SwiftUI UIView 全局缓存 | `HomepageItemsCollectionView.swift:800-833` |
| 视频行布局、下载与播放时序 | `HomepageVideoBigRowCell.swift:18-151` |
| 视频样式与高度 | `HomepageCardStyle.swift:3-45` |
| `AVPlayer` 初始化和 UI 层级 | `VideoPlayCell.swift:12-130` |
| 播放项替换、play/pause/stop | `VideoPlayCell.swift:168-226` |
| 前后台、音频中断和复用 | `VideoPlayCell.swift:228-283` |
| 下载、落盘和队列 | `VideoDownloadManager.swift:11-206` |
| 读取视频尺寸 | `CommonUtil.swift:10-21` |
| CryptoKit MD5 缓存键 | `String+Ex.swift:12-25` |
| Tab 条件切换 | `HomePageContrainer.swift:133-165` |
| `cover` / `operations_cover` 映射 | `DataSource.swift:276-305` |

## 13. 结论

当前首页视频方案的核心是：先用 Kingfisher 展示封面，可见时将 `cover` 指向的视频整文件下载到 `Documents/video`，之后只用本地 URL 创建静音 `AVPlayerItem`。内层和外层的 `didEndDisplaying` 负责 Cell 级暂停，再上屏时从暂停点恢复，播放结束后自动循环。

该方案能降低二次播放的网络开销，但当前还缺少页面级播放状态管理、可靠的下载取消/多订阅者回调、文件有效性校验和磁盘淘汰策略。
