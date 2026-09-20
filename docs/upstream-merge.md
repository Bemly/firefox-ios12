# 上游合并与 Git 约定

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

## Git 约定


- `.github/workflows/` 只保留我们自己的 `sync-upstream.yml`（定时同步上游+构建+发版，
  见下）；上游的 workflow 文件在本 fork 用不上（本地构建+ldid），合并上游时若复活，
  解完冲突后删掉上游文件、只保留 `sync-upstream.yml` 再提交。

- **平时不得手动上传/覆盖 GitHub release 资产**（2026-09-21 用户明确规定；
  09-18 那次滚动覆盖是最后一次手动操作）。**唯一例外是 `sync-upstream.yml` 自动化**：
  它按 `CURRENT_VERSION` 打 tag `<version>-ios12`，同名 release 删掉重建、没有则新建。
  新包平时只放本地 `dist/` + 仓库外备份目录。

- `main` 跟踪 `bemly/main`（公开主线），保持干净可编；推送前先确认与 `bemly/main` 同步。
  `origin/main` 是上游只读存档，早已分叉，不要以它为基准、不要往它推。
  不要在 main 上堆验证代码。
- 2026-09-16 起公开仓库为 https://github.com/Bemly/firefox-ios12（remote `bemly`），
  由 `local/jit-main-process-a7` 强推为 `main`。曾用 filter-branch 剥离上游误提交的
  94MB `browser/Reynard/JIT/RPPairing/libidevice_ffi.a`，但改写 SHA 会切断与上游的
  共同祖先、后续合并必炸，用户决定**不剥离**，历史已恢复原样（接受该 blob）。
- 验证性/过期代码放 `archive/*` 或 `local/*` 分支。已有：
  `archive/expired-validation-20260915`（launch-logging 验证，+43/-3），
  子模块内对应 `engine/firefox` 的 `archive/diag-launch-log`（`4a3f369` 写 `/tmp/ReynardLaunch.log` 的诊断提交）。
- `local/white-screen-probe`：白屏排查分支。含 Swift NSLog 探针（EventDispatcher
  attach/activate/dispatch 分支、Progress/Navigation 事件）、四个引擎正式修
  （remoteTab `?.`、iOS 去 remote 属性+不设 maychangeremoteness、C++ 单进程
  parent 放行 ×2，均有 `patches/` 文件）。2026-09-15 夜白屏已修好
  （test.html PageStop=1 + 渲染 REYNARD-LAN-OK，包 `/tmp/Reynard-fix1.ipa`）。
  注意：装机包里的 JS 探针（`/tmp/gvnav.log` 系列、selfdrive 自动加载、WP listener）
  是直接改 DerivedData 内 `.app` 拷贝做的**一次性实验**，没进 git，重编即丢；
  转正前要么删掉、要么按“debug 模式开关”收敛（用户已要求，待做）。
- （UDID/ECID/序列号已按要求从本文删掉。）


## 上游合并实录（分支 `merge/upstream-20260917`，上游 d9f2dc9→5d08f38 共 6 个提交）


- 内容：toolbar inset 三连（APZ/ContentEventHandler/WR/PresShell 的 `patches/`）、
  reader mode（900+ 行 Swift + readerview 引擎文件）、find-in-page 新图标、
  action bar iOS 26 改款。
- 冲突 6 文件解法（iOS 12 适配优先）：addon 三件套 async→completion
  （+补上游新增 `ensureBuiltIn`）；EventDispatcher 删 Task 桥（留 `AnyObject` 约束，
  否则 `$0 === listener` 编不过）；AddonMessaging.swift 整文件 port；
  AddressBar 收 reader（`addonsMenu` 保持 `Any?` + `#available` 门、`isReaderActive` 门外赋值，
  `.label` 改 `.appLabel`）；两 action bar 保 PERF flat-chrome（radius 归 0）。
- ReaderSettingsViewController 整文件 port：语义色/material 全换 UICompat shim、
  `cornerCurve` 改 `applyContinuousCornerCurve()`、`setPreferredSymbolConfiguration`
  + `preferredSymbolConfiguration` 加 iOS 13 门、UIAction 构造收进 iOS 14 门内
  （类 iOS 12 不存在，构造即崩）、`withDesign` 回退系统字体、brightness 观察者加 iOS 13 门、
  去 `nonisolated`；BrowserPreferences 里 `connectedScenes` 加 iOS 13 门（12 永浅色）。
