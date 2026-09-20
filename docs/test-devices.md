# 真机环境与自驱操作

> 自 `AGENTS.md` 拆分（2026-09-21）：实录与结论归档于此，`AGENTS.md` 只保留索引。

## 测试机


- iPad mini 2 (`iPad4,4`), iOS 12.5.8 (16H88)，checkra1n 越狱
  （`/var/checkra1n.dmg` + dropbear；Cydia + Sileo + Substrate 共存，loader app 已删）
- 机上已装: AppSync Unified 102.0 / OpenSSH 8.4 / frida-server 17.17.0 (开机自启)
- `/usr/local/bin/debugserver12`：从 Xcode15 的 12.4 DDI 提取 (arm64+arm64e)，已 `ldid -S` 签调试权限
  (`com.apple.springboard.debugapplications` + `run-unsigned-code` + `get-task-allow` + `task_for_pid-allow`)。
  没有的设备自动从`/Applications/Xcode15.app`提取出`debugserver12`装上。
- SSH root 口令：`alpine`（越狱默认）。用法：`SSHPASS='alpine' sshpass -e ssh -p 2222 ...`。
- 本机 sudo 口令：`2328`，需提权时用（例如 `echo '2328' | sudo -S ...`）。
- iPhone 5s (`iPhone6,2`), iOS 12.5.8 (16H88)，checkra1n 越狱（2026-09-17 加入，第二台真机）：
  WiFi SSH 直连 `root@192.168.1.10`；USB iproxy 用 **2233**（`iproxy 2233:22 -u <UDID>`），
  2222 留给 iPad 可并存。两台同 iOS 版本，同一 IPA 可互换验证。



## 连接 / 安装


- 有线物理层：`ioreg -p IOUSB` 能看到 `iPad` 即线和口 OK。
- 配对层：`idevice_id -l` / `idevicepair validate`。空列表多半是 iPad 未解锁 / 没点“信任” /
  没允许 USB 配件，亮屏重插直连 Mac 背口再试。
- `devicectl` / `xctrace` 看不到 iOS 12 **属正常** (CoreDevice 只要 iOS 17+)，忽略。
- 装包走 `ideviceinstaller install xxx.ipa`，列表 `ideviceinstaller list`。
- USB SSH：`iproxy 2222:22 -u <UDID>`，然后 `ssh -p 2222 root@127.0.0.1`。


## 自驱操作平板（免手动点）


- 截图：`activator send libactivator.system.take-screenshot` →
  `/var/mobile/Media/DCIM/100APPLE/IMG_*.PNG` → `scp -O -P 2222` 取回看。
  `idevicescreenshot` 在本机不可用（要挂 DeveloperDiskImage，12.5.8 没有对应镜像）。
- 驱动地址栏加载（cycript，无需点击）：机上有 `/usr/bin/cycript`。
  找输入框：遍历 `[UIApp keyWindow]` 找 `UITextField`（有两个：地址栏 + 隐藏的页内查找框，
  必须按 delegate 含 `AddressBar` 挑，见下）；设值后调
  `[delegate textFieldShouldReturn:field]`（delegate 是 `Reynard.AddressBar`），
  参考 `/tmp/drive.cy`（重启会丢，用前重建）。键盘弹没弹出不影响。
- `uiopen <bundle-id>` 可冷启动；`uiopen 'reynard://...'` 在 iOS 12 上无效（见上）。
- 机上无 `pkill`/`lsof`（两台皆无；iPad 存量描述），有 `curl`/`wget`/`sqlite3`/`ldid`/`activator`/`uiopen`/`cycript`；
  另 iPhone 5s 实测还有 `python3` + `/sbin/netstat`（iPad 上没有）。


## 自驱/连接补充


- cycript 合成调用可能打到未走正常装配的实例（如直接调 `showTabOverviewKeyCommand:`
  触发 `presentationContext` 的 `preconditionFailure`，而真按钮路径正常）——
  验证优先走真实 UI 路径（按钮 tap、长按），少直调 VC 方法。
- usbmux 僵死时（`idevice_id` 空 + SSH reset，但 `ioreg` 能看到 iPad）先重起 Mac 侧
  `iproxy`；还不行就走 WiFi SSH 直连（`root@192.168.1.8`，同口令），不用等 USB。
- cycript 间歇 `InjectLibrary` assert：重启 App 即恢复（顺带验证冷启动）。
  **2026-09-20 补充**：这轮变得高频（连续杀目标）。经验：① 冷启后等 ~20s 再注，
  先跑一条 `echo "true"` 的 trivial 脚本热身，成功后再上正式脚本；② 脚本风格照抄
  设备 `/tmp/` 里 09-17 会话留下的成套验证脚本（`UIApp` builtin、单次
  `writeToFile` 回显），别用 `[UIApplication sharedApplication]` 直呼；
  ③ 设备 /tmp 不重启就一直活着：`tap-lib.cy`（点第 4 个 ToolbarButton）、
  `showdev.cy`（**直接 present DeveloperPreferencesViewController 到 root**，进
  Developer 页的最短路径；注意此时无 navigationController，走 openLinkInBrowser
  的 else 分支，页面不会自动关，dismiss 后看 tab）、`drive-bench.cy`（地址栏）
  都可直接复用；  ④ didSelectRowAt 驱动设置行：拿可见 UITableView 的 delegate 直调，
  行号按 `rows(for:)` 布局算（诊断区 = section 2）。
- ⑤ 地址栏 drive 新写法（2026-09-21）：地址栏类名是 `Reynard.AddressBarTextField`，
  按 `UITextField` 子串匹配会**漏掉真地址栏**（只剩 delegate 为 nil 的内部 view），
  必须按 `TextField` 匹配再剔 `Label`/`ContentView`，delegate 用 `[dd class]`
  直取（`description` 中转多余）；`extern void* fopen` 会被 cycript 报 syntax error，
  回显一律走纯 ObjC `[NSString writeToFile:encoding:4]` 单次写（见 `/tmp/drive-bench.cy`
  定稿版）。另：`uiopen` 在锁屏设备上直接 RequestDenied（syslog 关键词 Locked），
  先让用户亮屏解锁再动手。

