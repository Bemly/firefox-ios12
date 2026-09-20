# iOS 12 兼容与优化

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

## iOS 12 兼容门禁清单（原 browser/IOS12_GATES.md，2026-09-16 并入本文件）


记法：**[SHIM]** = 有真实 fallback（iOS 12 上功能正常）；**[GATE]** = 功能在 iOS 12 上直接缺失，
以后补 fallback 就按这张表找。新增 iOS 13+ API 门禁时同步更新本节；写法约定：
整类型/扩展加 `@available(iOS 13.0, *)`，调用点用 `if #available` 包住。

- Helper 扩展点 [SHIM，已真机验证]：`Helper/Info.plist` 的 `NSExtensionPointIdentifier`
  用 `com.apple.app.non-ui-extension.multiple-instances`（`com.apple.ar.viewer` 是 13.4+，
  iOS 12 会拒装整个包）。2026-09-16 已验证：可装机 + 网页正常渲染（子进程能起）。
- Swift 并发运行时（历史教训）：光删 `async/await` 不够，`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`
  + `@MainActor` 会让编译器链接 `libswift_Concurrency.dylib`（最低 iOS 13），iOS 12 上
  dyld 直接启动崩溃。pbxproj 四处配置已改为 `nonisolated`/`NO`，编译目标内无 `@MainActor`
  （`ThirdParty/BlurUIKit` 内两文件仍有注解，但未编入 target，无害）。
  合并上游代码时凡见 `async/Task/@MainActor` 一律手工 port 成 completion 风格。
- 语义色/圆角/材质 [SHIM]：`UICompat.swift` 的 `UIColor.app*`、`UITableView.Style.appGrouped`
  （`insetGrouped`→`grouped`，调用点已收敛为 shim）、`CALayer.applyContinuousCornerCurve()`、
  `UIColor.appDynamic`（`init(dynamicProvider:)` 回退，取浅色分支）、`appResolved`、
  `UIFont.appMonospacedSystemFont`（Menlo 回退）、`UIStatusBarStyle.compatDarkContent`、
  `UIBlurEffect.Style.appChromeMaterial/appMaterial`（→`.regular`）。
  注意批量替换误伤过：`PromptChoice.separator`（布尔属性）、`ContextTarget.link`、
  `InformationRow.link`、`NSAttributedString.Key.link` 不是颜色，别碰。
- 上下文菜单（`UIContextMenuInteraction`/`UIMenu`/`UIAction`）[GATE]：iOS 12 无此 API，
  长按无反应。门禁点：Homepage 三区 delegate、Library（书签/下载菜单）、
  `ContextMenuCoordinator`、`AddressBar` 扩展 + `addInteraction` 调用点、
  `ToolbarButtonMenus` 4 个 delegate 类（数组用 `[AnyObject]` 存）、
  `TabOverview` 清除菜单（`installMenu`/`make` 整体 `@available`）、
  `ApplicationMenuBuilder` 整文件 `@available`（main.swift 里注册观察者同样门禁）、
  `UIMenuController` 新旧 API（见坑位速查 UIMenuController 条）。
- SF Symbols [SHIM]：`reynard.*` 图标已转通用 template `.imageset`（`generate-ios12-icons.py`），
  `UIImage(named:)` 两端通用；`SymbolConfiguration`/`setPreferredSymbolConfiguration` 调用点
  用 `if #available` 包住，else 分支用 `compatibleWith: nil` 加载。
- Scene 生命周期 [GATE]+[SHIM]：`SceneDelegate` 整类 `@available(iOS 13)`；iOS 12 走
  `main.swift` 里 `didFinishLaunchingNotification` 观察者建窗（引擎调 `UIApplicationMain`
  用的是自己的 `AppShellDelegate`，`AppDelegate` 方法根本不执行，留空即可）。
  `windowScene` 一律走 `compatInterfaceOrientation/compatIsForegroundActive` helper；
  `statusBarOrientation` 替代方向，`statusBarFrame` 替代高度；`AppAppearanceController`
  在 iOS 12 直接 no-op（无深夜模式）。
- 零散门禁：`RelativeDateTimeFormatter`→短日期（`UserDataSuggestionCell`）、`UITabBarAppearance`
  →legacy tint、`QLThumbnailGenerator`→占位图标、`ListFormatter`→逗号拼接、
  `isModalInPresentation` 直接门禁、`hasDifferentColorAppearance` 门禁（iOS 12 永 false）、
  `UIKeyCommand.propertyList` 门禁、`UIActivityIndicatorView(style:.large)`→`.whiteLarge`+灰色、
  `configureUnsandboxedAppDataDirectories` 跳过 iOS 12。上游 `cb41797` 删了
  `deviceSensors` 权限提示，合并时同步删（别留着 `.deviceSensors` 引用，会编不过）。


## iOS 12 优化实录（2026-09-16，真机验证）


- Tab 缩略图：`WebContentView.makeThumbnail()` 原来全分辨率 @2x（~12MB/张常驻内存），
  现长边封顶 672px（~0.5MB），卡片观感无差（TabOverview 截图验证）。
