# AGENTS.md — iOS 12 真机环境 (reynard-browser-ios12)

本文档记录本地 iOS 12 真机联调环境的准备工作结论，后续会话直接照做，不要重复探路。
`engine/firefox/` 下的 AGENTS.md 是上游文件，与本文无关。

## 测试机

- iPad mini 3 (`iPad4,4`), iOS 12.5.8 (16H88), 已越狱 (Cydia + Sileo)
- 机上已装: AppSync Unified 102.0 / OpenSSH 8.4 / frida-server 17.17.0 (开机自启)
- `/usr/local/bin/debugserver12`: 从 Xcode15 的 12.4 DDI 提取 (arm64+arm64e)，已 `ldid -S` 签调试权限
  (`com.apple.springboard.debugapplications` + `run-unsigned-code` + `get-task-allow` + `task_for_pid-allow`)
- SSH root 口令：`alpine`（越狱默认）。用法：`SSHPASS='alpine' sshpass -e ssh -p 2222 ...`。
- 本机 sudo 口令：`2328`，需提权时用（例如 `echo '2328' | sudo -S ...`）。

## Mac 工具链 (不要动 xcode-select，当前指向 Xcode-beta)

- `/Applications/Xcode.app` = 26.6：**编译用**。SDK iOS 26.5，`MinimumDeploymentTarget=12.0`，
  本工程 `IPHONEOS_DEPLOYMENT_TARGET=12.4` 可编；但 `DeviceSupport` 只有 15.0+，**不能**真机调试 iOS 12。
- `/Applications/Xcode-beta.app` = 27.0：xcode-select 正指着它，**保持不动**。
- `/Applications/Xcode15.app` = 15.4：GUI 在新 macOS 上跑不起来，但 CLI (`xcodebuild`/`lldb-1500`)
  和 `DeviceSupport/12.x` + `DeveloperDiskImage.dmg` 可用。
- 编译一律显式指定，不依赖 select，例如：
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project browser/Reynard.xcodeproj -scheme Reynard ...`

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
- 真断点 (已端到端验证)：手机 ` /usr/local/bin/debugserver12 0.0.0.0:1234 -a <pid>`，
  Mac `iproxy 1234:1234`，再用 **15 的 lldb**：
  `platform select remote-ios` → `target create 本地.app` → `process connect connect://127.0.0.1:1234` → `b 文件:行号`。
- debugserver 丢了重提 (Mac `/tmp` 重启会丢，不要当永久存储)：
  `hdiutil attach Xcode15 DeviceSupport/12.4/DeveloperDiskImage.dmg` → 拷出 `usr/bin/debugserver` →
  `scp -O` 上机 → 按上文 4 项 entitlement `ldid -S` 签名。注意机上没有 `pkill`，kill 用 `kill $(ps aux | grep ... | awk '{print $2}')`。

## Git 约定

- `main` 恒等于 `origin/main`，保持干净可编；不要在 main 上堆验证代码。
- 验证性/过期代码放 `archive/*` 或 `local/*` 分支。已有：
  `archive/expired-validation-20260915`（launch-logging 验证，+43/-3），
  子模块内对应 `engine/firefox` 的 `archive/diag-launch-log`（`4a3f369` 写 `/tmp/ReynardLaunch.log` 的诊断提交）。
