# macOS SwiftUI SPM 模板：开箱即用清单与实施记录

> 状态：已实施，在本地分支 `feat/template-infrastructure` 上，未 push · 2026-10-18
> 基线：Xcode 26.2（Swift 6.2.3），开发机 macOS 15.7
> 验收清单见 [ACCEPTANCE.md](ACCEPTANCE.md)。这两份是模板专用文档，`scripts/init.sh` 会删除它们。

## 目标

- **开发**：用模板新建仓库 → 运行 `scripts/init.sh` → `make run` 出窗口 → 直接写业务代码。
- **发布**：PR 以 squash 方式合并进 `main` → release-please 维护发版 PR → 合并后自动打 tag、创建 Release，CI 上传 DMG、dSYM、appcast → 已安装的应用通过 Sparkle 自动更新。

原则：纯 `Package.swift`，不提交 `.xcodeproj`；一个命令入口（Makefile）；每项都有可执行的验收方式；依赖尽量少；和 chengzi-io 其他模板以及 `github-repo-scaffold` skill 的约定保持一致。

---

## 1. 定稿决策

| # | 议题 | 决定 |
|---|------|------|
| Q1 | 最低 macOS 版本 | 14 |
| Q2 | 分发渠道 | 以 Developer ID 为主（DMG + Sparkle）。暂时没有 Developer ID 时，`TEAM_ID` 留空即可：用 ad-hoc 签名、跳过公证，整条发布链路照常运行；有了证书后填上 `TEAM_ID` 和 secrets 即切换。MAS 走一条独立路径 |
| Q3 | CPU 架构 | 通用二进制（arm64 + x86_64） |
| Q4 | App Sandbox | 默认开启 |
| Q5 | 打包实现 | 自写脚本（`scripts/`） |
| Q6 | 命令入口 | **Makefile** |
| Q7 | Lint | 只用 `swift format` |
| Q8 | 崩溃上报 | 不内置，只提供接入说明 |
| Q9 | 提交规范 | 本地不装 commit-msg 钩子（不依赖 Node），只在 CI 检查 PR 标题（`amannn/action-semantic-pull-request`）。仓库强制 squash 合并，PR 标题即提交信息。release-please 自己的 PR 跳过 CI 和标题检查（条件：分支以 `release-please--` 开头，且来自本仓库） |
| Q10 | 语义化发版 | release-please（`simple` 类型，版本号写在 `version.txt`，生成 `CHANGELOG.md`，`bump-minor-pre-major`），使用 GitHub App token。模板仓库自己也跑发版流程；新项目用 `scripts/init.sh` 完成首次清理和改名 |

---

## 2. 已验证事实

V1–V8 是规划阶段的实测结论，V9 起是实施过程中新发现的。

