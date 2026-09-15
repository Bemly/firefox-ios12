# AGENTS.md — iOS 12 真机环境 (reynard-browser-ios12)

本文档记录本地 iOS 12 真机联调环境的准备工作结论，后续会话直接照做，不要重复探路。
`engine/firefox/` 下的 AGENTS.md 是上游文件，与本文无关。

## 工作流铁律

- 每次改完代码（修 bug、加探针、改脚本），必须把 Honest 的经验/坑同步到本文件，然后提交 git。
  本条规则本身也要留在这里，不得遗忘。

## 测试机

- iPad mini 3 (`iPad4,4`), iOS 12.5.8 (16H88), 已越狱 (Cydia + Sileo)
- 机上已装: AppSync Unified 102.0 / OpenSSH 8.4 / frida-server 17.17.0 (开机自启)
- `/usr/local/bin/debugserver12`: 从 Xcode15 的 12.4 DDI 提取 (arm64+arm64e)，已 `ldid -S` 签调试权限
  (`com.apple.springboard.debugapplications` + `run-unsigned-code` + `get-task-allow` + `task_for_pid-allow`)
- SSH root 口令：`alpine`（越狱默认）。用法：`SSHPASS='alpine' sshpass -e ssh -p 2222 ...`。
- 本机 sudo 口令：`2328`，需提权时用（例如 `echo '2328' | sudo -S ...`）。

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

附带发现（真 bug，另案修）：`NavigationDelegate` 的 `.onLoadError` 是空实现，
加载报错会被吞；`reynard://open?url=` 在 iOS 12 上根本没接（真 delegate 是引擎的
AppShellDelegate，SceneDelegate 只有 13+ 才有，AppDelegate 里也没有 openURL 处理）。

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
- 引擎 C++ 改动必须 `./mach build` 重编（增量约 50 分钟：603 对象 + gkrust +
  链 XUL）。objdir 配置硬编码了已消失的 `/Applications/Xcode-beta.app`
  （host 报 `stdio.h file not found` 即此病），解法 `sudo ln -s Xcode.app
  Xcode-beta.app`（只补兼容软链，不动 xcode-select）。
- Xcode 重编会覆盖 `.app` 内一次性 JS 探针（本次 fix 包已无 gvnav/selfdrive 探针，
  属正常）；但 `dist` rsync 会带上源码级正式修（`patches/` 已应用部分），放心。
- `browser/Reynard/Entitlements/` 里没有 `Reynard-Helper.private.entitlements`
  （AGENTS 旧述有误）：Helper/OpenIn/dylib 用 `ldid -S` ad-hoc 即可，只有主二进制
  必须用 `Reynard.private.entitlements`（`get-task-allow`，attach 必需）。
- `browser.addProgressListener` 持的是**弱引用**：listener 只存局部 const 会被 GC，
  后期加载的 WP 日志会无声消失（曾误判为“test.html 无 WP 事件”）。探针须挂强引用
  （如 `this.__wp`）；正式代码同理。
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

## Git 约定

- `main` 恒等于 `origin/main`，保持干净可编；不要在 main 上堆验证代码。
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
- 本文件含口令（alpine/2328），只放本地，**不要 push 到公开远端**。
  （UDID/ECID/序列号已按要求从本文删掉。）
