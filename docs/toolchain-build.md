# 工具链与构建（含 iOS 12.0 目标）

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

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


## main 分支构建 (2026-09-15 实测链路)


- 子模块刚 `update/reset` 后必须先 `./tools/development/apply-patches.sh`，否则
  `dist/include` 里链回源码的软链是断的（如 `GeckoViewRuntimeSupport.h`），Swift 编译报
  `cannot find type 'DeviceOSVersion' in scope`。打完补丁子模块变脏属正常（工作树补丁流），不要提交。
- `AddGecko.sh` 已自带 ad-hoc fallback（`SIGN_IDENTITY` 取 `EXPANDED_CODE_SIGN_IDENTITY`，
  `CODE_SIGNING_ALLOWED=NO` 或空时自动用 `-`），不再需要 `/tmp/fakebin/codesign` 垫片。
  pbxproj 里四处 `CODE_SIGN_IDENTITY = "Apple Development"` 在 `CODE_SIGNING_ALLOWED=NO` 时不生效，不用管。
- Debug 构建命令（Xcode 26.6，不动 select）：
  `DEVELOPER_DIR=/Applications/Xcode26.app/... xcodebuild build
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


## iOS 12.0 适配实录（2026-09-20，起因：mini5 iOS 12.2 闪退）


- 现象：iPad mini 5（A12、12.2、unc0ver/Cydia + AppSync）装 release ipa
  （爱思改 Info.plist `MinimumOSVersion=12.2` 绕过安装检查）点开即闪。
- 定案：**dyld minos 门禁**。release 包内所有 Mach-O（主程序/XUL/9 个 dylib/appex）
  `LC_BUILD_VERSION minos=12.4`，dyld 加载时拒载 minos>当前系统 的镜像 →
  一行代码没跑就死。Info.plist 的 MinimumOSVersion 只管 installd 安装检查，
  改它没用；快速验证可用 `vtool -set-build-version` 原地改 minos，正式包必须重编。
- 12.4→12.0 全部改动点（**5 个文件，缺一不可**）：
  ① `browser/Configuration/Reynard.xcconfig`；② pbxproj **10 处 target 级**
  `IPHONEOS_DEPLOYMENT_TARGET = 12.4`（target 级会盖掉 xcconfig，只改 xcconfig 无效）；
  ③ `tools/development/build-gecko.sh` 的 `--enable-ios-target=12.0`
  （configure 只是普通版本串，无下限校验；引擎侧是 configure 级变更 → 全量重编 ~50 分钟）；
  ④ `tools/development/build-idevice.sh`（rust 静态库对象自带 minos，链接取 max
  会传染给宿主二进制，改完必须重编 `libidevice_ffi.a`）；
  ⑤ `tools/release/create-ipa.sh`（jb_ptrace_jit 的 `-miphoneos-version-min`）。
- 验证法：解包 ipa 后 `otool -l` 扫每个 Mach-O 的 `LC_BUILD_VERSION` minos；
  静态库用 `otool -l xxx.a | grep minos | sort -u`（216 对象全 12.0）。
- 弱链接风险评估：browser 代码 grep 无任何 12.1–12.4 可用性门禁（现有门禁几乎全在
  13.0），12.0→12.4 系统 API 增量极小；12.0–12.3 真机未测，README 改为
  "按 12.0 构建、实测 12.5.8/A7"。旧 12.4 包备份在仓库外
  `../reynard-ipa-backups/Reynard-Jailbroken-12.4-9404527.ipa`。
- 新坑：`tools/release/build-app.sh` 开头 `rm -rf dist/`——会删掉旧 release 资产
  的本地唯一副本，重跑打包前先把 `dist/Reynard-Jailbroken.ipa` 拷出仓库。
- **打包顺序铁律（本次起执行）**：先 commit 源码改动，再跑 `build-app.sh`
  （它拿 `git rev-parse HEAD` 盖 CFBundleVersion），否则包戳=旧 SHA、内容=新改动，
  重演 b080a71 坑。12.0 首包即按此流程：commit b44287d → 重打 → 戳=内容。
- 12.0 包真机验证（2026-09-20，iPhone 5s/12.5.8，包
  `dist/Reynard-Jailbroken.ipa` 戳 b44287d）：ideviceinstaller 安装 → 冷启
 （`restoresTabsOnLaunch` 仍是 False，无风暴）→ 主页/favicon 正常
 （IMG_0135）→ cycript drive 地址栏 example.com 完整渲染（IMG_0136）→
  3 分钟存活 RSS 134MB、无新崩溃。A12/12.2 侧仍待 mini5 用户实测。

