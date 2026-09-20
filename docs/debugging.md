# 调试与坑位速查

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

## 调试


- 日志：`idevicesyslog`，崩溃：`/var/mobile/Library/Logs/CrashReporter/`。
- 真断点：手机
  `/usr/local/bin/debugserver12 0.0.0.0:1234 -a <pid>`，Mac `iproxy 1234:1234`，再用
  **26 的 lldb**（15 的 lldb-1500 会在 `target create` 本工程二进制时崩溃，无 target 裸连才可用）：
  `platform select remote-ios` → `target create <本地.app/二进制>` → `process connect connect://127.0.0.1:1234` →
  `bt` → `b` → `process detach`。实测堆栈可符号化到 `XUL`Run at nsAppShell.mm:308`。
- debugserver 丢了重提 (Mac `/tmp` 重启会丢，不要当永久存储)：
  `hdiutil attach Xcode15 DeviceSupport/12.4/DeveloperDiskImage.dmg` → 拷出 `usr/bin/debugserver` →
  `scp -O` 上机 → 按上文 4 项 entitlement `ldid -S` 签名。注意机上没有 `pkill`，kill 用 `kill $(ps aux | grep ... | awk '{print $2}')`。


## 本地诊断页（设置 About 区版本号上方，2026-09-16 已装机验证）


- 测试页收进仓库 `browser/Reynard/Resources/Diagnostics/`（anim/bench/hidden/test/video/video240 共 6 页
  + 两份 mp4，扁平存放无子目录），高级 > Developer 下 4 行入口
  （JIT Bench / Video 720p / Video Drops 240p / Animation Composite），点开走
  `file://` 直接加载包内页。验证：`IMG_0187` 点行即开 tab，
  `RUNS[78,66,67,67]` warmup 形状 = Release 下主进程 JIT 正常。
- Xcode 的 Resources phase 是**空的**（历史遗留，`Assets.car`/lproj 靠工具链自动编）。
  ~~打包时 Mac 端手工拷 Diagnostics~~ **该惯例已废（2026-09-20）**：工程实为 Xcode16
  文件系统同步组（`PBXFileSystemSynchronizedRootGroup`），Resources 下散文件**自动进包
  但拍平在 bundle 根**（不保留 Diagnostics/ 子目录）。诊断页"点开没反应"根因即此：
  `diagnosticsURL` 用 `subdirectory: "Diagnostics"` 查找 → nil → 静默失败；旧包能工作
  纯因发版时手工拷过子目录，脚本里从无此步。已改为「先子目录、回落根目录」双查，
  Debug+Release 通用（commit 见 2026-09-20）。
- 自驱进设置链（iPad 上 Library = sidebar，不是 modal）：bottom 6-button stack
  第 4 个 `ToolbarButton` 发 `sendActionsForControlEvents:64` 开书签侧栏 →
  nav `popToViewController` 回菜单 → 对 menu collectionView 调 delegate
  `didSelectItemAtIndexPath:item:3`（settings）→ 按 label 文案找 cell +
  `indexPathForCell` 再调一次 didSelect → `scrollToRowAtIndexPath` 滚到底。
  注意 cycript 读 struct（frame/contentSize）直接抛，用纯对象/整数 API；
  App 内有两个 UITextField，drive 按 delegate 含 `AddressBar` 挑（沿用）。
- 设置 About 区归属（2026-09-17）：诊断 4 行已搬到 高级 > Developer
  （`DeveloperPreferencesViewController` 新 section）；About 新增
  `GitHub - @Bemly`（`github.com/Bemly`），“查看源代码”改链
  `github.com/Bemly/firefox-ios12`；`CURRENT_BUILD = bemly`（本地包括号显示
  bemly，`build-app.sh` 正式打包仍会 sed 盖 SHA，不冲突）。
- 启动恢复开关（2026-09-17）：`Prefs.HomepageSettings.restoresTabsOnLaunch`
 （默认 true，老行为不变），`通用 > 主页 > 启动时` 下多一行 switch；
  门控在 `TabManagerImpl.restoreTabsIfNeeded()` 开头 early-return false。
  验证：关 → kill → 冷启动只剩空白新 tab；开 = 原代码路径（未改）。
  注意 pref 直接写 UserDefaults 要杀进程冷读（内存有 boolCache）。


## 坑位速查


- SSH 会间歇 `Permission denied`（sshd 限流），等几秒重试，不要连续轰。
- `idevicesyslog` 经常静默死亡（输出停在 `[connected...]` 一行），读不到新日志先
  `wc -l` 确认流还活着，死了就 `pkill` 重起一个（同时只留一个）。
