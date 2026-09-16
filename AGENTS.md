# AGENTS.md — iOS 12 真机环境 (reynard-browser-ios12)

本文档记录本地 iOS 12 真机联调环境的准备工作结论，后续会话直接照做，不要重复探路。
`engine/firefox/` 下的 AGENTS.md 是上游文件，与本文无关。

## 工作流铁律

- 每次改完代码（修 bug、加探针、改脚本），必须把 Honest 的经验/坑同步到本文件，然后提交 git。
  本条规则本身也要留在这里，不得遗忘。

## 测试机

- iPad mini 2 (`iPad4,4`), iOS 12.5.8 (16H88)，checkra1n 越狱
  （`/var/checkra1n.dmg` + dropbear；Cydia + Sileo + Substrate 共存，loader app 已删）
- 机上已装: AppSync Unified 102.0 / OpenSSH 8.4 / frida-server 17.17.0 (开机自启)
- `/usr/local/bin/debugserver12`: 从 Xcode15 的 12.4 DDI 提取 (arm64+arm64e)，已 `ldid -S` 签调试权限
  (`com.apple.springboard.debugapplications` + `run-unsigned-code` + `get-task-allow` + `task_for_pid-allow`)
- SSH root 口令：`alpine`（越狱默认）。用法：`SSHPASS='alpine' sshpass -e ssh -p 2222 ...`。
- 本机 sudo 口令：`2328`，需提权时用（例如 `echo '2328' | sudo -S ...`）。
- iPhone 5s (`iPhone6,2`), iOS 12.5.8 (16H88)，checkra1n 越狱（2026-09-17 加入，第二台真机）：
  WiFi SSH 直连 `root@192.168.1.10`；USB iproxy 用 **2233**（`iproxy 2233:22 -u <UDID>`），
  2222 留给 iPad 可并存。两台同 iOS 版本，同一 IPA 可互换验证。
- iPhone 与 iPad 环境差异（2026-09-17 实测）：无 apt-get/plutil/netstat/pkill/Activator；
  已 dpkg 手装 libactivator 四件套（rocketbootstrap/flipswitch/preferenceloader/libactivator，
  deb 从 `https://rpetri.ch/repo/debs/` 拉，依赖也在同源）+ network-cmds（`/sbin/netstat`，
  从设备 Sileo 已刷新的 `/var/lib/apt/lists/*.plist` 里查 `Filename:` 定位 deb URL，BigBoss 索引
  里搜不到该包定义）。设备截图即 `activator send libactivator.system.take-screenshot`。
  iPhone 上 uiopen 拉不起锁屏状态的 App（报错无进程），自动化前先亮屏解锁。

## iPhone 5s 排障实录（2026-09-17，"所有网页打不开 + 三个点闪退"，Debug 包 /tmp/Reynard-debug-fix1.ipa 验证通过）

- **根因一：iOS 按 App 无线数据权限把 App 整个断网**（首要坑，影响任何装机流程）：
  症状=每个网页都 Gecko DNS 错误页（"could not be found"），但设备 shell 里 curl 一切正常。
  实质：该 App **全部 socket（TCP/UDP、含局域网 IP）在内核层秒拒 `EHOSTUNREACH`（errno 65）**，
  nw_path_monitor 永不回调，mDNSResponder 查询也死——系统级按 App 断网（设置→无线局域网→
  「使用无线局域网与蜂窝网络的应用」），首启弹窗被拒/误点即中。iPad 一直没事因为从没弹过/允许过。
  诊断链（可照抄）：设备 curl OK → cycript dlopen 进程内探针 dylib（constructor 写 /tmp 日志：
  getaddrinfo/res_query/原始 TCP/UDP/csops）→ 全挂但 csops=0x2600100f 平台位正常、profile 照写
  全局路径（=no-sandbox 正常）→ 读 `/var/preferences/com.apple.networkextension.plist`
  （NSKeyedArchiver，拉回 Mac plistlib 解）：每 App 记录 `WiFiBehavior/CellularBehavior`，
  **1=拒绝 2=允许**（全表佐证：Safari/AppStore/Firefox/Cydia 全 2，越狱工具+reynard 全 1）。
  修（CLI 法）：`kill nesessionmanager` → Mac 上 python plistlib 把 reynard 两条 1→2 二进制回写 →
  scp 回 `/var/preferences/`（root:wheel 644）→ 杀 App 重启即通（launchd 自动拉起守护重读）。
  已留备份 `/var/preferences/com.apple.networkextension.plist.bak-20260917`。
  GUI 法：设置→无线局域网→底部列表→Reynard→选「WLAN 与蜂窝网络」。
- **根因二：necko 不认 iOS 系统 WiFi 代理**（HTTP 全局代理也无效，neck 走自家 socket+自家 prefs）：
  无 VPN 时被墙站全死、直连站（baidu）修复根因一后即通。修：设备 profile
  `/var/mobile/Library/Application Support/.mozilla/firefox/*.default/user.js` 加
  `network.proxy.type=1` + `http/ssl/socks → 192.168.1.5:7890`（Mac 上 Clash），杀进程重进。
  实测 google 首页完整渲染（Debug 包 + 代理）。iPad 靠 VPN 不需要这套。
- **根因三（已修，commit 4943d0d）：三个点闪退 = iPhone-only 上游潜伏 bug**：
  `ContentModalNavigationController` 自定义 designated init（`init(rootViewController:onDismissed:)`）
  后，Swift 不再继承 `init(nibName:bundle:)`，编译器生成的 @objc thunk 直接 trap
  （fatalError "use of unimplemented initializer"，crash 帧=`@objc ...CfETo`）；
  而 UIKit `initWithRootViewController:` 内部会 `[self initWithNibName:nil bundle:nil]`
  动态派发回子类 thunk → 必崩 EXC_BREAKPOINT。iPad 上 `presentLibrary` 走 sidebar 分支
  从不构造该类，iPad-only 测试永远暴露不了。修：改 `super.init(nibName: nil, bundle: nil)` +
  `viewControllers=[rootViewController]`（静态上溯绕开 thunk），行为等价。符号化注意：
  Release 主二进制 `__TEXT` 只有 ~4.6MB，crash 地址要按报告里 base+偏移还原，别拿运行时
  地址直接对段。