- 图标：`generate-ios12-icons.py` 重跑（18/18，含新增 text.page 两件套）。
- 引擎：submodule 指针上下游一致（`fb95137`，上游没 bump），14 个 patch 文件先经
  pristine worktree `--check` 全过，再 `reset --hard + 删 50 个新文件目标 + apply-patches.sh`
  全量重打成功。注意 C++/Rust hunks 要下次 `./mach build` 才进 dist（当前 dist 仍是旧的）；
  `.sys.mjs`/manifest 类文本文件下次 Xcode 构建经 rsync 即生效。
  `reset --hard` 前必先对 dirty 树与 `patches/` 覆盖率（本次 349 全对上，含一个删除型 patch）。


## 上游合并实录（分支 `merge/upstream-156`，上游 5d08f38→2e383ee：引擎 156）


- 单提交：submodule 155→156 + 80 个 patch 同步。冲突 4 文件（iOS 适配与同步重叠）：
  nsDocShell 取上游头（纯行号漂移）；nsWindow 取上游头（PiP hunk 内容一致）；
  CoreTextFontList = 上游文件 + 我们的 `ActivateFontsFromDir` hunk（mRequiresAAT 被上游收编了）；
  AppleVTDecoder 三个 hunk 按 156 重锚（`CGColorSpaceNameForFrame` 被上游抽出、`__builtin_available` 双写照跟）。
- 血泪两条：① 解冲突别手写 hunk（counts/行尾空格必错），用 `diff -U` 从 pristine 生成；
  ② 全量 `--check` 过之前不要 `reset --hard` 工作树（本次 Pascal 式逐个修：160→156 行号全变）。
- 本次 submodule 缺 156 tag（`apply-patches.sh` 拒跑）：`git -C engine/firefox fetch origin tag FIREFOX_156_0_RELEASE`。
- 工具链三坑（2026-09-17，156 全量编实测）：① 引擎编必须
  `DEVELOPER_DIR=Xcode26`（Xcode27 的 SDK TBD 无 arm64 切片，mozbuild 自带 lld 在
  configure 即挂）；② PATH 最前加 rustup 工具链 bin（自带 ios target，
  Homebrew rustc 编不了 `aarch64-apple-ios`）；③ Release archive 同样走 Xcode26
 （27 的最低 deployment 是 15.0，直接拒 12.4）。App 侧 `xcodebuild` 本体不受影响。


## 上游合并实录（分支 `merge/upstream-20260918`，上游 2e383ee→1498894 共 3 提交）


- 内容：Apple Pencil 前置支持（引擎 patch 7 文件：新增 `GeckoPencilSupport.h/.mm.patch` +
  PointerSupport/TouchSupport/moz.build/nsWindow 重锚）、nsWindow 外观修复
 （`nsLookAndFeel::SetSystemUsesDarkTheme`）、App 侧 shadowPath 三件套
 （AddressBar/TabOverviewCard/TabOverviewPresentation）。**submodule 指针未动**
 （仍 FIREFOX_156_0_RELEASE），不用 fetch tag。
- 冲突 3 文件：TabOverviewPresentation.swift（取上游 + shim 三连：
  `.appSystemBackground`/`applyContinuousCornerCurve()`/`.appSeparator`，borderWidth 新行照收）；
  GeckoTouchSupport.mm.patch（**UIMenuController iOS 12 fallback 保住**，pencil 集成收编，
  hunk 头 358 行）；nsWindow.mm.patch（**nil interaction 守卫保住**，pencil+外观修复收编）。
- auto-merge 陷阱：AddressBar/TabOverviewCard 双方各自加了 `layoutSubviews`，git 能
  **干净合并出重复 override**（编译必炸，不报冲突）。AddressBar 取上游版（引用已归零的
  flat-chrome 常量，零成本；将来回退 flat-chrome 时 shadowPath 自动拿对 path，
  比旧的 shadowPath=nil 回退状态更对），TabOverviewCard 保留我方注释版。
- nsWindow.mm.patch 重建法（推荐流程）：双方 patch 各自 `git apply` 到 pristine 目标文件 →
  `git merge-file` 三方合并 → 解 7 处内容冲突（5 取上游、1 双方合体、1 空白取上游）→
  临时 git 仓 `git diff` 重生成整份 patch（29 hunks，行号自动正确）。本轮 diff 上游只剩
  index 行 + 我方 nil 守卫，干净。
- **新坑（git apply 静默截断）**：new-file patch 的 hunk 头行数比正文少时，
  `git apply --check` 和 apply **都不报错**，只消费头声明的行数、多余的尾行（如 `@end`）
  静默留在补丁外 → 应用文件缺最后一行，编译期才炸（本次 GeckoTouchSupport.mm.patch
  357→358 血案，根因是 `tail -n +N` 起始偏移数错一行）。**校验必须做产物对比**：
  `sed 's/^+//' <(tail -n +N patch) | diff - engine/firefox/<目标文件>`。