- Mac 侧 `iproxy` 放几个小时会变僵（能连上但握手失败），debugserver 连不上先重起
  Mac 侧对应隧道再说（`kill <iproxy-pid>` + 重跑 `nohup iproxy ...`）。
- `debugserver -a <pid>` 长时间没 debugger 连会上自己退出；lldb 这边
  `target create` 完（`preload-symbols=false` 只要几秒）立刻 `connect`，别晾着。
  不要同时起两个 debugserver 挂同一个 pid，会互掐（一个 T 状态、一个空转 CPU）。
- lldb 连上后 `target create` 会丢连接（"Command requires a current process"），
  顺序必须是 create → connect。
- **lldb 脚本化会话必须 `process detach` 收尾**（2026-09-15 血案：直接 kill lldb
  客户端，目标留 STOPPED 无人领，SpringBoard 以 signal 杀掉进程 pid 3528，无
  crash 日志，只能从 syslog `exited abnormally via signal` 反查。若已 kill，
  立刻重连一次 `process detach`；确认目标 `ps` 还在且 cycript 可驱动）。
- 换 App 图标/README logo（2026-09-16）：Mac 没有 ImageMagick，用 ffmpeg。ChatGPT
  导出的 PNG 透明区存的 RGB 是黑的，直接 `format=rgb24` 丢 alpha 会露黑角，必须
  overlay 到边缘采样色（源图 `crop=1:1:8:627` 取色）上压平：icon 三件套 1024
  无 alpha，`assets/logo.png` 保留透明原样给 README 用。
- 引擎 C++ 改动必须 `./mach build` 重编。单文件/少文件改动只要 ~30 秒（1-2 个对象 +
  链 XUL）；约 50 分钟的量级（603 对象 + gkrust）只出现在大规模改动或动
  StaticPrefList.yaml 这类全局生成头时。`.mozconfig` 现直接 pin `/Applications/Xcode26.app`
 （旧文里的 `/Applications/Xcode-beta.app` 兼容软链已不需要，机上也不存在）。
- XUL 链接报 `__isPlatformVersionAtLeast` 未定义：移植的 `@available(iOS 13,*)`
  兼容代码（`NativeLayerCA.mm`/`nsLookAndFeel.mm` 等）会被 clang 降为该 compiler-rt
  符号，而 mozbuild clang 自带 runtime 没有 iOS 切片。`build-gecko.sh` 已自动把
  `DEVELOPER_DIR` 同工具链的 `libclang_rt.ios.a` 补进 `LDFLAGS`（`export` 进
  `.mozconfig`，只影响 target 链接；找不到会告警，换 Xcode 大版本 glob 仍能命中）。
- 新文件 patch 的 hunk 头必须是 `@@ -0,0 +...`；写成 `@@ 0,0`（少了 `-`）时
  `git apply` 不报错但产出 0 字节文件，编译/链接期才爆（已踩两次：
  `GeckoEditableSupport.h`、`nsIOSNetworkLinkService.mm`）。改完 patch 必跑
  `repair-headers.py + git apply --check`，并对新文件 `wc -c` 确认非空。
- Xcode 重编会覆盖 `.app` 内一次性 JS 探针（本次 fix 包已无 gvnav/selfdrive 探针，
  属正常）；但 `dist` rsync 会带上源码级正式修（`patches/` 已应用部分），放心。
- `browser/Reynard/Entitlements/` 里没有 `Reynard-Helper.private.entitlements`
  （AGENTS 旧述有误）：Helper/OpenIn/dylib 用 `ldid -S` ad-hoc 即可，只有主二进制
  必须用 `Reynard.private.entitlements`（`get-task-allow`，attach 必需）。
- `browser.addProgressListener` 持的是**弱引用**：listener 只存局部 const 会被 GC，
  后期加载的 WP 日志会无声消失（曾误判为“test.html 无 WP 事件”）。探针须挂强引用
  （如 `this.__wp`）；正式代码同理。
- **Gecko 回调必须回主线程**：`HistoryDelegate` 的 completion 会重进 Gecko
  （`AutoJSAPI::Init`），在后台队列调用即 `EXC_BAD_ACCESS`（`HistoryStore.Queue`
  线程崩溃实录，2026-09-16）。`HistoryStore.recordVisitImmediately/visitedStatuses`
  的 completion 一律 `DispatchQueue.main.async` 再调；上游 `@MainActor` handler
  隐含了这点，port 成 completion 时别丢。