- 定位方法论加分项：**进程内探针 dylib** 是本工程最快的一锤定音工具——Mac
  `xcrun -sdk iphoneos clang -x c -arch arm64 -dynamiclib`（缺符号就补
  `-framework CoreFoundation -framework CFNetwork -lresolv -weak_framework Network`），
  constructor 里写 `/tmp/*.log` 并**每行 fflush**，`ldid -S` 签名，scp 上机，
  `cycript -p <pid> /tmp/dlopen-probe.cy`（文件模式；extern 块只放 `dlopen` 原型）→ cat 日志。
  本轮 getaddrinfo EAI_NONAME（8ms 秒拒）vs res_ninit 正常（能看到 114DNS）→ 把"DNS 配置坏"
  和"socket 被拒"区分开全靠它。cycript 注入偶发 `_assert(InjectLibrary)` 并杀掉目标属已知噪声，
  重启 App 即恢复。

## Mac 工具链 (不要动 xcode-select，当前指向 Xcode.app 即 27)

- `/Applications/Xcode26.app` = 26.6：**编译+调试用**。SDK iOS 26.5，`MinimumDeploymentTarget=12.0`，
  本工程 `IPHONEOS_DEPLOYMENT_TARGET=12.4` 可编；但 `DeviceSupport` 只有 15.0+，**不能**真机调试 iOS 12。
- `/Applications/Xcode.app` = 27.0：xcode-select 正指着它，**保持不动**（2026-09-15 用户主动切过来的）。
- `/Applications/Xcode15.app` = 15.4：GUI 在新 macOS 上跑不起来，但 CLI (`xcodebuild`/`lldb-1500`)
  和 `DeviceSupport/12.x` + `DeveloperDiskImage.dmg` 可用。注意 15 的 lldb-1500
  `target create` 本工程二进制会崩（无 target 裸连才可用），真断点用 26 的 lldb。
- 编译/调试一律显式指定，不依赖 select，例如：
  `DEVELOPER_DIR=/Applications/Xcode26.app/Contents/Developer /Applications/Xcode26.app/Contents/Developer/usr/bin/xcodebuild -project browser/Reynard.xcodeproj -scheme Reynard ...`
- lldb 用 `/Applications/Xcode26.app/Contents/Developer/usr/bin/lldb`。

## 连接 / 安装

- 有线物理层：`ioreg -p IOUSB` 能看到 `iPad` 即线和口 OK。
- 配对层：`idevice_id -l` / `idevicepair validate`。空列表多半是 iPad 未解锁 / 没点“信任” /
  没允许 USB 配件，亮屏重插直连 Mac 背口再试。
- `devicectl` / `xctrace` 看不到 iOS 12 **属正常** (CoreDevice 只要 iOS 17+)，忽略。
- 装包走 `ideviceinstaller install xxx.ipa`，列表 `ideviceinstaller list`。
- USB SSH：`iproxy 2222:22 -u <UDID>`，然后 `ssh -p 2222 root@127.0.0.1`。

## 调试

- 日志：`idevicesyslog`，崩溃：`/var/mobile/Library/Logs/CrashReporter/`。
- Frida (动态分析首选，server 端已就绪)：Mac 端 `pip install "frida==17.17.0" frida-tools`，
  然后 `frida-ps -U` / `frida -U -f <bundle-id>`，走 usbmux 不用额外隧道。