- `NSCache` 必须用 `countLimit`：插入没带 cost 时 `totalCostLimit` 永不触发。
  四处（Addon 图标 ×2、下载图标/占位）已加 64/64/64/128。
- 阴影必须配 `shadowPath`：只设 `shadowOpacity/Radius/Offset` 不设 path 时，
  CoreAnimation 每帧离屏光栅化算阴影形状。已补 `AddressBar` 背景和
  `TabOverviewCard` 预览阴影（`layoutSubviews` 里按 bounds 更新）；其余站点早有。
  注意阴影只影响合成帧率，不影响加载（网络/解码/排版），别指望动阴影加快加载。
- 单进程不需要预热：`dom.ipc.processPrelaunch.enabled=false`
  （`PreallocatedProcessManager` 在本移植恒为 true，会白起 Helper 子进程；
  `patches/mobile/ios/app/mobile.js.patch`）。
- iOS 12 去 blur：backdrop blur 每帧重采样，A7 吃不消。`UICompat.appDisableBackdropBlurForIOS12()`
  （13+ no-op）+ `view.effect == nil ? 不透明色 : 半透明色`，13 站点（chrome 7 + 主页卡片 6），13+ 零变化。
- 长按菜单 iOS 12 回退：`UICompat.CompatMenuAction` + `UIView.compatPresentMenu`
  （actionSheet + popover 锚点），已接 Toolbar 4 菜单和 TabOverview 清除菜单；
  书签/下载/主页/Web 内容页的长按仍是 no-op（待补）。
- **视频硬解结论**：VT 解码器默认即被选中（iOS 不在 blocklist，`CanUseHardwareVideoDecoding`
  默认 true，`force-enabled` 纯多余，别加），session 创建成功；剩余 CPU 是 SWGL 侧
  NV12→RGB+合成，不是解码器问题，真加速等 GPU 合成工程。隐藏视频法可隔离解码成本
  （720p 解码约 16-19%，合成约 20-30%）。
- user.js 生效，但 `false` 等于默认值时不落 prefs.js（别拿 prefs.js 有无当判据）；
  改完 user.js 必须杀进程重进（退出时会重写 prefs.js，见上文）。
- 本体 chrome 去圆角阴影实验（`PERF flat-chrome` 标记）：Toolbar/地址栏（含手势预览浮层）/
  ActionBar 三件套/ChromeOverlay/TabOverviewToolbar/LibraryActionButton/TabBar 药丸/
  个人收藏（含文件夹 cell）的 cornerRadius 常量归 0、
  `shadowOpacity` 归 0、`layoutSubviews` 里 `shadowPath=nil`（不再算圆角 shadowPath）。
  后续又拉平：经常访问卡片（`previewCornerRadius`，注意内层用
  `max(0, radius-padding)` 防负数）、最近关闭药丸（`height/2` 胶囊改 0）、
  私密浏览卡片。
  `clipsToBounds/masksToBounds` 和 `applyContinuousCornerCurve()` 调用保留原样
 （radius=0 时无离屏 mask 成本；iOS 12 上 continuous 本来就是 no-op）。回退：搜
  `PERF flat-chrome` 恢复常量即可。注意这只影响 UIKit chrome 合成，不影响 Gecko
  SWGL 网页合成帧率（见“媒体/视频现状”），别拿网页滚动帧率当验收标准。


## 警告处理经验（2026-09-16，101 条 `-Wunguarded-availability-new` 清零）


- **`__builtin_available(macOS…)`/`@available(macOS…)` 在 iOS target 上恒为 true**
  （IR 实证：`br i1 true`，编译器静态折叠）。凡写错平台的守卫分支在 iOS 12 全都会执行，
  是批量真 crash 来源（修：`__builtin_available(iOS 14.0, macOS 11.0, *)` 双写）。
- SDK 注解“iOS 17+”的 VT key 是 weak 链接，12 上可能是 nil：字典 key 用前必须
  nil-check（nil key 进 `CFDictionaryCreate` 直接崩），`Set/Copy` 类调用天然安全
  （返回错误码）。decoder spec key 已被 session 创建成功反证非空。
- 消警告三板斧（按顺序选）：① 真 bug 用 `@available` + fallback 修
  （修出三个：`isSuspended` 缺失导致 iOS 12 相机全隐藏、`IsCGColorOpaqueBlack`、
  `LogSurface` 的错平台守卫）；② 纯类型提及用 `id`/方括号动态派发
  （`configureTextInteractionForTouchInput:(id)` + `[obj prop]` 不警告不断链）或
  `API_AVAILABLE` 注解 delegate 方法（编译器自己会提示）；③ 已实证安全的用窄 pragma
  （uikit 文件已有先例 `GeckoPointerSupport.mm:71`）。
- 改完引擎源码必须 regen 对应 `patches/`（`git diff` 生成）+ reverse-check；
  新文件走 glob 自动发现，无需注册。验证用 touch 定点重编 + grep 日志，不要全量等。

