# 蜂窝网络授权（ZIK/ZY/Soulghost）

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

## ZIK+ZY 双探针干净验证（2026-09-17，分支 `local/netauth-fresh-bid`，包名 zik2）


- ZIK 全套已移植（`ReynardCellularAuthFix.h/.m`，无混淆，门禁改为 iOS 12，
  日志落 `/tmp/zikfix.log`；调用点在 main.swift iOS 12 observer，主线程），
  ZY 检测层已移植（`ReynardNetworkAccessibility.h/.m`，纯公开 API，
  日志落 `/tmp/zyauth.log`；alert 文案按“设置无此行”实情改写）。
- 干净首启日志（pid/bundle/CH/hasCellular 全过）：nudge `rc=2`，
  `dataActiveAndReachable` 返回 0，CT 初值 Unknown；ZY 侧 CT=restricted、
  Reachability flags=0、判定 state=3（被拒）。
- 结论：**ZIK 强制弹框对“安装即拒绝”无效**——无系统弹窗、policy 事后仍 1,1、
  usage 库无记录（文档前提“仅未决定有效”被实证）；**ZY 检测+自制提示全通**——
  判定正确且 alert 正常弹出（`IMG_0103`）。此前 zik1 轮的日志混乱系现场污染，
  代码本身无辜。方向：ZIK+ZY+PS 三者全收进 main（用户拍板）。


## Soulghost 自写 policy 根治（2026-09-17，分支 `local/netauth-fresh-bid`，包名 zik2，真机全通）


- 方法（Soulghost 2020-05，iOS 13.5b3 以前有效，12.5.8 在射程内）：
  给 App 签 `com.apple.CommCenter.fine-grained = [spi,phone,identity,data-usage,
  data-allowed,data-allowed-write]`（已进 `Reynard.private.entitlements`，分支），
  调设置 App 自己的写入器 `PSAppDataUsagePolicyCache
  -setUsagePoliciesForBundle:cellular:wifi:`。ldid 可自签该 ent，系统认（platform binary）。
- 定位：类在 dyld shared cache 里，不在任何 PrivateFrameworks 磁盘文件里；
  宿主库不用管——**本进程预加载即有该类**（`preloaded=YES`，Gecko 链的东西顺手带进来的），
  直接 `NSClassFromString` 可用。selector 经 cache strings 确认。
- 实测（cycript 进程内调用，参数 `zik2/YES/YES`）：调用成功进程不崩，
  policy 当场 **1,1→2,2**，**无需杀 nesessionmanager、无需重启**，baidu 首页完整渲染
  （`IMG_0104`）。usage 双库随后出现 zik2（`bundle_info` 36 行 + `ZPROCESS` 1 行），
  “有流量→Settings 行出现”链只差用户亲手看一眼设置页。
- 结论：这才是根治——App 侧可**静默自修**，比 ZIK 弹框、比 CLI 都彻底。
  已 bake 进 `ReynardCellularAuthFix`（与 ZIK nudge 共存，三者全留），包名恢复正式 ID，
  合 main。测试包覆盖规则更正：之前两轮“装新包挤掉旧包”系用户手动删除，非系统行为。
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

