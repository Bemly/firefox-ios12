# AGENTS.md — iOS 12 真机环境 (reynard-browser-ios12)

本地 iOS 12 真机联调入口索引。实录与结论一律归档到 `docs/`，本文件只保留铁律、
速查与现状，不再堆放长篇实录。
`engine/firefox/` 下的 AGENTS.md 是上游文件，与本文无关。

## 工作流铁律

- 每次改完代码（修 bug、加探针、改脚本），必须把 Honest 的经验/坑写到
  `docs/` 对应文件，然后提交 git。本条规则本身也要留在这里，不得遗忘。
- 新的验证结论（如某包的 bench RUNS、minos 抽查结果）记到 `docs/` 相关文件
  末尾追加，不要另起大章节。

## 文档索引

- `docs/test-devices.md` — 测试机、连接/安装、自驱操作平板
- `docs/network-auth.md` — 蜂窝网络授权（ZIK/ZY/Soulghost policy 自写根治）
- `docs/toolchain-build.md` — Mac 工具链、Debug/Release 构建、iOS 12.0 目标
- `docs/debugging.md` — debugserver/lldb/cycript 调试、诊断页、坑位速查
- `docs/gecko-engine.md` — 白屏/JIT/媒体/WebGL/内存/GPU 合成等引擎实录
- `docs/ios12-compat.md` — iOS 12 兼容门禁、优化、警告处理
- `docs/upstream-merge.md` — 上游合并实录、Git 约定、release 政策、自动同步 action

## 测试机速查

- iPad mini 2（`iPad4,4`）+ iPhone 5s（`iPhone6,2`），同 iOS 12.5.8，
  checkra1n 越狱；AppSync Unified / OpenSSH / frida-server / cycript / activator 已装。
- 机上 `/usr/local/bin/debugserver12`（Xcode15 12.4 DDI 提取，已签调试权限）。
- SSH 口令 `alpine`，本机 sudo 口令 `2328`。
- iPad 走 USB `iproxy 2222:22`，iPhone 5s 走 USB `2233` 或 WiFi `root@192.168.1.10`。
- 详见 `docs/test-devices.md`，调试链路见 `docs/debugging.md`。

## 工具链速查（不要动 xcode-select，指向 Xcode.app 即 27）

- 编译/调试一律 Xcode26 显式指定；真断点用 26 的 lldb + `debugserver12`。
- 引擎重编一律走 `tools/development/build-gecko.sh`（DEVELOPER_DIR=Xcode26，
  PATH 最前加 rustup 工具链 bin），编完 `otool -l XUL` 验 minos。
- 详见 `docs/toolchain-build.md`。

## 构建速查

- Debug：`xcodebuild build -project browser/Reynard.xcodeproj -scheme Reynard
  -configuration Debug -sdk iphoneos -arch arm64 CODE_SIGNING_ALLOWED=NO
  CODE_SIGN_IDENTITY="-" -derivedDataPath /tmp/ReynardDD`，再 `ldid -S` 重签。
- Release：先 commit（`build-app.sh` 拿 HEAD 盖版本戳），再
  `DEVELOPER_DIR=Xcode26 build-app.sh --no-signing` + `create-ipa.sh --jailbroken`。
- 打包前先把 `dist/*.ipa` 拷出仓库（`build-app.sh` 开头 `rm -rf dist/`）。
- 包名 `moe.bemly.reynard`，部署目标 12.0，`CURRENT_VERSION = 0.14.0`。

## Git / Release

- `main` 跟踪 `bemly/main`；`origin/main` 只读存档；验证代码放 `archive/*`、`local/*`。
- `.github/workflows/` 只保留 `sync-upstream.yml`；平时不得手动碰 GitHub release，
  唯一例外是该自动化（按 `<version>-ios12` 建/替换同名 release）。
- 详见 `docs/upstream-merge.md`。
