# Gecko 移植实录（白屏/JIT/媒体/WebGL/内存）

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

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

附带发现（真 bug，`NavigationDelegate` 的 `.onLoadError` 原来是空实现会吞加载报错，
现已改为 `NSLog` 探针；`reynard://open?url=` 在 iOS 12 上根本没接（真 delegate 是引擎的
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


## 媒体/视频现状（2026-09-16 实测）


- **视频能放**：本地 720p30 H.264+AAC mp4 全屏播放成功（
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


## GPU 合成验证结论（2026-09-17，分支 `local/gpu-compositing-wr-gl`，iPhone 5s 同包 A/B）


- 开关：user.js `gfx.webrender.all=true` + `gfx.webrender.software=false` 即进 HW-WR。
  代码级确认吃得上：ForceEnabled 优先级高于 iOS GfxInfo UNKNOWN 触发的 blocklist
  Disable（`gfxFeature.cpp` 状态机），EAGL 建 headless context（WebGL 已证），
  硬件路 compositor 是 NativeOGL（CA 呈现；SW 路是 NativeSWGL，呈现端同样 CA 零拷贝）。
- 同包 A/B（只换 user.js）：静态 ~0% 双零；JS-setInterval 全屏渐变 SW 36–53 / HW 42–64
  （无收益，瓶颈是每帧 JS+样式+场景固定成本——100px 小盒 HW 仍 33–40% 反证）；
  纯 CSS keyframes 全屏渐变 **SW 37–45 / HW 17–27（省约 40%，截图验过都在转）**；
  视频 240p/720p 双无差（解码本就 VT 硬解，呈现双零拷贝）。
  另：`layout.frame_rate=30` 限帧实验是废的（anim 页是 setInterval 自驱动，改 vsync 不改负载）。
- 探针页 `Diagnostics/cssanim.html`（纯 CSS 版，合成器主场）已进仓库。
- WebGL（同上 A/B，探针 `Diagnostics/webgl-anim.html`：rAF 旋转三角 + HUD fps，已进仓库）：
  600px canvas：SW 56–64%/29.2fps vs HW 51–73%/29.8fps；150px：HW 32–40%/30.0fps。
  结论：合成后端对 WebGL **无影响**——渲染本来就在 GPU（EAGL），帧率钉死 30 与像素无关
  （600→150 只降 CPU 不升 fps），瓶颈是每帧固定管线成本（rAF→canvas 移交→WR 事务→CA 提交），
  不是光栅化。vsync 源确认配 60（`MaxFPS` + CAFrameRateRange 有 respondsToSelector 守卫）。
- 未合 main：重 DOM 页的 AGXGLDriver 崩风险仍 open（browserscore 夜前科），1GB 机
  GPU 纹理添 jetsam 压力；默认开需更广稳定性测试。当前结论 = 能点亮、有局部收益、不默认开。
- 开关已进设置（分支已验证）：高级 > Developer > 合成区「硬件 WebRender」（默认关，
  重启生效；端到端：开→cssanim 21–24%，关→36–47%）。诊断行 +2（CSS 动画/WebGL 动画，
  走包内 file://）。翻译 en/zh-Hans/zh-Hant 进 SettingsLocalizable，其余语言回落英文。
  注意：本分支比 proxy 合入早，合 main 时 RuntimePreferences 取两边（proxy 行 + WR 行）。


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
- 可能的缓解方向：image/JS GC 缓存已由上文内存预算 pref（7dc188d）压过一轮，
  剩下 WR 纹理缓存未动；动手前先 `about:memory` 细分；启动恢复风暴同理需做渐进恢复。

### 启动恢复内存风暴（重装会重置为默认开，注意）

- `Prefs.HomepageSettings.restoresTabsOnLaunch=true` 时，冷启动恢复上次会话
  的多 tab 会在 1GB 设备上引发内存风暴：实测两次冷启动分别于启动后 ~45s/~9s
  被 jetsam 杀（JetsamEvent-2026-09-17-004242/004637），cycript 都来不及
  attach。**注意重装 App 会把该开关重置回默认开**（2026-09-17 实测：重装后
  `moe.bemly.reynard.plist` 只剩 2 键、无此键即默认 true）。
  用户可在设置 > 通用 > 主页 > 启动时 重开/关闭。
- 绕过法（不用重启 App 的进程内改法没用，boolCache）：App 是 platform
  application 不走沙盒容器，UserDefaults 直接落在
  `/var/mobile/Library/Preferences/moe.bemly.reynard.plist`。改法：scp 拉回
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