- 真断点 (已端到端验证，2026-09-15 用 main 分支 Debug 包实测通过)：手机
  `/usr/local/bin/debugserver12 0.0.0.0:1234 -a <pid>`，Mac `iproxy 1234:1234`，再用
  **26 的 lldb**（15 的 lldb-1500 会在 `target create` 本工程二进制时崩溃，无 target 裸连才可用）：
  `platform select remote-ios` → `target create <本地.app/二进制>` → `process connect connect://127.0.0.1:1234` →
  `bt` → `b` → `process detach`。实测堆栈可符号化到 `XUL`Run at nsAppShell.mm:308`。
- debugserver 丢了重提 (Mac `/tmp` 重启会丢，不要当永久存储)：
  `hdiutil attach Xcode15 DeviceSupport/12.4/DeveloperDiskImage.dmg` → 拷出 `usr/bin/debugserver` →
  `scp -O` 上机 → 按上文 4 项 entitlement `ldid -S` 签名。注意机上没有 `pkill`，kill 用 `kill $(ps aux | grep ... | awk '{print $2}')`。

## main 分支构建 (2026-09-15 实测链路)

- 子模块刚 `update/reset` 后必须先 `./tools/development/apply-patches.sh`，否则
  `dist/include` 里链回源码的软链是断的（如 `GeckoViewRuntimeSupport.h`），Swift 编译报
  `cannot find type 'DeviceOSVersion' in scope`。打完补丁子模块变脏属正常（工作树补丁流），不要提交。
- 本机 0 个有效签名证书，`AddGecko.sh` 里写死的 `Apple Development` 会挂。
  不改仓库文件的做法：`CODE_SIGNING_ALLOWED=NO` + PATH 里放 `codesign` 垫片，
  把 `--sign "Apple Development"` 映射成 `--sign -`（ad-hoc，见 `/tmp/fakebin/codesign`，重启会丢）。
- Debug 构建命令（Xcode 26.6，不动 select）：
  `PATH=/tmp/fakebin:$PATH DEVELOPER_DIR=/Applications/Xcode26.app/... xcodebuild build
  -project browser/Reynard.xcodeproj -scheme Reynard -configuration Debug -sdk iphoneos -arch arm64
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="-" -derivedDataPath /tmp/ReynardDD`
- 装机前 Mac 端 `ldid -S` 重签（AppSync 越狱机可装）：主二进制用
  `browser/Reynard/Entitlements/Reynard.private.entitlements`（自带 `get-task-allow`，attach 必需），
  Helper 用 `Reynard-Helper.private.entitlements`，OpenIn 和 dylib 直接 `ldid -S`。
  保持 bundle id 原样（`com.minh-ton.Reynard.MH79SBCPK5` 系列）可覆盖升级已装版本。
- 打包 `Payload/*.app` → zip 改 `.ipa` → `ideviceinstaller install`，启动 `uiopen <bundle-id>`。
- Debug 包主二进制很小是正常的（~76KB stub），真正代码在 `Reynard.debug.dylib`（~41MB）。

## Release 构建（2026-09-16 首通，包 `/tmp/Reynard-release.ipa` 已装机验证）

- 命令同 Debug，把 `-configuration` 换成 `Release`，`-derivedDataPath` 换
  `/tmp/ReynardDD-Release`（与 Debug 隔离）。Release 关断言
  （`ENABLE_NS_ASSERTIONS=NO`，iOS 12 上等于去掉了一批 SIGTRAP）、strip 符号
  （崩溃回溯弱一截）。Release 无 `Reynard.debug.dylib`（Swift 静态链进主二进制），
  只签主二进制 + appex + Frameworks。
- **启动崩坑**：Xcode26 的 Release `-O` 会让 Swift 大栈帧函数 emit
  `___chkstk_darwin`（本轮是 `SearchViewModel.o` / `TabBarPresentation.o`），
  iOS 12 的 libSystem 没有这个符号 → dyld 启动即 `SIGABRT`（`2316*.ips`）。
  修：`OTHER_LDFLAGS` 补 `DEVELOPER_DIR` 同工具链的 `libclang_rt.ios.a`
  （`.../Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/21/lib/darwin/`，
  里面是真实现；换 Xcode 大版本注意 `clang/21` 路径会变）。appex 无此引用，
  全局加 harmless（linker 只拉用到的 member）。
  **2026-09-17 起该修复已落仓库 `browser/Configuration/Reynard.xcconfig`**
  （`$(DT_TOOLCHAIN_DIR)/usr/lib/clang/21/...`，工具链路径自动跟随），不再需要
  命令行临时传。坑：命令行 `xcodebuild OTHER_LDFLAGS=...` 会**整体替换**工程
  里的链接项（XUL/nss 那串），链接必败——盖版本号走 `-xcconfig` 覆盖文件只改
  `CURRENT_BUILD`，别在命令行碰 OTHER_LDFLAGS。
  `___darwin_check_fd_set_overflow`（`JITSupport.o`，fortify 的 FD 宏带来，
  iOS 14+ 才有）是 **weak import**（`nm -m` 验证），12 上 resolve 成 NULL，
  头文件里的运行时检查会跳过——不用管。Debug `-Onone` 帧小不触发，
  所以只有 Release 会踩到。
- 定位法：`llvm-nm -u` 扫主二进制找缺符号 → `llvm-nm -u` 扫
  `Objects-normal/arm64/*.o` 定到文件 → `otool -rv` 看调用点（Swift 大函数
  inlining 产物，逐个改源码是打地鼠，必须全局解）。

## 本地诊断页（设置 About 区版本号上方，2026-09-16 已装机验证）

- 测试页收进仓库 `browser/Reynard/Resources/Diagnostics/`（bench/video/video240/
  anim/hidden/test.html + 两份 mp4，共 ~7MB），设置 About 区版本号上方 4 行入口
  （JIT Bench / Video 720p / Video Drops 240p / Animation Composite），点开走
  `file://` 直接加载包内页。验证：`IMG_0187` 点行即开 tab，
  `RUNS[78,66,67,67]` warmup 形状 = Release 下主进程 JIT 正常。
- Xcode 的 Resources phase 是**空的**（历史遗留，`Assets.car`/lproj 靠工具链自动编），
  散文件不会自动进包：打包时 Mac 端 `rm -rf "$APP/Diagnostics" && cp -R ...`
  拷进去（先删再拷——`cp -R` 到已存在目录会再嵌套一层，已踩一次）。
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

## 白屏排查实录（2026-09-15，分支 local/white-screen-probe）

现象：壳（主页/快捷方式/设置，原生 Swift UI）正常，任何网页白屏、地址栏叉号常亮。
已定案四根因（都有 patch 文件，均在 `local/white-screen-probe`）：

1. `frameLoader.remoteTab` 为 null，`RemoteWebNavigation.sys.mjs` 的
   `maybeCancelContentJSExecution` 直接解引用抛 TypeError，整条加载静默死亡。
   修：`?.` 容错。patch：`patches/toolkit/components/remotebrowserutils/RemoteWebNavigation.sys.mjs.patch`。
2. `geckoview.js createBrowser()` 给 `<browser>` 加 `remote="true"`，但 iOS 上没有
   content 进程 → 永远没有 docshell → 加载无声无息。
   大坑：`isRemoteBrowser` 看的是属性**有无**不是值，`remote="false"` 等于没改，
   必须 `removeAttribute("remote")`（iOS 才删，Android 保持）。patch：
   `patches/mobile/shared/chrome/geckoview/geckoview.js.patch`（用
   `AppConstants.platform == "ios"` 判断；注意 `Services.appinfo.OS` 在本移植上是
   `"Darwin"`，不能拿它判断）。
   修完 `docShell=true`，PageStart/Progress 开始流动。
   同文件：iOS 不设 `maychangeremoteness`（否则每次导航都触发 ChangeRemoteness
   进程切换，必败；lldb 抓到过 `FinishReplacementChannelSetup(NS_ERROR_FAILURE)`）。
3. **真凶（收尾失败，白屏最后一跃）**：本移植是单进程（无 content 进程），但
   `BrowserTabsRemoteAutostart()` 恒返回 true（只认 `MOZ_FORCE_DISABLE_E10S=1`
   环境变量，不读任何 pref），于是 `XRE_IsE10sParentProcess()==true`；
   `ParentProcessDocumentChannel::RedirectToRealChannel` 判定 http“不许在
   parent 加载”→ promise 决议 `NS_ERROR_CONTENT_BLOCKED`，底层 http channel
   随之撕掉（`OnStopRequest(NS_ERROR_FAILURE)`，`OnDataAvailable` 永不到）。
   所以 DNS→建连→TLS→Waiting→服务器回 200 全正常，但无渲染、无成功 PageStop。
   修（C++，`XP_IOS` 守卫，单进程全许 parent 加载）：`nsDocShell::CanLoadInParentProcess`
   直接 `return true`（兼顾 `InternalLoad` 同名门禁）+
   `RedirectToRealChannel` 跳过 e10s-parent 检查。patches：
   `patches/docshell/base/nsDocShell.cpp.patch`、
   `patches/netwerk/ipc/ParentProcessDocumentChannel.cpp.patch`。
   修完 test.html 首次 `PageStop success=1`，截图渲染出 `REYNARD-LAN-OK`（包
   `/tmp/Reynard-fix1.ipa`，已装机验证，pid 3756）。
   定位法：WP `STATE_STOP status=2153644038` → `0x805E0006`，按 ErrorList.py
   （MODULE_BASE_OFFSET=0x45，实际模块 94-69=25=CONTENT，code 6）=
   `NS_ERROR_CONTENT_BLOCKED`；lldb 断点亲见 `RedirectToRealChannel:62` 调
   `CanLoadInParentProcess`。注意 user.js 里 `browser.tabs.remote.autostart=false`
   / `fission.autostart=false` 对这条路**无效**（源码根本不读 pref），别再试。
   `about:blank` 一直正常是因为 `SchemeIs("about")` 天生放行。

当前前沿（收尾观察项）：页面已渲染，但 parent 进程内 Web JS 的 eval/脚本加载
受 `nsContentSecurityUtils` parent 门禁（`extensions.webextensions.remote` 等
逃生口），复杂站点的 JS 可能还需 user.js/补丁跟进；待用 google 等重型页验证。
→ **2026-09-16 已修**：实锤是 `IsEvalAllowed`——本移植 `XRE_IsE10sParentProcess()`
恒 true，web 内容的 eval/Function 在"parent 进程"被拦，Google 搜索结果页
JS 中途死掉只剩 "If you're having trouble accessing Google Search" 兜底页
（深色模式即用户看到的"黑色报错"；脚本加载门禁 `ValidateScriptFilename` 因
`security.allow_parent_unrestricted_js_loads` 默认 true 无害）。修：XP_IOS 下
web 内容（非 system principal）eval 直接放行，与子进程同等对待（patch：
`patches/dom/security/nsContentSecurityUtils.cpp.patch`）。user.js 临时方案
`user_pref("security.allow_eval_in_parent_process", true)` 亦有效，已从设备删除。
搜索结果页若出 reCAPTCHA"unusual traffic"是 Google 对出口 IP/UA 的服务端
风控（设备挂 VPN 时常见），不是浏览器问题。

附带发现（真 bug，另案修）：`NavigationDelegate` 的 `.onLoadError` 是空实现，
加载报错会被吞；`reynard://open?url=` 在 iOS 12 上根本没接（真 delegate 是引擎的
AppShellDelegate，SceneDelegate 只有 13+ 才有，AppDelegate 里也没有 openURL 处理）。

## JIT 主进程实验实录（2026-09-16 凌晨，分支 local/jit-main-process-a7）

目标：iOS 12 A7 上打开 SpiderMonkey JIT。本移植单进程，JIT 必须在**主进程**
生效，引擎的子进程 JIT 管线（childProcessDidStart/信号管道/ChildProcessInitImpl
读端）在本移植永远走不到——`ReportJITStatusForChild(getpid(), false)` 在主进程
查不到子进程管道是无害 no-op，不会锁死 JIT，别再往这条线查。

最终结果：基准页从 ~1280ms×4 全平（纯 C++ 解释器）到 `[77,70,70,69]`
（Ion 稳态，约 18 倍），`/tmp/Reynard-jit-final.ipa` 已装机验证。

定案的三道门（按生效顺序，均有 patch 文件）：

1. `javascript.options.main_process_disable_jit`：StaticPrefList.yaml 在 XP_IOS
   默认 **true**，`nsXPConnect::InitJSEngine` 在 JS_Init 前读到就
   `JS::DisableJitBackend()`，一次性进程级。user.js 救不了（挂在 NS_InitXPCOM
   里，早于 profile/user.js 加载）。修：XP_IOS 直接硬编码跳过
   （`patches/js/xpconnect/src/nsXPConnect.cpp.patch`，新文件）。
2. **MAP_JIT 是误诊**：iOS 12 内核对 MAP_JIT 直接 **EINVAL**（内核不认该
   flag），纯匿名 R|X mmap 反而成功。上一轮"加 MAP_JIT"实际是把本来能成功的
   mmap 弄坏了。修：iOS 分支去掉 MAP_JIT + EINVAL 时以 hint=0 重试（随机
   hint 可越 iOS 12 VA 界，XNU 对越界 hint 返回 EINVAL 而不是重定位；
   `patches/js/src/jit/ProcessExecutableMemory.cpp.patch`）。
3. `MaxCodeBytesPerProcess`（ProcessExecutableMemory.h）：上游 64 位值
   2044MB 在 iOS 12 用户 VM map 放不下（进程内探针实测 512MB OK / 1GB 即
   ENOMEM，与 exec 位无关）。修：XP_IOS 降到 140MB（上游 32 位同款）。

关键事实（全部进程内实测，cycript dlopen 探针 dylib）：

- AppSync+ldid 把主二进制签成 **CS_PLATFORM_BINARY**（csflags=0x2600100f），
  no-sandbox/platform-application 等 entitlement 生效皆源于此；
- 平台二进制下内核放行**整套 W^X**：R|X 预留 → mprotect RWX → 写入 →
  mprotect R|X → 直接 RWX mmap 全部成功，**不需要 CS_DEBUGGED、不需要
  ptrace helper**——"persona 提权"问题就此消解；
- setuid 在 iOS 12 无效（root 属主 4755 二进制 mobile 跑仍 getuid()=501）；
  TrollStore 的 persona spawnRoot 也不行（iOS 12 无 persona）；
- `dynamic-codesigning` entitlement 实测无效（已从 entitlements 删掉）；
- JITController 的 iOS 12 主进程自附 ptrace（helper 以 mobile 跑）必失败，
  保留作未来 root daemon 场景的后备，失败静默无害；**attach 必须赶在
  JS_Init 前**（execmem 在 JS_Init 内分配），故 start() 里用
  `attachQueue.sync`（iOS 12 分支）；
- execmem 预留失败不能硬返回：JS_Init 会 MOZ_CRASH 启动即崩，JitContext.cpp
  加了 XP_IOS 软降级（disableJitBackend=true 退解释器）。

诊断方法（后人照抄）：

- 进程内探针：Mac 编探针 dylib（`clang -dynamiclib` + **必须** `ldid -S`
  helper entitlements 签名——裸 `ldid -S` 二进制放 /tmp 上 exec 直接
  SIGKILL），scp 上机，`cycript -p Reynard` 后 dlopen，构造器写
  `/tmp/reynard-probe.log`。cycript extern 块**只能放原型不能放函数体**；
  mach_vm.h 在 iOS SDK `#error`，mach_vm_region 手工 extern 即可；
- 引擎内三层临时 fprintf（nsXPConnect/JitContext/Reserve 写
  /tmp/reynard-jit.log）做分层定位，终版构建已移除探针；
- 每轮验证：Mac `python3 -m http.server 8033 /tmp/reynard-bench` +
  cycript 驱动地址栏加载 bench.html，看 RUNS 数组有无 warmup 形状。

## 自驱操作平板（免手动点）

- 截图：`activator send libactivator.system.take-screenshot` →
  `/var/mobile/Media/DCIM/100APPLE/IMG_*.PNG` → `scp -O -P 2222` 取回看。
  `idevicescreenshot` 在本机不可用（要挂 DeveloperDiskImage，12.5.8 没有对应镜像）。
- 驱动地址栏加载（cycript，无需点击）：机上有 `/usr/bin/cycript`。
  找输入框：遍历 `[UIApp keyWindow]` 找 `UITextField`（整个 App 就一个，placeholder
  是 "Search or enter website name"）；设值后调
  `[delegate textFieldShouldReturn:field]`（delegate 是 `Reynard.AddressBar`），
  参考 `/tmp/drive.cy`（重启会丢，用前重建）。键盘弹没弹出不影响。
- `uiopen <bundle-id>` 可冷启动；`uiopen 'reynard://...'` 在 iOS 12 上无效（见上）。
- 机上无 `pkill`/`lsof`/`python3`/`nc`，有 `curl`/`wget`/`sqlite3`/`ldid`/`activator`/`uiopen`/`cycript`。

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
  StaticPrefList.yaml 这类全局生成头时。objdir 配置硬编码了已消失的
  `/Applications/Xcode-beta.app`（host 报 `stdio.h file not found` 即此病），解法
  `sudo ln -s Xcode.app Xcode-beta.app`（只补兼容软链，不动 xcode-select）。
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
- 包名已改为 `reynard.bemly.moe`（2026-09-16，用户要求）：改点含 pbxproj 四处
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
- profile 在 `/var/mobile/Library/Application Support/.mozilla/firefox/ylc3xczg.default/`；
  places.sqlite 可能是 0 字节（本移植历史记录没启用），别拿它当判据。
- 状态确认三件套：`ps` 看 pid/CPU（转圈≈在干活，0.0%≈卡死）、`netstat -an` 看连接及
  Send-Q/Recv-Q、`ls -lt .../CrashReporter/` 看新崩溃（`0xdead10cc` 是后台握锁被杀，
  `0x8badf00d` 是看门狗，加载卡死本身不崩溃）。

## 媒体/视频现状（2026-09-16 实测）

- **视频能放**：本地 720p30 H.264+AAC mp4 全屏播放成功（`MOZ_APPLEMEDIA=1`，
  `AppleDecoderModule` 已注册，ffvpx 软解兜底也在），240p 丢帧约 4%。
- **但没有可用的硬件加速**：播放时 app CPU 40–95%（720p）/22–65%（240p）；
  纯 CSS 全屏动画（只有合成、无解码）CPU 也有 28–46% → 合成端是 **CPU 软合成**
  （SWGL 特征，GPU 合成该是个位数）。解码端大概率也是 ffvpx 软解在扛大头。
  真实网站高分辨率视频会卡顿、A7 发热。
- 诊断法：局域网 `http.server` + ffmpeg 生成 testsrc2 测试视频 + JS
  `getVideoPlaybackQuality()` 读 decoded/dropped + `ps` 采样 CPU 对比
  （静态页 0% / 纯动画 ≈ 纯合成成本 / 视频 ≈ 合成+解码）。
- 若要真加速，两块都要动：解码走 VT 硬解零拷贝（IOSurface→合成器）+
  合成端上 GPU（WebRender GL/Metal 而非 SWGL）。属后续工程方向。

## iOS 12 兼容门禁清单（原 browser/IOS12_GATES.md，2026-09-16 并入本文件）

记法：**[SHIM]** = 有真实 fallback（iOS 12 上功能正常）；**[GATE]** = 功能在 iOS 12 上直接缺失，
以后补 fallback 就按这张表找。新增 iOS 13+ API 门禁时同步更新本节；写法约定：
整类型/扩展加 `@available(iOS 13.0, *)`，调用点用 `if #available` 包住。

- Helper 扩展点 [SHIM，已真机验证]：`Helper/Info.plist` 的 `NSExtensionPointIdentifier`
  用 `com.apple.app.non-ui-extension.multiple-instances`（`com.apple.ar.viewer` 是 13.4+，
  iOS 12 会拒装整个包）。2026-09-16 已验证：可装机 + 网页正常渲染（子进程能起）。
- Swift 并发运行时（历史教训）：光删 `async/await` 不够，`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`
  + `@MainActor` 会让编译器链接 `libswift_Concurrency.dylib`（最低 iOS 13），iOS 12 上
  dyld 直接启动崩溃。pbxproj 四处配置已改为 `nonisolated`/`NO`，全仓无 `@MainActor`。
  合并上游代码时凡见 `async/Task/@MainActor` 一律手工 port 成 completion 风格。
- 语义色/圆角/材质 [SHIM]：`UICompat.swift` 的 `UIColor.app*`、`UITableView.Style.appGrouped`
  （`insetGrouped`→`grouped`，26 处）、`CALayer.applyContinuousCornerCurve()`、
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

## GPU 合成方向（分支 `local/gpu-compositing-wr-gl`，实验中）

- 现状：网页合成走 SWGL（CPU）。present 端已是 CoreAnimation
 （`RenderCompositorNative.cpp.patch` 在 XP_IOS 返回 CORE_ANIMATION；
  NativeLayerCA/SurfacePoolCA 均有 XP_IOS 分支）；`layers.gpu-process.enabled=false`，
  合成在主进程 in-process（`mobile.js.patch` 注释：子进程是 app extension 建不了
  GLES context，主进程是完整 app 可以）。
- 硬件路在树上存在：`gfx/gl/GLContextProviderEAGL.mm` 是完整实现
  （GLES3→GLES2 回退、sharegroup）；`GfxInfo.cpp:176` iOS 永不 blocklist OGL。
- 切入点：`gfxPlatform.cpp` 的 SWGL 决策链（`SetUseSoftwareWebRender(!hasHardware)`、
  `gfx.webrender.software*` fallback prefs）+ EAGL provider 在本移植是否正常编译链接；
  先加临时日志确认当前 `UseSoftwareWebRender` 取值与 fallback 起因
 （`gfxCriticalNote "Fallback WR to SW-WR*"`），再决定翻哪道开关。
- 风险：A8X 上 PBO 上传曾触发 AGXGLDriver 崩溃（见 RuntimePreferences.swift），
  A7 PowerVR 驱动更老；GLES 在 iOS 12 已废弃但可用。引擎重编定点约 30 秒、
  大规模约 50 分钟，坑位见“坑位速查”引擎条。
- 验收：沿用 bench 法（http.server + cycript 驱动地址栏 + RUNS warmup 形状 +
  `ps` CPU 对比静态/纯动画/视频三档）。

## 输入法崩溃实录（2026-09-16，包 `/tmp/Reynard-ime-fix.ipa` 已装机）

- 现象：网页输入框（Google 搜索框）敲任意键即 SIGABRT（NSException），
  `CrashReporter/Reynard-2026-09-16-2039*.ips` 两份同签名（ASLR 基址不同、
  文件偏移同为 +91155036）。
- 根因：`TextInputHandler::HandleKeyEvent`（及 Phase2 同名调用）直接调私有
  `-[UIKeyboardImpl handleKeyInputMethodCommandForCurrentEvent]`，该 selector
  在 iOS 12.5.8 上根本不存在（cycript 进程内探针实证
  `instancesRespondToSelector=false`；`deleteFromInputWithFlags:` /
  `addInputString:withFlags:withInputManagerHint:` 存在，无害）。
  此前从未有人在网页里敲过字（bench 全走原生地址栏），故一直潜伏。
- 定位法：atos（`obj-.../dist/bin/XUL` 221MB 未 strip，可直接符号化）→
  `otool -arch arm64 -tv -p <mangled>` 对偏移，崩溃 +216 恰为该 msgSend 的
  返回地址（`tbz` 那条）。
- 修：两处调用加 `respondsToSelector` 守卫（patch：
  `patches/widget/uikit/TextInputHandler.mm.patch`）。
- regen 血泪：工作树含已应用的 port 补丁，regen 必须用
  `git -C engine/firefox diff HEAD -- <path>`；裸 `diff`（相对 index）只吐
  增量，会把 patch 文件覆盖成十几行（已踩，已恢复）。
  校验用引擎目录内 `git apply --check -R <patch绝对路径>`
  （正向 check 必败——patch 是相对 pristine 上游的，不是相对工作树的）。
- 自驱补充：App 内有两个 UITextField（地址栏 + 隐藏的页内查找框），
  drive 脚本必须按 delegate 含 `AddressBar` 挑（见 `/tmp/drive2.cy`，重启会丢）。

## JIT 弹窗误报实录（2026-09-16，包 `/tmp/Reynard-jit-silent.ipa` 已装机）

- 现象：YouTube 播视频弹“启用 JIT 失败”（`错误 -30`），但视频本身流畅。
- 根因：视频触发 Gecko 起了 `type="tab"` 的**真子进程**（“单进程无 tab 子进程”
  的假设破了，`start()` 注释已过时）；`childProcessDidStart → attachToProcess →
  handleJITFailure → 弹窗`。`-30 = TSPtraceHelperAttachFailed`：helper 以 mobile
  跑，ptrace 附着在 iOS 12 上**永远**失败。主进程 JIT 走 platform-binary W^X，
  本来就是好的；两子进程 CPU 全 0.0%，页面 JS 不在里面——弹窗是纯噪声。
  （点“启用无 JIT 模式”也无害：`detachAllJITSessions` 只动 debug session，
  主进程 execmem 不受影响，但点了也没用。）
- 修：iOS 12 上子进程 attach 失败静默上报 false（`JITController.swift` 的
  `handleJITFailure` + `handleJITDisconnectNotification` 两处
  `if #unavailable(iOS 13.0) { return }`），附着尝试保留（以后 root daemon
  场景还用得上）；13+ 行为不变。
- 验证：重播 YouTube，helper 照起（pids 6521/6522），弹窗不再出现
  （`IMG_0180/0181`）。注意当时页面白屏是另一起事故：21:15 `PacketTunnel`
  崩了，外网全 `SYN_SENT` 黑洞——先重开 VPN 再测页面。
- 附带未查项：21:06 有一起主进程 `js::Interpret +22984` 空指针 SIGSEGV
  （`Reynard-2026-09-16-210634.ips`，ime-fix 包，用户播视频期间），与本次
  弹窗无关，另案跟。

## WebGL 修复实录（2026-09-17，单行 pref 修复，真机验证通过）

现象：任何页面 `getContext('webgl'/'webgl2'/'experimental-webgl')` 全部返回
null（3d.bemly.moe 只剩移动按钮）。最终修复只有一行：
`pref("webgl.allow-in-parent", true)`（已落 `mobile/ios/app/mobile.js`）。

- **定位捷径（零重建，先用这个）**：`ClientWebGLContext::CreateHostContext`
  的每个 Err 都会向 canvas 派发 `webglcontextcreationerror`，探针页监听
  `e.statusMessage` 直接拿到精确失败字符串。第一轮截图即拿到
  "WebGL disabled, see about:support for why"——是 `CreateHostContext` 的
  **第一道门** `gfxVars::AllowWebGL()`，上会话怀疑的 CanvasManagerChild 层
  根本没执行到。
- lldb 教训：`CanvasManagerChild::Get` 调用方很多（2D canvas/
  PersistentBufferProvider/CompositorBridgeChild 等），断点命中 ≠ WebGL
  路径走到；先用 creationerror 字符串定性，再上断点。
- 根因：`gfx/thebes/gfxPlatform.cpp`（~3252）无 GPU 进程时
  `featureWebGL.Disable(UnavailableNoGpuProcess)` → `AllowWebGL=false`。
  修：`webgl.allow-in-parent`（**连字符**，StaticPrefList 里 grep 下划线
  找不到；默认 false，ONCE_PREF 启动一次性读，user.js / 默认 prefs 均可）。
  user.js 里旧的 `webgl.force-enabled`/`webgl.ignore-blocklist` 对这道门
  无效（门在 gfxConfig/GPU 进程判定，不在 blocklist），属无效药可清理。
- 架构事实（Fx 155）：WebGL **没有进程内 host 分支**，无条件走
  `CanvasManagerChild::Get()`（TLS 惰性建链）→ `SendPWebGLConstructor` IPC。
  单进程 port 下整条链实测能跑通：in-proc `CompositorManagerChild`
  （合成会话创建时 `EnsureProtocolsReady → InitSameProcess` 设置
  `sCompositorProcInfo=Current`）→ 同进程 endpoint
  （`PCanvasManager::CreateEndpoints(Current, Current)`）→
  `CanvasManagerParent`/`WebGLParent`/`HostWebGLContext`/EAGL headless GL
  全部落主进程 CompositorThread。上游注释 "we don't actually support remote
  canvas in the parent process" 是保守说法，别被吓退。
- 同进程排查备忘：`CanvasShutdownManager::Get()` 主线程惰性自建不是断点；
  `CompositorManagerChild::GetCompositorProcInfo()` 只有 `InitSameProcess`/
  `Init` 会设置。
- 验证：user.js 单加该 pref 冷启 → 探针页三种类型全 OK
  （RENDERER "Apple M1, or similar" 是 Gecko 对 Apple GPU 的掩码文案，
  `draw+read: PASS` = 画+readPixels 读回校验）。
  patch regen：`git -C engine/firefox diff HEAD -- mobile/ios/app/mobile.js`
  整文件 diff 覆盖 `patches/mobile/ios/app/mobile.js.patch`，reverse-check 过。
- 3d.bemly.moe（three.js 实站，bundle 2.5MB）修复后表征改变：WebGL 被禁时
  只剩摇杆按钮不崩；WebGL 打开后场景真初始化，**加载几秒内触发系统级内存/
  CPU 风暴**（load 26+，jetam 连杀 App+dropbear/sshd，SSH 断连、连崩溃报告
  都来不及写）——与 browserscore.dev 702MB 高水位同案（1GB A7 + SWGL 软合成
  的硬件墙），另案缓解，不是 WebGL 管线问题。注意"设备熄屏"和"内存风暴杀
  dropbear"都会造成 cycript/截图链路死亡，先 `uptime`+`ps` 分辨（熄屏时
  uiopen 即可恢复；风暴后 load 依旧很高）。
- WebGL 修复包：`/tmp/Reynard-webgl-17dd42f.ipa`（Release，装机验证通过；
  user.js 三条 webgl pref 已清空，纯靠仓库 mobile.js 默认值）。

### 内存预算 pref（2026-09-17，commit 7dc188d，包 `/tmp/Reynard-mem-7dc188d.ipa` 已装机）

配置层缓解 jetsam 高水位（~702MB），全部落在 `mobile/ios/app/mobile.js`：

- **`image.mem.max_bytes` 在 Fx 155 已不存在**（旧文档/记忆别再找它），解码图
  缓存实际由 SurfaceCache 管理：大小 = `min(physmem / size_factor,
  max_size_kb)`，默认 factor=4、max≈2GB → 1GB 机上 **256MB**。已改
  `size_factor=8` + `max_size_kb=131072`（封顶 128MB）。
- JS GC tunables 在 `modules/libpref/init/all.js`（StaticPrefList 里只有
  mem.log/notify）。desktop 默认 `gc_large_heap_size_min_mb=500` 在 1GB 机
  完全失配。已改：small_heap_max 64、large_heap_min 128、high_freq_small
  growth 200、high_freq_large/low_freq growth 120、allocation_threshold 8、
  malloc_threshold_base 16、urgent 8。代价 = 更频繁的增量 GC。
- 实测（3d.bemly.moe，nohup `ps aux` 采样 /tmp/mem.log）：RSS 曲线
  146→181MB 峰值→GC 压回 95MB，**ps RSS 看不见 GPU/IOSurface/phys_footprint，
  别拿它当 jetsam 判据**。站点加载 ~15s 后仍触发系统级风暴。
- **为什么风暴后找不到 JetsamEvent**：系统会拉起 `/usr/libexec/
  ReportMemoryException`（CrashReporter 目录里有同名隐藏 `.ips`），但它被
  越狱插件 Cr4shed（Cr4shedJetsam.dylib）搞崩（SIGABRT），完整 jetsam 报告
  永远落不了盘。看到 `.ReportMemoryException-*.ips` = 内存异常事件实锤。
- 风暴时 nohup 后台采样器也会陪葬（只录到 6 条）；`ps` 采样结论仅作趋势用。
- 3d 站剩余内存消耗在 GPU 纹理/SWGL 渲染缓冲，pref 压不到，缓解需
  场景降载/纹理预算（非配置层）。




## browserscore.dev 崩溃定性（2026-09-17，Debug 包 + lldb 真机复现）

结论：**不是单个代码 bug，是内存耗尽**。该站是 Lea Verou css3test 变体，对数千个
CSS 特性跑 `CSS.supports()` + 建巨型结果 DOM，1GB A7 上进程超过 jetsam 高水位
**702MB** → `EXC_RESOURCE (RESOURCE_TYPE_MEMORY: high watermark)` → jetsam
SIGKILL。当晚用户自己的会话同样死于该上限（JetsamEvent-2026-09-16-230753.ips：
Reynard **179712 页 = 702MB**，与上限分毫不差）。

- 复现法：关启动恢复（见下）冷启动 → `cycript -p Reynard /tmp/drive-bscore.cy`
  驱动地址栏加载 → CPU 80% 猛跑几十秒 → 死。lldb attach 时抓到两次
  EXC_RESOURCE stop（一次主线程、一次 TaskController #0），命中时主线程栈顶是
  `imgLoader::LoadImage → malloc(240) → mozjemalloc GetNewEmptyBinRun`——
  即进程已在 702MB 顶上，任何分配都触发；停止态等 memsum 时被 SIGKILL 不可拦截。
- 同晚日志里的其他死法（同一页面压力下的次生/独立问题，另案）：
  22:52 看门狗 SIGKILL（主线程被页面 JS/DOM 饿死 >20s）；22:59
  **AGXGLDriver SIGSEGV**（WR-GL `draw_instanced_batch` 实例化绘制把 A7 GPU
  驱动打崩——本分支 GPU 合成实验的真实稳定性数据点）；23:05/23:06
  `BrowsingContext::Commit` 主线程 SIGSEGV（Debug 包，未复现，疑与内存压力下
  tab/BC 拆除有关）；23:16 两份 `___chkstk_darwin` DYLD 崩是**旧 Release 包**
  （build=UNKNOWN，未带 libclang_rt 链接修复）残留，非新问题。
- 可能的缓解方向（未实施）：user.js 压缓存（image cache
  `image.mem.max_bytes`、JS GC `javascript.options.mem.*`、WR 纹理缓存），
  先 `about:memory` 细分再动手；启动恢复风暴同理需做渐进恢复。

### 启动恢复内存风暴（本次新发现，装置现为关闭状态）

- `Prefs.HomepageSettings.restoresTabsOnLaunch=true` 时，冷启动恢复上次会话
  的多 tab 会在 1GB 设备上引发内存风暴：实测两次冷启动分别于启动后 ~45s/~9s
  被 jetsam 杀（JetsamEvent-2026-09-17-004242/004637），cycript 都来不及
  attach。**本机该开关已被关掉**（用户可在设置 > 通用 > 主页 > 启动时 重开）。
- 绕过法（不用重启 App 的进程内改法没用，boolCache）：App 是 platform
  application 不走沙盒容器，UserDefaults 直接落在
  `/var/mobile/Library/Preferences/reynard.bemly.moe.plist`。改法：scp 拉回
  Mac → `plutil -convert xml1` → 手改 `<true/>` 为 `<false/>`（注意
  `plutil -replace` 会把 key 里的点当 keypath，**改不动这个扁平键**）→
  binary1 转回 → scp 上机 `chown mobile:mobile` → `kill cfprefsd` → 冷启动生效。

### 调试链路补充（debugserver12 + lldb 为主，cycript 驱动 UI）

- EXC_RESOURCE（含 memory highwater）是可停的 Mach 异常，lldb 能抓到并 bt；
  jetsam 的 SIGKILL 抓不到（进程直接消失，且 attach 状态下常不落 JetsamEvent
  崩溃报告）。所以"活着被 OOM 杀"用 lldb 盯 EXC_RESOURCE，"直接消失"查
  JetsamEvent。
- **lldb `expression` 驱动 UI 在本链路不可行**：真机连的是本地 .app、无 iOS
  SDK，ObjC 表达式编译报 `no known method '-isKindOfClass:'` 等一堆 unknown
  method/return type——别再试，驱动 UI 用 cycript。
- cycript 文件模式（`cycript -p Reynard /tmp/xxx.cy`）执行成功但**不回显结果**，
  别拿"没输出"当失败判据，用 `ps` CPU/RSS 验证是否真的驱动了；pipe 模式经
  SSH 转义容易把代码打碎（syntax error at 1.xxx），优先 scp 脚本上机走文件模式。
- debugserver 只能 attach 活着的进程：App 秒死时先解决存活问题（如上述关恢复），
  别换工具硬凑。批量 SSH 别循环猛打（sshd 限流），中间留 sleep。
- frida 本轮尝试不可靠（`unable to communicate with remote frida-server` 间歇
  出现，spawn 大进程时必挂），用户已明确要求不用——调试主链路就是
  debugserver12 + lldb（26 的），UI 驱动是 cycript。

## 自驱/连接补充

- cycript 合成调用可能打到未走正常装配的实例（如直接调 `showTabOverviewKeyCommand:`
  触发 `presentationContext` 的 `preconditionFailure`，而真按钮路径正常）——
  验证优先走真实 UI 路径（按钮 tap、长按），少直调 VC 方法。
- usbmux 僵死时（`idevice_id` 空 + SSH reset，但 `ioreg` 能看到 iPad）先重起 Mac 侧
  `iproxy`；还不行就走 WiFi SSH 直连（`root@192.168.1.8`，同口令），不用等 USB。
- cycript 间歇 `InjectLibrary` assert：重启 App 即恢复（顺带验证冷启动）。

## Git 约定

- `main` 恒等于 `origin/main`，保持干净可编；不要在 main 上堆验证代码。
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