| # | 事实 | 处理 |
|---|------|------|
| V1 | `swift build` 只原样拷贝 `.xcassets`、`.xcstrings`，不编译 | 产出 `.app` 一律走 xcodebuild |
| V2 | `swift build` 生成的 `Bundle.module` 只查 `.app` 根目录和构建机绝对路径 | 同上 |
| V3 | `xcodebuild -scheme App` 会编译资源，生成的 accessor 优先查 `Bundle.main.resourceURL` | `scripts/build-app.sh` |
| V4 | `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` 产出通用二进制和 dSYM | release 和 mas 配置 |
| V5 | `actool --app-icon --accent-color` 产出 icns、Assets.car，以及含 `NSAccentColorName` 的 partial plist | 已采用 |
| V6 | `swift test` 可以测 executable target；`xcodebuild test` 的本地化结果跟随机器语言 | 单测不断言文案 |
| V7 | manifest 中的 `.treatAllWarnings(as: .error)` 生效 | B1 |
| V8 | 工具链自带 `swift format`；macOS 15 自带 jq；`dump-package` 能读出 platforms | B2、A7 |
| V9 | 开启 `defaultIsolation(MainActor)` 后，SwiftPM 生成的 `Bundle.module` 也是 MainActor 隔离的；Error 类型是 nonisolated 的，所以 `LocalizedError.errorDescription` 里读不到它 | 本地化文案在 MainActor 代码里解析（`GreeterError.message`），写进 AGENTS.md |
| V10 | 同样的默认隔离下，`Decodable` 等一致性也被隔离到 MainActor，无法在 `@concurrent` 函数里使用 | 跨 actor 使用的值类型写成 `nonisolated struct`（RECIPES 中的片段已编译验证） |
| V11 | xcodebuild 把 Sparkle.framework 放在 `Products/<Config>/` 根目录，而不是 `PackageFrameworks/`；通过 `.unsafeFlags` 添加的 rpath `@executable_path/../Frameworks` 生效；Release 构建的 rpath 不含本机绝对路径 | 两处都拷贝 |
| V12 | hardened runtime 的库校验要求 Team ID；ad-hoc 签名 + runtime 的应用拒绝加载自带的 Sparkle.framework，启动即崩 | ad-hoc 不开 runtime；`release.sh` 对 release 包跑冒烟测试 |
| V13 | ad-hoc 签名 + sandbox + Sparkle 端到端可用：本地 HTTP feed 下从 0.1.0（构建号 6）更新到 0.1.1（构建号 7），安装后没有 quarantine 属性，新版正常启动 | 无 Developer ID 的路径成立 |
| V14 | 只在 Info.plist 写 `CFBundleLocalizations`，包内的 zh-Hans 就能生效（截图确认） | A4 |
| V15 | 从终端直接 exec 的 GUI 进程不会成为前台应用（开着台前调度时只出现在侧栏）；用 `open -n -W --env --stdout` 启动会激活应用；`OS_ACTIVITY_DT_MODE=YES` 让 Logger 输出到 stdout/stderr | `make run` 改用 `open` 启动 |
| V16 | xcodebuild 构建包时，Debug 配置定义 `DEBUG`，Release 不定义 | Debug 构建不启动 updater |
| V17 | `Context.environment["APP_STORE"]` 在 xcodebuild 下生效，能去掉 Sparkle；但依赖变空时 SwiftPM 会删除仓库里的 `Package.resolved` | MAS 构建在源码副本上进行 |
| V18 | `actions/create-github-app-token@v3` 的输入是 `client-id`（`app-id` 已弃用）；actionlint 1.7.12 内置的元数据过时，会误报 | 保留 `client-id`；其余 workflow 用 actionlint 校验通过 |
| V19 | `.swift-format` 只写部分键（缩进、行宽）即可，其余取默认值 | B2 |
| V20 | `plutil` 会把键名中的点当作路径分隔符，`com.apple.security.*` 这类键写不进去 | 改用 PlistBuddy |
| V21 | Sparkle 的 `sign_update` / `generate_appcast --ed-key-file` 接受 base64 编码的 32 字节 Ed25519 种子 | 本地测试可以用 openssl 生成密钥，不碰 keychain |

---

## 3. 清单与状态

状态说明：

- ✅ 已在本机实现并实测通过。
- 🟡 已实现，但需要 GitHub（push 之后）或 Apple 证书才能验收。
- 📄 按计划只提供文档；文档中的代码片段已编译验证。