- 工具链补充：mach build 的 PATH 要加 `~/.rustup/toolchains/stable-aarch64-apple-darwin/bin`
 ——`~/.cargo/bin` 里没有 rustc/cargo 垫片（只有 cbindgen 等），加了等于没加，
  Homebrew rustc 抢先 → configure 报 ios target 缺失；且**失败的 configure 会改写构建
  配置引发宽域重编**（本轮 dom/gfx/layout 全编了一遍，多花 ~30 分钟）。
- Pencil 代码 iOS 12 安全性已核：全部走运行时 `SupportsIOSVersion`（NSProcessInfo）门禁
 （hover 16.1 / modifierFlags 13.4 / rollAngle 17.5），`UIPencilInteraction` 是 12.1+
 原生可用；iPad mini 2 无 Pencil，recognizer 空转无害。GeckoPointerSupport 里无门禁的
 `allowedTouchTypes` 等弱链调用在 nil receiver 上是 no-op，无需补。
- 验证链：patch 全量 `--check` 通过 → apply → 关键文件与合并目标逐字节 diff 一致 →
  `mach build` 成功（GeckoPencilSupport.o/GeckoTouchSupport.o/nsWindow.o 全重编 + XUL 链接）→
  Xcode26 Debug `BUILD SUCCEEDED`。真机验证通过（2026-09-18，iPhone 5s Release 包
  `/tmp/Reynard-merge.ipa`：冷启主页/example.com 加载（Pencil init 无崩溃）/
  tab overview 开+关（新快照路径 + 边框阴影样式正常）/无新崩溃日志，
  RSS ~20%）→ 已推 bemly/main。测试注意事项：① 上机前把
  `default.HomepageSettings.restoresTabsOnLaunch` 用**设备端 python3 plistlib**
  关掉（scp 推回会被 sshd 限流卡死；且 `kill cfprefsd` 后 USB 隧道 SSH 会持续
  密码被拒 rc=5，改走 WiFi 直连 `root@192.168.1.10` 即恢复）；② cycript 里
  **NSNotFound 比较有 JS 精度坑**（`==`/`!=` 均不可靠），地址栏匹配要用
  `("" + cls).indexOf(...)`；且 delegate 匹配除了含 "AddressBar" 还必须**排除
  "FindInPage"**（`Reynard.FindInPageActionBar` 也含该子串，模糊匹配会选中
  页内查找框，setText 静默无效）；③ cycript 文件模式 + fopen/fprintf 写
  `/tmp/cydrive.log`（extern 原型）是本机唯一可靠回显通道。
- Release 资产说明（2026-09-18 曾滚动覆盖过一次，此做法已废）：当时 `/tmp/Reynard-merge.ipa` 以
  `Reynard-Jailbroken.ipa` 名义覆盖上传到 GitHub release `0.13.1-ios12`。
  **现行规定：GitHub release 保留原样，任何人不得上传新资产、不得覆盖已有资产。**
  新包只放本地 `dist/`（+ 仓库外备份目录）。
  坑：该包 CFBundleVersion 戳是 `b080a71`（build-app.sh 在旧 HEAD 时跑的），
  **实际内容=9404527 合并树**——判断包内容以二进制符号为准，别信版本戳：
  XUL 里 grep `GeckoPencilSupport` 符号 + Diagnostics 有 cssanim/webgl-anim。


## 上游合并实录（分支 `merge/upstream-20260920`，上游 62c3cac→0019395 共 7 提交）


- 内容：0.14.0 版本号、Crowdin 翻译、toolbar-inset 大修（APZ/PresContext/
  BrowserChild/nsWindow 等 27 个 patch）、iPad 横屏、全屏触摸偏移、cubeb
  RemoteIO 崩溃修。**submodule 指针未动**（仍 3bf8f468），但 C++ patch 面大，
  合并后必须重打补丁 + mach build。
- 冲突 3 文件：`Reynard.xcconfig`（取上游 0.14.0，保我方 12.0 部署目标）；
  `ContentView.swift`（我方 self. 闭包版 vs 上游新公式——保 self. 版、吸收
  `focusedInputBottom: viewportFrame.minY` 一行）；`nsWindow.mm.patch`
  （见下）。