- **UIMenuController 新 API 全是 iOS 13+**：`hideMenuFromView:`/`showMenuFromView:rect:`
  在 iOS 12 上直接调即 `NSInvalidArgumentException`（`unrecognized selector`）。
  引擎侧（`GeckoEditableSupport.mm` 全文件 9 处 + `GeckoTouchSupport.mm` 1 处）已收敛到
  `Hide/ShowChildViewEditMenu` 内联 helper（`respondsToSelector` 守卫， fallback 走
  `setMenuVisible`/`setTargetRect:inView:`）；Swift 侧同理用 `#available`。
  另：`UITextInteraction +textInteractionForMode:` iOS 12 根本不存在，
  `setupTextInput` 已加 `respondsToSelector` 守卫；`nsWindow.mm` 里把可能为 nil 的
  interaction 塞进 `@[]` 字面量会崩（`initWithObjects:count: attempt to insert nil`），
  已加 nil 判断。
- **iOS 12 上为 nil 的 UIKit 全局量不能解引用**：`UISceneDidActivateNotification` 等
  scene 通知常量在 iOS 12 是 nil，`addObserver:name:` 传 nil 等于收**所有**通知还是小事，
  真机会在 `didFinishLaunching` 里直接 `EXC_BAD_ACCESS`（`nsAppShell.mm.patch`
  已用 `@available(iOS 13,*)` 包住四个 scene 观察者；定位法：atos 到
  `didFinishLaunchingWithOptions +244` + 反汇编看 GOT 取空）。
- Debug 包的 `assertionFailure` 在真机即 `SIGTRAP` 崩溃：`FaviconStore` 的
  SafariSharedUI 私有方法在 iOS 12 缺失，原来直接 `assertionFailure`，
  已改静默回退默认值。凡是“新系统才有”的私有 API 探测，失败路径一律静默回退，
  不要断言。
- 包名已改为 `moe.bemly.reynard`（2026-09-21 纠正写反的 `reynard.bemly.moe`）：改点含 pbxproj 四处
  `PRODUCT_BUNDLE_IDENTIFIER`、Info.plist 的 `CFBundleURLName`、主/Helper 的
  `application-identifier`、代码里 `com.minh-ton.Reynard` 字符串
  （菜单 ID/队列 label）、`tools/release/create-ipa.sh`；`DEVELOPMENT_TEAM`
  （签名 team）不动。注意改包名 = 新 profile（缓存目录按 bundle id 拼），
  但 `.mozilla` 旧 profile 仍在，session restore 可能拉起旧 tab。
- 引擎 `.sys.mjs` 是纯文本散文件（dist 经软链直接读源码，app 包里是 rsync 来的拷贝）：
  改完**源码**要同步镜像到 `.app` 拷贝再打包，不用重新编引擎；但正式修必须同时落
  `patches/`（`git -C engine/firefox diff -- <path>` 生成，`apply-patches.sh` 格式）。
  改 app 拷贝里的 JS 做实验最快（重打包 2 分钟），但重编 Xcode 会覆盖，悠着点。
- JS 模板字符串里 `${...}` 内部**不能**写 `\"`（会吞掉字符串边界），用单引号。
  `.sys.mjs` 语法检查：拷成 `/tmp/x.mjs` 用 `node --check`。
- `.sys.mjs` 各文件是独立模块作用域，跨文件 helper（如 gvProbeLog）每个文件都要
  各自定义一份；`setTimeout` 模块作用域没有，用 `this.window.setTimeout`。
- `Services.dns.asyncResolve` 参数个数和文档不一致会报 NS_ERROR_XPC_NOT_ENOUGH_ARGS，
  先查签名再调（当前该探针是坏的，别直接抄）。
- 给引擎加文件日志：`Cc["@mozilla.org/file/local;1"]` + `file-output-stream` 写
  `/tmp/*.log`（app 是 `platform-application` + `no-sandbox`，可写），再 `cat` 回看。
  `dump()` 输出到 stderr，GUI App 看不到，别用。
- user.js 改偏好无需重编（`user_pref("network.http.spdy.enabled", false);` 这类），
  改完杀进程重进即生效；注意 Firefox 退出时会重写 prefs.js，活着的时候别直接改 prefs.js。
- `launchctl setenv MOZ_LOG...` 对 SpringBoard 起的 App 不生效，别试了。
- profile 在 `/var/mobile/Library/Application Support/.mozilla/firefox/u51lzeog.default/`；
  places.sqlite 可能是 0 字节（本移植历史记录没启用），别拿它当判据。
- 状态确认三件套：`ps` 看 pid/CPU（转圈≈在干活，0.0%≈卡死）、`netstat -an` 看连接及
  Send-Q/Recv-Q、`ls -lt .../CrashReporter/` 看新崩溃（`0xdead10cc` 是后台握锁被杀，
  `0x8badf00d` 是看门狗，加载卡死本身不崩溃）。