| ID | 项 | 落地位置 | 状态 |
|----|----|----------|------|
| A1 | Package.swift 与目录 | `Package.swift`、`Sources/App`、`Sources/AppCore`、`Tests/AppCoreTests` | ✅ |
| A2 | 应用身份单一来源 | `Bundle/app.env` | ✅ |
| A3 | App 入口骨架 | `Sources/App/MainApp.swift`、`AppDelegate.swift` | ✅ |
| A4 | 资源与本地化（en、zh-Hans） | `Sources/AppCore/Resources/Localizable.xcstrings` | ✅ |
| A5 | App 图标与强调色 | `Bundle/Assets.xcassets`（自绘橙子切面占位图标） | ✅（`.icon` 格式未做，见 §5） |
| A6 | Info.plist / Entitlements / 隐私清单 | `Bundle/Info.plist`、`App.entitlements`、`PrivacyInfo.xcprivacy` | ✅ |
| A7 | `.app` 打包脚本 | `scripts/build-app.sh`（debug / release / mas） | ✅ |
| A8 | 本地运行与调试 | `make run`、`scripts/run.sh` | ✅ |
| A9 | 忽略规则与编辑器配置 | `.gitignore`、`.editorconfig` | ✅ |
| B1 | 编译严格度 | `Package.swift` 中的 `swiftSettings` | ✅ |
| B2 | 格式化与 lint | `.swift-format`、`make fmt` / `make lint` | ✅ |
| B3 | Git hooks | `lefthook.yml`（pre-commit 格式化） | ✅ |
| B4 | 测试 | `Tests/AppCoreTests`（Swift Testing，3 个用例） | ✅ |
| B5 | `.app` 冒烟测试 | `scripts/smoke.sh`，同时用于 debug 包和 release 包 | ✅ |
| C1 | 日志 | `Sources/AppCore/Support/Log.swift`、`make logs` | ✅ |
| C2 | 错误处理约定 | `AppModel` 示例 + AGENTS.md | ✅ |
| C3 | 状态与依赖注入 | `AppModel` + `Greeter` 协议 + 测试 stub | ✅ |
| C4 | 本地持久化 | 设置页 `@AppStorage` 示例；Keychain / SwiftData 见 RECIPES | ✅ |
| C5 | 开机启动 | `docs/RECIPES.md` | 📄 |
| C6 | 网络 | `docs/RECIPES.md`，`network.client` 已开 | 📄 |
| C7 | 菜单栏 App | `docs/RECIPES.md` | 📄 |
| C8 | 崩溃上报 | `docs/RECIPES.md` | 📄 |
| C9 | 隐私清单 | `Bundle/PrivacyInfo.xcprivacy`（随所有构建打包） | ✅ |
| E1 | 命令单一入口 | `Makefile`（`make help`） | ✅ |
| E2 | AI 约定 | `AGENTS.md`、`CLAUDE.md` | ✅ |
| E3 | 环境自检 | `make doctor` | ✅ |
| E4 | IDE 支持 | README「Editors」一节 | ✅（Preview 需在 Xcode 中人工确认） |
| E5 | 模板初始化 | `scripts/init.sh`、`make init` | ✅ |
| E6 | 项目文档 | `README.md`、`docs/RELEASING.md`、`.github/SECURITY.md`、`.github/CONTRIBUTING.md` | ✅ |
| F1 | PR CI | `.github/workflows/ci.yml` | 🟡 |
| F2 | 依赖更新 | `.github/dependabot.yml` | 🟡 |
| F3 | 仓库治理 | PR 模板、CODEOWNERS、Issue 模板、`make github-setup` | 🟡 |
| F4 | PR 标题规范 | `.github/workflows/pr-title.yml` | 🟡 |
| G1 | 代码签名 | `build-app.sh`：ad-hoc，或 Developer ID + runtime | ✅ ad-hoc / 🟡 Developer ID |
| G2 | 公证 | `scripts/notarize.sh` | 🟡（无 `TEAM_ID` 时跳过，已验证） |
| G3 | DMG | `scripts/package-dmg.sh` | ✅ |
| G4 | 版本号 | `version.txt` 加 `git rev-list --count HEAD` | ✅ |
| G5 | Release 流水线 | `.github/workflows/release.yml`、`scripts/release.sh`、`publish-github.sh` | ✅ 本地 `make release` / 🟡 CI |
| G6 | 密钥管理 | `scripts/ci-keychain.sh`、`release` environment、`docs/RELEASING.md` | 🟡 |
| G7 | 发布说明 | release-please 的 CHANGELOG；ad-hoc 构建自动追加打开方式说明 | 🟡 |
| G8 | dSYM 存档 | Release 资产 + 保留 90 天的 workflow artifact | ✅ 本地 / 🟡 CI |
| H1 | Sparkle 自动更新 | `Sources/App/Updates.swift`、`scripts/appcast.sh`、`make sparkle-keys` | ✅ 本地端到端 / 🟡 GitHub |
| H2 | Homebrew Cask | `scripts/update-cask.sh`，通过 `vars.HOMEBREW_TAP` 启用 | 🟡 |
| H3 | Mac App Store | `make release-mas` / `make upload-mas` | 🟡（构建链路已用替代身份验证） |
| H4 | 测试版通道 | `docs/RELEASING.md` | 📄 |