- **nsWindow.mm.patch 重建流程（比 0918 更顺）**：双方 patch 各自**普通
  `git apply`** 到临时仓的 pristine 文件（不要先 `--3way`——unmerged index
  会让后续 checkout 静默失效，冲突标记混进文件让 patch(1) 误报 reversed），
  `diff` 成品确认 `FocusForHardwareKeyboard` 等区两边逐字节相同后 `git
  merge-file`（**别带 -p**，带 -p 结果进 stdout、第一个文件原样不动），
  9 处冲突按索引批量裁决：1-5 取我方（textInteraction nil 守卫 + 等价区），
  6-9 取上游（SetFixedLayerMargins 早退、`offset` 公式、
  `UpdateDynamicToolbarHeights` 改名、`setDynamicToolbarMaxHeight:minHeight:`），
  临时仓 `git diff` 重生成 1557 行整份 patch，最后 pristine+新 patch roundtrip
  逐字节 == 合并成品才入库。
- **patch 集合变化触发的覆盖率校验新形态**：上游这次**删了**
  `ExpectedGeckoMetrics.cpp.patch`、**新增** `nsCSSRendering.cpp.patch`，
  脏树 vs patch 覆盖的集合差不再是"全等"——出现
  dirty-not-patched（旧补丁残留，reset 后归 pristine）和
  patched-not-dirty（新补丁待打，重打后变脏）各 1 个属**预期**，
  逐个能解释即可 reset。52 个新文件目标 reset 后要删干净再 apply。
- 357 补丁全量重打零冲突；产物校验三连：新文件 wc -c 非空 ✓、
  删除型 patch 目标 == pristine ✓、nsWindow.mm == 合并成品 ✓。
- **血案二连（都在 mach build 环节）**：① 我合的 nsWindow.mm 有拼接错误
 （merge-file 在 4/5 两冲突间留下的"共享区"其实属于函数体内部，两边都取 ours
  会把函数提前闭合、剩余体成孤儿；brace 平衡检查挡不住这种错，靠编译才暴露）。
  教训：patch 重建后必须**双向全文件 diff**（合并成品 vs 我们版 应=恰好上游改动；
  vs 上游版 应=恰好我方改动），逐 hunk 过目后再入库。② 上游合并重编时**直接
  `./mach build` 会吃进陈旧 .mozconfig**——build-gecko.sh 原本构建后恢复
  12.4 时代的 .mozconfig.bak，结果 XUL 链出 minos=12.4（等于白编，12.2 设备
  照样 dyld 拒载）。已改脚本：生成的 mozconfig 持久化、不再恢复陈备份；重编
  引擎一律走 `tools/development/build-gecko.sh`，编完 `otool -l XUL` 验 minos。
- **血案②闭环验证（2026-09-21，iPhone 5s）**：合并后 dist 里 XUL 实测
  `minos=12.4`（strings 含 `GeckoPencilSupport`，代码是最新的，只有目标错——
  坐实"裸 mach 吃陈配置"）；走 `build-gecko.sh` 全量重编 45 分钟后 XUL
  `minos=12.0`（sdk 26.5 不变），Debug 包内主二进制 + 全部 dylib 同为 12.0，
  装机冷启主页正常（IMG_0140）。注意 `.mozconfig.bak` 已不再生成，
  备份恢复逻辑别加回来。
- **Release 12.0 包+iPad JIT 验证（2026-09-21，同分支）**：`0b47449` 提交后
  `DEVELOPER_DIR=Xcode26 build-app.sh --no-signing`（27 拒 12.0 目标，必须指定 26），
  `create-ipa.sh --jailbroken`，包 `dist/Reynard-Jailbroken.ipa` 戳与 HEAD 一致。
  拆包 39 个 Mach-O：iOS 实际装载的 21 个全 `minos 12.0`
  （主二进制/XUL/GeckoView/gecko dylib/appex/ptrace 双 helper）；
  17 个 `libswift*.dylib` 是工具链自带的 `LC_VERSION_MIN_IPHONEOS 7.0` 老格式
  （最低 iOS 7，照载）；`nsinstall` 是 platform=macOS 的宿主工具（旧包同样存在，
  iOS 不加载）。iPad 装机冷启 + cycript 驱动地址栏加载包内 `bench.html`，
  `RUNS[75,68,66,66]`（IMG_0207）= Ion 稳态，Release 下 JIT 正常。
- **CI 首包验证（2026-09-21，iPad）**：`gh run download` 取 run 35530802200 的
  `Reynard-Jailbroken.ipa`（短直链 blob 只有几十秒有效期，409 即过期，走 gh 通道），
  包名 `moe.bemly.reynard`/0.14.0、主二进制+XUL 皆 `minos 12.0`。
  装机（新包名=新 App，旧 `reynard.bemly.moe` 并存）冷启 + 同法驱动 bench，
  `RUNS[83,73,73,69]`（IMG_0208）= Ion 稳态，CI 链产物 JIT 正常。