---

## 4. 与原计划的差异

- Taskfile 改成 Makefile（Q6），命令名为 `release-app`、`release-dmg` 等。
- **G4 版本号**：来源从 git tag 改为 `version.txt`，由 release-please 维护。脚本不再要求 HEAD 正好在 tag 上，因为正式发布只走 CI，而 tag 由 release-please 创建。
- **G5 发布触发**：不再由推 tag 触发，改为同一个 workflow 里 release-please 创建 Release 之后的 publish job。原因是 `GITHUB_TOKEN` 创建的 tag 不会触发其他 workflow。
- **G7 发布说明**：从 `--generate-notes` 改为 release-please 生成的 CHANGELOG。
- **G1**：ad-hoc 发布不开 hardened runtime（V12）。
- **B3**：没有 commit-msg 钩子（Q9）。**F4**：从 P2 提升为已实现。
- **H1**：`SUFeedURL` 由 `RELEASES_URL` 推导；联网用 `network.client`，不用 Downloader XPC（Sparkle 文档建议这样做）。
- **A8**：`make run` 改用 `open` 启动（V15）；没有终端时日志写到 `.build/app/run.log`。
- **C2**：`GreeterError` 不实现 `LocalizedError`（V9）。
- **新增**：
  - `PrivacyInfo.xcprivacy` 随所有构建打包。
  - `ci-keychain.sh` 负责 CI 中证书的导入和清理。
  - `publish-github.sh` 负责上传资产，并给 ad-hoc 的 Release 追加打开说明。
  - `github-setup.sh` 落实仓库设置：只允许 squash、分支保护、`release` environment。

---

## 5. 已知限制与未完成项

| 项 | 说明 |
|----|------|
| 没有 XCUITest | 纯 SPM 无法建 UI Testing target；用冒烟测试 + 模型层测试 + 人工检查代替 |
| Xcode Run 跑的是裸可执行文件 | 没有 bundle ID、不受 sandbox 限制；真实环境请用 `make run` 再附加调试器 |
| 漏写 `bundle: .module` 不会报错 | 已写进 AGENTS.md 的规则 |
| ad-hoc 发布的体验 | 首次打开要在系统设置里点「仍要打开」；每次更新签名都会变，权限和 keychain 访问可能需要重新授权；Homebrew 安装会被 Gatekeeper 拦截 |
| ad-hoc 切换到 Developer ID 的首次更新 | 理论上靠 EdDSA 能通过，**尚未实测** |
| Icon Composer `.icon` | 未实现：需要用 Icon Composer 产出的 `.icon` 文件才能验证 actool 的支持情况；目前使用 `.appiconset` |
| SwiftUI Preview | 视图都在 library target 中，但 Preview 只能在 Xcode GUI 里确认，我没有实测 |
| `make run` 输出到真实终端 | 机制已用文件路径验证；我的执行环境没有 tty，没能直接测试 |
| Developer ID、公证、MAS、所有 GitHub 侧流程 | 需要证书或 push 后才能验收，见 ACCEPTANCE.md |
