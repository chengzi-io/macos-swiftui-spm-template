# macOS SwiftUI SPM 模板：开箱即用清单与实施记录

> 状态：已实施，在本地分支 `feat/template-infrastructure` 上，未 push · 2026-10-18
> 基线：Xcode 26.2（Swift 6.2.3），开发机 macOS 15.7
> 验收清单见 [ACCEPTANCE.md](ACCEPTANCE.md)。这两份是模板专用文档，`scripts/init.sh` 会删除它们。

## 目标

- **开发**：用模板新建仓库 → 运行 `scripts/init.sh` → `make run` 出窗口 → 直接写业务代码。
- **发布**：PR 以 squash 方式合并进 `main` → release-please 维护发版 PR → 合并后自动打 tag、创建草稿 Release → CI 构建、校验并上传 DMG、dSYM、appcast，然后公开 Release → 已安装的应用通过 Sparkle 自动更新。

原则：薄 Xcode 工程（`App/Pomelo.xcodeproj`，只放壳）加仓库根的 Swift 包（`Package.swift`、`Sources/`，放全部代码），2026-10-23 起取代原来的「纯 `Package.swift`，不提交 `.xcodeproj`」（见第 4 节末尾）；一个命令入口（Makefile）；每项都有可执行的验收方式；依赖尽量少；和 chengzi-io 其他模板以及 `github-repo-scaffold` skill 的约定保持一致。

---

## 1. 定稿决策

| # | 议题 | 决定 |
|---|------|------|
| Q1 | 最低 macOS 版本 | 14 |
| Q2 | 分发渠道 | 以 Developer ID 为主（DMG + Sparkle）。暂时没有 Developer ID 时，`TEAM_ID` 留空即可：用 ad-hoc 签名、跳过公证，整条发布链路照常运行；有了证书后填上 `TEAM_ID` 和 secrets 即切换。MAS 不在模板里，由 `mac-app-store` skill 按需加入 |
| Q3 | CPU 架构 | 通用二进制（arm64 + x86_64） |
| Q4 | App Sandbox | 默认开启 |
| Q5 | 打包实现 | Xcode 构建、签名、打包；`scripts/` 只补版本号、release 的 universal 归档和 Developer ID 重签（2026-10-23 前是自写脚本组装 `.app`） |
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
| V4 | `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` 产出通用二进制和 dSYM | release 配置（mas 配置由 skill 加入） |
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
| V17 | `Context.environment["APP_STORE"]` 在 xcodebuild 下生效，能去掉 Sparkle；但依赖变空时 SwiftPM 会删除仓库里的 `Package.resolved` | `mac-app-store` skill 的双渠道方案在源码副本上构建 MAS 版本 |
| V18 | `actions/create-github-app-token@v3` 的输入是 `client-id`（`app-id` 已弃用）；actionlint 1.7.12 内置的元数据过时，会误报 | 保留 `client-id`；其余 workflow 用 actionlint 校验通过 |
| V19 | `.swift-format` 只写部分键（缩进、行宽）即可，其余取默认值 | B2 |
| V20 | `plutil` 会把键名中的点当作路径分隔符，`com.apple.security.*` 这类键写不进去 | 改用 PlistBuddy |
| V21 | Sparkle 的 `sign_update` / `generate_appcast --ed-key-file` 接受 base64 编码的 32 字节 Ed25519 种子 | 本地测试可以用 openssl 生成密钥，不碰 keychain |
| V22 | Xcode 26.2 的 actool 直接接受 `.icon`，可与 `.xcassets` 同时编译。最低系统设为 14 时产出：Assets.car（含 Liquid Glass 分层资源和 16–1024 的扁平图）、只含 16、32、128、256 px 四档的 AppIcon.icns（加 `--standalone-icon-behavior all` 才有全部 10 档，876 KB 对 62 KB），以及 `CFBundleIconName` / `CFBundleIconFile`。一个真实的 Icon Composer 文件（react-native 仓库中的）和我们手写的文件在 macOS 15 上都显示正常；Icon Composer 1.2 能打开我们手写的文件 | A5 改用 `Bundle/AppIcon.icon` |
| V23 | dmgbuild 自己写 `.DS_Store`，不驱动 Finder。`window_rect` 的高度包含 28 pt 标题栏；`hide_extensions` 会在 .app 上写 FinderInfo，导致 `codesign --verify --strict` 失败；背景图配 `@2x.png` 时会自动合成 Retina TIFF；1.6.7 要求 Python ≥ 3.10（Xcode 自带的 python3 是 3.9.6） | 模板不用 `hide_extensions`；窗口高 428 pt；按哈希固定版本，装在 `.build/` 的 venv 里 |
| V24 | 窗口所有者名称是本地化的（中文系统下 Finder 叫「访达」）；带背景图的 DMG 窗口中，Finder 的图标标签是黑字（DropDMG 论坛报告深色模式下也是如此，我只验证了浅色模式） | 预览脚本按 pid 找窗口；skill 要求标签区域保持浅色 |
| V25 | actool 把编译交给常驻的 `ibtoold`，相对路径按 `ibtoold` 自己的工作目录解析。在第二个 checkout（如 worktree）里构建时，会写到甚至读到第一个 checkout 的文件 | `build-app.sh` 和 app-icon skill 的 `check-icon.sh` 都传绝对路径 |
| V26 | mermaid 节点文字以「1. 」开头时会被当作 Markdown 列表，渲染成「Unsupported markdown: list」 | 图里的步骤编号用 ①②③ |
| V27 | Icon Composer 1.2 自带命令行渲染器 `ictool`（`Icon Composer.app/Contents/Executables/ictool`），在 macOS 15 上也能渲染 macOS 26 的 Liquid Glass 效果，外观有 Default、Dark、TintedLight、TintedDark、ClearLight、ClearDark 六种。它不做校验：组超过 4 个、图层图片缺失时照样输出图片 | app-icon skill 用它出检查图，校验交给 actool |
| V28 | actool 对超过 4 个组的 `.icon` 报错退出；图层引用的图片不存在时只给警告（`Icon export exited with status 255`），退出码为 0，而且不产出图标 | `build-app.sh` 和 `check-icon.sh` 都把 actool 的警告当错误 |
| V29 | `.icon` 的图层可以是带透明的 PNG，actool 和 ictool 都能处理，玻璃效果照常。系统自带的 Vision（`VNGenerateForegroundInstanceMaskRequest`，macOS 14+）能从不透明的图里抠出主体，但会把主体内部与背景同色的部分一起挖掉（测试图里火箭的白色舷窗成了洞） | `image-layer.swift`：不透明的图才抠，并提醒检查 |
| V30 | 玻璃效果下，用描边画的开放路径会沿弦多出一条淡线；同样的形状改成填充轮廓就没有。深色前景放在浅色底上，在 Dark 和 Tinted 外观里几乎看不见；浅色或饱和色前景在六种外观里都清楚 | 写进 app-icon skill 的作图规则 |
| V31 | Icon Composer 的其余设置都是 `icon.json` 里的普通属性。格式取自公开仓库里 Icon Composer 保存的 10 个文件（expo、VLC、Firefox iOS、CodeEdit、KeePassXC、Signal、UTM 等），再在模板图标上逐项修改、用 ictool 渲染核对：只在深色外观生效的底色和图层颜色、关掉 specular、blur-material、position（y 向下）、只在着色外观隐藏，都按预期生效；图层的 `fill` 会把整层改成一种颜色。lighting、混合模式和不透明度只核对了格式。actool 对错误取值（未知的混合模式和外观名，`fill`、`position` 里拼错的键）给警告；根、组、层这一级拼错的属性名则被静默忽略。VLC 的文件里有 Icon Composer 1.2 不认识的 `refractivity`，是新版本写的，这个 Xcode 同样会忽略 | skill 里列出属性表；`check-icon.sh` 先用 `lint-icon.swift` 检查属性名 |
| V32 | Homebrew 7.0：flight 块改成声明式的 `postflight_steps`（官方库拒收旧的 `postflight do`，第三方 tap 暂时还能用）；`depends_on macos:` 用裸 symbol 表示最低版本，`">= :sonoma"` 过不了 `brew style`；官方 cask 必须通过 Gatekeeper；第三方 tap 需要 Tap Trust，`brew install --cask owner/tap/token` 这种全名安装只信任这一个 cask；cask 的下载都带 quarantine。官方库收录要求仓库「知名」且建库满 30 天：作者自己提交要 225 star、90 fork 或 90 watcher 之一（别人提交 75、30、30），`brew audit --new` 联网检查（审计报错用的是 75/30/30 的门槛）；收录后 BrewTestBot 每 3 小时按 livecheck 自动提版本 PR（autobump），作者不用管；livecheck 默认用 `Git` 策略读 tag，`:github_latest` 只读已公开的 Release（用 exelban/stats 实测两种策略）；给官方库提 PR 时用了 AI 要在 PR 里说明，提交不能带 AI 署名或 `Assisted-by` 之类的 trailer，维护者的提问要本人回答；`tap_migrations.json` 对 cask 生效（`cask_loader.rb`），能把 `owner/tap/token` 指向官方 cask，但已经从 tap 装上的 cask 不会自动迁移。本地 tap 实测：`postflight_steps` 里 `run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/X.app"]` 在 Homebrew 的沙盒里能清掉 quarantine；`xattr -dr` 在属性不存在时也返回 0；`brew style` 只在 tap 里按 cask 规则检查 | `homebrew-cask` skill 的 cask 写法和检查步骤 |
| V33 | 用 Xcode「Add Local…」加入的本地包（pbxproj 里是 `XCLocalSwiftPackageReference`），Xcode 给包里每个模块都加 `-suppress-warnings`，和 `.treatAllWarnings(as: .error)` 冲突：`Conflicting options '-warnings-as-errors' and '-suppress-warnings'`，构建失败；去掉 treatAllWarnings 后包里的警告在 Xcode 里则完全看不到。改成把包目录作为文件夹引用（`PBXFileReference`，`lastKnownFileType = wrapper`），6 个模块都带 `-warnings-as-errors` 编译 | `App.xcodeproj` 用文件夹引用；AGENTS.md 禁止「Add Local…」 |
| V34 | 模块名和 SwiftUI 类型同名时，不带前缀的用法能编译，带模块前缀的会解析到 SwiftUI 类型：`App.RootView()` 报 `type 'any App' has no member 'RootView'`，`Settings.SettingsView()` 报 `type 'Settings<Content>' has no member 'SettingsView'`（临时包实测） | 功能模块名以 `Feature` 结尾，根模块叫 `AppRoot` |
| V35 | 开启 `MemberImportVisibility` 后，`Logger` 带 `privacy:` 的字符串插值要求本文件 `import OSLog` | 包和工程都开启；写进 AGENTS.md |
| V36 | Xcode 展开 Info.plist 的值和 entitlements 文件里的构建变量（`$(PRODUCT_BUNDLE_IDENTIFIER)-spks`）；包的资源包放在 `Contents/Resources/<包名>_<target>.bundle`；Sparkle.framework 自动嵌入；buildable folder 里的 `.icon` 配 `ASSETCATALOG_COMPILER_APPICON_NAME` 产出 AppIcon.icns 和 Assets.car | 不再需要组装脚本；`smoke.sh` 按 `dump-package` 里带资源的 target 检查资源包 |
| V37 | `xcodebuild archive -destination 'generic/platform=macOS'` 产出 universal 的 app 和 Sparkle（x86_64 arm64），归档的 `dSYMs/` 里有 app 和 Sparkle 各部件的 dSYM；Release 的 entitlements 不含 `get-task-allow` | `build-app.sh release` |
| V38 | `plutil -replace` 和 PlistBuddy 会把整个 plist 改成 tab 缩进，和 `.editorconfig` 的 2 空格冲突 | `SUPublicEDKey` 用 sed 原地替换（`set_sparkle_public_key`） |
| V39 | macOS 自带的 GNU Make 3.81 接受 `test\:ui:` 这样的目标，`make test:ui` 能调用 | UI 测试的入口 |
| V40 | Mac 上的 XCUITest 在真实桌面上启动应用并发送真实的鼠标键盘事件；本机 Automation Mode 关闭且需要认证，`automationmodetool enable-automationmode-without-authentication` 可免认证开启（man page） | UI 测试不进 `make ci`，由 GitHub CI 跑 |
| V41 | Xcode 26.4 起要求 macOS Tahoe 26.2；26.3 是最后一个支持 macOS Sequoia 的版本（Apple 的系统要求页） | 本机（macOS 15.7）停在 26.3 |
| V42 | 本机 PATH 里的 `grep` 是 Homebrew 的 ugrep，其他机器和 CI 是 BSD grep | `lint-rules.sh` 写死 `/usr/bin/grep` |
| V44 | XCUITest 启动参数 `["--ui-testing", "-AppleLanguages", "(en)"]` 让应用一个窗口都没有：AppKit 把 `-key value` 形式的参数读成 defaults，`--ui-testing` 吞掉下一个参数当值，落单的 `(en)` 被当作要打开的文件，SwiftUI 于是不建默认窗口（`open --args strayword` 同样 0 个窗口；把 `--ui-testing` 放到最后则有 1 个） | UI 测试改用环境变量 `UI_TESTING=1` |
| V45 | macOS 的 XCUITest 里，SwiftUI `Text` 对应的 `staticTexts` 元素 `label` 为空，文字在 `value` 里 | UI 测试断言 `value` |
| V46 | Xcode 26.3（17C529）在 macOS 15.7.2 上装得上，`make ci` 通过；但 `xcrun mcpbridge` 一启动就崩：`dyld: Symbol not found: _$s10AppSandbox17ASBBinaryIdentityC14teamIdentifierSSSgvg`，来自私有框架 `AppSandbox.framework`。二进制声明的最低系统是 14.0，实际依赖 macOS 26 的系统框架；Apple 论坛有同样的报错，并称在 macOS 26.3 上可用 | `make doctor` 按系统版本判断，macOS 15 上给 warn；AGENTS.md、DEVELOPMENT.md 写明需要 macOS 26 |
| V47 | swift-snapshot-testing 1.19.6 的 SwiftUI 策略只支持 iOS 和 tvOS；macOS 上包进 `NSHostingView` 用 NSView 的 `.image`，本机按 2x 出图（360×200 pt 得 720×400 px），连跑两次一致，内边距改 4 pt 即失败，失败信息给出参考图和新图两个路径；`SNAPSHOT_TESTING_RECORD` 设默认录制模式（缺省 `missing`），套件上显式写 `record:` 会盖掉它。它的 manifest 连带解析 swift-syntax、swift-custom-dump、xctest-dynamic-overlay，只链接进测试 target，app 里没有它的符号 | 视图快照测试；重录用 `SNAPSHOT_TESTING_RECORD=failed make test` |
| V48 | 不在窗口里的 `NSHostingView` 没人画窗口背景：暗色快照里浅色文字落在透明像素上，看不见 | 快照前加 `.background(Color(nsColor: .windowBackgroundColor))` |
| V49 | 同一台机器上，`xcodebuild test` 跑包测试时编译了字符串目录、跟随系统语言（本机中文），快照里是「名字」「打招呼」；`swift test` 不编译目录，显示英文 key，两者对不上 | `App` scheme 的 TestAction 设 `language = "en"`、`region = "US"`，两种跑法都通过 |
| V50 | 库的源码注释写明快照只能在录制参考图的同一系统上比对；本机 macOS 15，CI 原来是 macOS 26（Liquid Glass 控件）。GitHub 的 macos-15 镜像是 macOS 15.7.9，带 Xcode 26.2 和 26.3 | CI 和发版 job 改到 `macos-15`，快照在 CI 上照常比对；容差 `perceptualPrecision: 0.98` 吸收小版本间的抗锯齿差别，内边距改 4 pt 仍失败 |
| V51 | NSView 策略按主屏幕的缩放出图，CI 的虚拟显示器可能是 1x；自己建 2x 的 `NSBitmapImageRep` 再 `cacheDisplay`，交给 `Snapshotting<NSImage, NSImage>`，尺寸固定。快照默认录制模式改成 `.never`（读 `SNAPSHOT_TESTING_RECORD`，缺省 never）后，删掉参考图再跑只会失败、不会补录 | 只有 `make snapshots` 录制；`.claude/settings.json` 对它和 `gh pr edit` 设 `ask`（Claude Code 文档：ask 规则在 auto 模式下也会问，但匹配时跳过命令前的环境变量赋值，所以拦不住 `SNAPSHOT_TESTING_RECORD=… swift test`，那条靠 AGENTS.md） |
| V52 | 重录能让任何截图失败重新通过，所以快照测试只能发现界面变了，判断不了对不对 | `Snapshot review` 检查（`scripts/check-snapshot-review.sh`）：PR 改了 `__Snapshots__/` 就失败，直到有 `snapshots-reviewed` 标签；之后再推改动截图的提交会摘掉标签。分支保护把它列为必过检查 |
| V53 | 参考图是模板作者那台 Mac 的控件样子；别的 macOS 大版本初始化后，第一次 `make ci` 就会失败（快照默认不录、CI 也不再跳过） | init 删掉示例的参考图，把两个 workflow 的 `runs-on` 设成本机的 macOS 大版本（macos-15、macos-26 镜像都有 Xcode 26.2）；AGENTS.md 的 init 步骤加上 `make snapshots`；`make doctor` 在 CI runner 和本机大版本不一致时 warn |
| V54 | `SMAppService.Status` 有 `requiresApproval`：已注册，但用户在系统设置里收回了许可，只能在那里重新打开（SDK 头文件）。`Toggle(isOn: Binding(get: …, set: setEnabled))` 把方法直接当 `set:` 传进去，Swift 6.2.3 在 IRGen 时崩溃（signal 6，转换成 `@isolated(any)` 闭包的 thunk） | 开机启动食谱按三种状态显示，`requiresApproval` 时给出打开登录项的按钮，App 回到前台时重读状态；`set:` 写成闭包 `{ setEnabled($0) }` |
| V55 | KeyboardShortcuts 3.1.0（2026-09）：Carbon 热键、录制控件、和系统及菜单快捷键的冲突提示，支持沙盒和 App Store，不弹权限；包本身也是 MainActor 默认隔离。`onKeyUp(for:)` 的注释写着以后会弃用、新代码用 `events(for:)`；macOS 15.0、15.1 上沙盒 app 注册不了只带 ⌥ 或 ⌥⇧ 的快捷键，15.2 恢复。同类的 LaunchAtLogin-Modern 2023-12 后没再更新，只包了几行 `SMAppService`；Defaults 和 `@AppStorage`、服务化的 UserDefaults 重叠 | 只给全局快捷键写食谱：名字和录制控件在 SettingsFeature，`AppModel` 用 `events(.keyUp, for:)` 监听；另外两个不引入 |
| V56 | GitHub 的「从模板创建仓库」只复制目录、分支和文件，新仓库从一个提交开始，没有变量或占位符（docs.github.com，2026-10-23）。Xcode 按 `.xcodeproj` 的文件名显示工程名；scheme 的 `BuildableName` 写的是产品名（`$(APP_NAME).app`），只改 `APP_NAME` 不改它时，Xcode 打开工程会自己改回去；手写的 scheme 属性顺序和 Xcode 的不同时，打开工程也会被重排（`effd3ea` 手写的 `language`、`region`）。Xcode 开着工程时把工程目录改名，它会在旧路径下重新写出只有 `xcuserdata` 的 `.xcodeproj`。sourcekit-lsp 只认 SwiftPM 包（或 `compile_commands.json`、BSP），`Packages/AppModules` 里能跳转，Xcode target 里的文件（`<App>/`）拿不到编译参数，实测跳转无结果 | 工程、app 和 UI 测试 target、scheme、源码目录都用 app 名（模板里是 Pomelo）；`scripts/rename.sh` 改 pbxproj 和 scheme 里这几处结构、`TEST_TARGET_NAME`，`git mv` 四个路径，并写 `APP_NAME`、`APP_DISPLAY_NAME`、`BUNDLE_ID`；只在 `version.txt` 为 0.0.0（没发布过）时运行，init 先重置版本再调用它；Makefile、`scripts/` 和 skill 脚本从根目录唯一带 `project.pbxproj` 的 `*.xcodeproj` 推出 `<App>`，文档写 `<App>`，改名不用改它们 |
| V57 | 薄壳 app（代码几乎都在包里）的做法一致：isowords、DroidKaigi 2022/2024 的 `app-ios`、kuglee/SwiftFormatter（macOS）、akbashev/swift-chat 都把 `Package.swift`、`Sources/`、`Tests/` 放在根目录，工程和只有一两个文件的壳放在 `App/`，`App/` 里放一个空的 `Package.swift`（isowords 的注释：「Leave blank. This is only here so that Xcode doesn't display it」），工程用 `lastKnownFileType = wrapper; path = ..;` 引用根目录；厚工程（IceCubes、NetNewsWire、CotEditor、Backyard Birds、Food Truck）才把包放在 `Packages/`、`Modules/` 或并排的目录；根目录主包加 `Packages/` 子包的也有（repoprompt-ce、mori、vChewing-macOS）。Xcode 没法隐藏包里的子目录，只能靠子目录里的 `Package.swift`（Swift 论坛，SwiftPM 维护者）。本机实测：工程在 `App/`、`path = ..;`、scheme 里包测试写 `container:..`，build、build-for-testing 都通过；资源包按 manifest 的 `name` 叫 `<App>_<target>.bundle`；包的 identity 取自目录名 | 包在仓库根，叫 `<App>`；壳是 `App/`：`<App>.xcodeproj`、`Application/`、`UITests/`、`Configs/` 和空的 `Package.swift`；目录按角色命名，rename.sh 只改工程、target、scheme 和包名，不再移动目录 |
| V43 | 图标图层的图片缺失时，Xcode 构建只有一条 `Icon export exited with status 255` 警告，照样成功；删掉 `.app` 重新构建，里面仍有更早构建留下的 AppIcon.icns，所以冒烟测试也通过（V28 的保证在 Xcode 构建里丢了） | `scripts/lint-assets.sh` 在 `make lint` 里单独跑 actool，有警告即失败 |

---

## 3. 清单与状态

状态说明：

- ✅ 已在本机实现并实测通过。
- 🟡 已实现，但需要 GitHub（push 之后）或 Apple 证书才能验收。
- 📄 按计划只提供文档；文档中的代码片段已编译验证。

| ID | 项 | 落地位置 | 状态 |
|----|----|----------|------|
| A1 | 工程与目录 | `App/Pomelo.xcodeproj`（Pomelo、PomeloUITests 两个 target，buildable folders）、`Package.swift`、`Sources/`、`Tests/` 在仓库根（AppRoot、`Features/<Name>`、`Platform/Core`、`Platform/Live`，测试目录镜像 Sources） | ✅ |
| A2 | 应用身份单一来源 | `Configs/Identity.xcconfig`（Xcode 和脚本读同一份） | ✅ |
| A3 | App 入口骨架 | `App/Application/MainApp.swift`（组装根，环境变量 `UI_TESTING=1` 时换 mock）、`AppDelegate.swift`；场景在 `AppRoot/AppScenes.swift` | ✅ |
| A4 | 资源与本地化（en、zh-Hans） | 每个带文案的 target 一份 `Resources/Localizable.xcstrings` | ✅ |
| A5 | App 图标与强调色 | `App/Application/AppIcon.icon`（Icon Composer 格式：两层 SVG 加渐变填充，自绘橙子切面）、`App/Application/Assets.xcassets`（强调色） | ✅ macOS 15 / 🟡 macOS 14、26 |
| A6 | Info.plist / Entitlements / 隐私清单 | `App/Configs/Info.plist`、`App/Configs/App.entitlements`、`App/Application/PrivacyInfo.xcprivacy` | ✅ |
| A7 | `.app` 构建脚本 | `scripts/build-app.sh`（debug：xcodebuild build；release：xcodebuild archive 加重签） | ✅ |
| A8 | 本地运行与调试 | `make run`、`scripts/run.sh` | ✅ |
| A9 | 忽略规则与编辑器配置 | `.gitignore`、`.editorconfig` | ✅ |
| A10 | App 图标 skill | `.agents/skills/app-icon`（`.claude/skills` 里是指向它的符号链接）。三条路：用户的 logo 或图片、agent 画 SVG 图层、写生图提示词让用户去生成。`check-icon.sh` 出两张检查图：一张是 ictool 渲染的 macOS 26 六种外观、32 pt 和本机 Finder 图标，另一张把图标放进已装应用中间的 Dock 行；`concepts.sh` 把黑白构思并排比较；`image-layer.swift` 把图片变成图层，不透明的图先用 Vision 抠图。草稿放在 `.build/app-icon`，用户认可后才替换 `App/AppIcon.icon`；两轮都选不出就停下 | ✅ 脚本 / 👀 完整流程 |
| A11 | DMG skill | `.agents/skills/dmg`，只能由用户启动（Claude Code 用 `disable-model-invocation`，Codex 用 `agents/openai.yaml`）：第一步把 dmgbuild 接进项目（用 `wiring/` 里的 dmgbuild 版 `make-dmg.sh` 替换模板的普通版，加上哈希锁定的依赖清单，在发版 job 里加 setup-python），再铺白底默认窗口，再按用户选择做轻品牌或标准品牌化；代码画不了的插画写生图提示词，生成的图作为 `art.png` 垫在箭头下面。背景一律不放文字 | ✅ 脚本和提示词坐标 / 👀 完整流程 |
| B1 | 编译严格度 | `Package.swift` 的 `swiftSettings`、`App/Configs/Project.xcconfig` | ✅ |
| B2 | 格式化与 lint | `.swift-format`、`make fmt` / `make lint`；`scripts/lint-rules.sh` 拦旧 API 和越层 import | ✅ |
| B3 | Git hooks | `lefthook.yml`（pre-commit 格式化） | ✅ |
| B4 | 测试 | `make test`：`GreetingFeatureTests`（Swift Testing，2 个模型用例和 3 个快照用例）；`make test:ui`：`PomeloUITests`（XCUITest，1 个用例） | ✅ |
| B5 | `.app` 冒烟测试 | `scripts/smoke.sh`，同时用于 debug 包和 release 包；检查签名、Info.plist、资源包、`Assets.car` 和 `AppIcon.icns`，然后启动应用 | ✅ |
| C1 | 日志 | 每个模块一个内部 `Log`（各自的 category）、`make logs` | ✅ |
| C2 | 错误处理约定 | `AppModel` 示例 + AGENTS.md | ✅ |
| C3 | 状态与依赖注入 | 模型经初始化器传给视图（漏传编译失败，`.environment` 漏注入运行时才崩），`AppModel` 持有各功能的模型；碰进程外资源（网络、文件、系统 API、时钟）的服务才写成协议，经初始化器注入，测试传 stub（RECIPES 的网络示例）；纯逻辑的 `Greeter` 是普通类型 | ✅ |
| C4 | 本地持久化 | Keychain / SwiftData 见 RECIPES（设置页的 `@AppStorage` 示例随结构调整删除） | 📄 |
| C5 | 开机启动 | `docs/RECIPES.md` | 📄 |
| C6 | 网络 | `docs/RECIPES.md`，`network.client` 已开 | 📄 |
| C7 | 菜单栏 App | `docs/RECIPES.md` | 📄 |
| C8 | 崩溃上报 | `docs/RECIPES.md` | 📄 |
| C9 | 隐私清单 | `App/Application/PrivacyInfo.xcprivacy`（随所有构建打包） | ✅ |
| C10 | 全局快捷键 | `docs/RECIPES.md`（KeyboardShortcuts 3.1.0） | 📄 |
| E1 | 命令单一入口 | `Makefile`（`make help`） | ✅ |
| E2 | AI 约定 | `AGENTS.md`、`CLAUDE.md` | ✅ |
| E3 | 环境自检 | `make doctor` | ✅ |
| E4 | IDE 支持 | `docs/DEVELOPMENT.md`「Editors」一节；Xcode Run 跑真正的 `.app` | ✅（Preview 需在 Xcode 中确认） |
| E5 | 模板初始化 | `scripts/init.sh`、`make init` | ✅ |
| E6 | 项目文档 | `README.md`（模板首页，init 把它换成应用自己的页面）、`docs/DEVELOPMENT.md`、`docs/RELEASING.md`、`docs/RECIPES.md`、`.github/SECURITY.md`、`.github/CONTRIBUTING.md`；流程用 mermaid 图加少量文字 | ✅ 本地渲染 / 🟡 GitHub 上的渲染 |
| F1 | PR CI | `.github/workflows/ci.yml` | 🟡 |
| F2 | 依赖更新 | `.github/dependabot.yml` | 🟡 |
| F3 | 仓库治理 | PR 模板、CODEOWNERS、Issue 模板、`make github-setup` | 🟡 |
| F4 | PR 标题规范 | `.github/workflows/pr-title.yml` | 🟡 |
| G1 | 代码签名 | Xcode 签 ad-hoc；`build-app.sh release` 由内向外重签：ad-hoc，或 Developer ID + runtime | ✅ ad-hoc / 🟡 Developer ID |
| G2 | 公证 | `scripts/notarize.sh` | 🟡（无 `TEAM_ID` 时跳过，已验证） |
| G3 | DMG | `scripts/package-dmg.sh`、`scripts/make-dmg.sh`：hdiutil 生成普通窗口。设计版完全由 dmg skill（A11）接入，模板里没有 dmgbuild、Python 和对应的 CI 步骤 | ✅ 本地 / 🟡 CI 上的设计版 |
| G4 | 版本号 | `version.txt` 加 `git rev-list --count HEAD` | ✅ |
| G5 | Release 流水线 | `.github/workflows/release.yml`、`scripts/release.sh`、`publish-github.sh`；Release 先建为草稿，资产全部上传后才公开 | ✅ 本地 `make release` / 🟡 CI |
| G6 | 密钥管理 | `scripts/ci-keychain.sh`、`release` environment、`docs/RELEASING.md` | 🟡 |
| G7 | 发布说明 | release-please 的 CHANGELOG；ad-hoc 构建自动追加打开方式说明 | 🟡 |
| G8 | dSYM 存档 | Release 资产 + 保留 90 天的 workflow artifact | ✅ 本地 / 🟡 CI |
| G9 | 产物校验 | `scripts/verify-dmg.sh`：挂载最终 DMG，检查 Applications 链接，对里面的 app 跑冒烟测试，有 Developer ID 时加 Gatekeeper 评估；`scripts/verify-appcast.swift`：appcast 的下载地址、长度和 EdDSA 签名必须与 `SUPublicEDKey` 对得上 | ✅ 本地（含反例） |
| H1 | Sparkle 自动更新 | `Platform/Core/Updater/UpdaterService.swift`（协议和 mock）、`Platform/Live/Updater/LiveUpdaterService.swift`、`scripts/appcast.sh`、`make sparkle-keys` | ✅ 本地端到端 / 🟡 GitHub |
| H2 | Homebrew Cask | `.agents/skills/homebrew-cask`，只能由用户启动，先按 `TEAM_ID` 和仓库知名度选渠道。官方 `homebrew/cask`：有 Developer ID 且仓库够知名时，skill 写好带 `desc` 和 `livecheck`（`:github_latest`）的 cask，在 `homebrew/cask` 的检出里检查，经用户同意后提 PR（说明用了 AI，提交不带 AI trailer）；收录后 BrewTestBot 自动更新，项目里不加 job、不建 tap。自建 tap：每次发版由单独的 `homebrew` job 下载已公开的 DMG，生成 cask 推到 tap；有 Developer ID 时是普通 cask（C），ad-hoc 时二选一：caveats 提示「仍要打开」（A）或安装后清掉 quarantine（B），两种都在 README 加 `[!IMPORTANT]` 提醒。还写了从自建 tap 转到官方库的步骤 | 🟡（自建 tap 的三种 cask 都过了 `brew style` 和 `brew audit`，A、B 用本地 tap 真装过；官方 cask 模板过了 `brew style`，`brew audit --new` 只因本仓库未公开、不够知名和下载 404 而失败；真实的 tap 推送和官方 PR 都没做过） |
| H3 | Mac App Store | `.agents/skills/mac-app-store`，只能由用户启动：双渠道（Sparkle 拆到 `SparkleUpdater` target，新增共用 `App/Application/` 的 `AppStore` target，不链接 Sparkle，用 `APP_STORE` 编译条件区分）或只上 App Store（删掉 Sparkle 和 DMG 发布，`Pomelo` target 就是 App Store 版）；带 `wiring/xcodeproj.py`（改 pbxproj 的唯一入口）、带 mas 配置的 `build-app.sh`、`release-mas.sh` 和 RELEASING 的一节 | 🟡（2026-10-23 按新结构重写，两种方案都在仓库副本里按 skill 走过一遍，签名用的是替代身份） |
| H4 | 测试版通道 | `docs/RELEASING.md` | 📄 |

---

## 4. 与原计划的差异

- Taskfile 改成 Makefile（Q6），命令名为 `release-app`、`release-dmg` 等。
- **G4 版本号**：来源从 git tag 改为 `version.txt`，由 release-please 维护。脚本不再要求 HEAD 正好在 tag 上，因为正式发布只走 CI，而 tag 由 release-please 创建。
- **G5 发布触发**：不再由推 tag 触发，改为同一个 workflow 里 release-please 创建 Release 之后的 publish job。原因是 `GITHUB_TOKEN` 创建的 tag 不会触发其他 workflow。
- **G7 发布说明**：从 `--generate-notes` 改为 release-please 生成的 CHANGELOG。
- **G5 草稿发版**：Release 先公开、后传资产时，`releases/latest` 会立即指向一个还没有 appcast 的 Release：发版的十几分钟里所有更新检查都是 404，失败时一直 404。改为 release-please 建草稿（`draft` 加 `force-tag-creation`，否则 tag 要等公开才建，release-please 找不到上一版），资产传完再公开。
- **G9**：只在发版时才跑的步骤（universal 构建、Release 配置、DMG、公证、appcast）在打 tag 前没人检查，第一次运行就在 publish job 里。`verify-dmg.sh` 和 `verify-appcast.swift` 在上传前检查用户拿到的产物，任何一步失败，Release 都停在草稿。
- **G10 发版演练：已移除**。它曾在发版 PR 上跑 ad-hoc 签名的 universal 构建和 DMG 校验：发版 PR 以草稿打开，点「Ready for review」才跑。草稿 Release 已经保证失败时用户看不到，演练额外换来的只是不浪费一个版本号，代价是第二个 macOS job、第三个必需检查，以及「合并前一刻再点 Ready」的操作纪律。现在发版 PR 的两个必需检查都跳过，合并即发版；仓库内容导致的发版失败，修复后发下一个版本。
- **G1**：ad-hoc 发布不开 hardened runtime（V12）。
- **B3**：没有 commit-msg 钩子（Q9）。**F4**：从 P2 提升为已实现。
- **H1**：`SUFeedURL` 由 `GITHUB_REPOSITORY` 推导（2026-10-23 前是 `RELEASES_URL`）；联网用 `network.client`，不用 Downloader XPC（Sparkle 文档建议这样做）。
- **A8**：`make run` 改用 `open` 启动（V15）；没有终端时日志写到 `.build/run.log`。
- **C2**：`GreeterError` 不实现 `LocalizedError`（V9）。
- **C3**：原来规定所有服务都是协议，`Greeter` 这种纯本地逻辑也套了协议、Live 实现和测试 stub，示例和「不加任务不需要的抽象」相矛盾。改为只有碰进程外资源的服务才抽协议；`Greeter` 改成普通类型，用 typed throws（`throws(GreeterError)`），`AppModel` 的测试直接用真实的 `Greeter`，同步调用。
- **A5**：图标从 `.appiconset` 改为 Icon Composer 的 `.icon`（V22）。
- **文档体系**：README 原来既是模板说明又是开发文档，init 只删掉模板段落，剩下的开发文档对应用的使用者没用。改为按读者分开：模板的 README 只介绍模板，init 把它整个换成给应用使用者看的短页（介绍、安装、首次打开、更新）；开发文档移到 `docs/DEVELOPMENT.md`；AGENTS.md 加一节「Before init」，让 agent 在做应用相关的工作前先问名字和 bundle ID 并运行 init，init 时删掉这一节。发版流程、恢复步骤、构建链路和新项目步骤改为 mermaid 图加少量文字。
- **品牌 skill 改为 app-icon skill**：只做图标，去掉品牌简报。agent 画出来的图标渲染质量没问题，弱点在构思，所以流程的重点放在先比较黑白构思、每轮都出六种外观和 Dock 对比图、草稿不经用户认可不替换、两轮选不出就停。原来让用户去 Icon Composer 看深色和着色效果，现在由 ictool 直接渲染。
- **H3 Mac App Store：移进 skill**。原来模板默认带 `APP_STORE` 开关：`Package.swift` 按环境变量切换依赖，`Sources/` 里 7 处条件编译，`SettingsView` 的公开参数为它做成可选，`build-app.sh` 为它复制源码再构建。不上 App Store 的 app 也背着这些，而这条路只用替代身份验证过。现在模板只有 Sparkle 一条渠道；`mac-app-store` skill 在用户启动时按选择加入双渠道，或者只上 App Store：后者直接删掉 Sparkle 和 DMG 发布，用不着条件编译。
- **H2 Homebrew：移进 skill**。原来 cask 步骤在 publish job 里、排在公开 Release 之后：失败时 Release 已经上线，job 却是红的；ad-hoc 时也照样推一个装上就被 Gatekeeper 拦下的 cask；`depends_on macos: ">= :sonoma"` 是 Homebrew 7 的 `brew style` 不认的旧写法（V32）。现在模板里没有 Homebrew。skill 先选渠道：有 Developer ID 且仓库够知名的直接进官方 `homebrew/cask`，收录后由 Homebrew 自动更新，不需要自建 tap；其余的用自建 tap，cask 放进单独的 job，按 `TEAM_ID` 和 `HOMEBREW_UNSIGNED` 选 C、A 或 B，A、B 都要求 README 加 `[!IMPORTANT]` 提醒。cask 的 `zap` 补上了沙盒应用留下的 `~/Library/Application Scripts/<bundle id>`。
- **DMG 美化**：不作为默认，做成单独的 DMG skill（A11），只能由用户启动。模板不为设计版做任何准备：原来模板的 `make-dmg.sh` 按 `Bundle/DMG/settings.py` 是否存在分两条路，发版 job 也按它决定装不装 Python；现在 dmgbuild 版的 `make-dmg.sh`、依赖清单和 setup-python 步骤都放在 skill 里，用户启动 skill 时才加进项目，和 `Configs/DMG/`（2026-10-23 前是 `Bundle/DMG/`）一起提交，revert 那次提交就回到普通 DMG。
- **skill 按独立项目写**：app-icon 和 dmg 两个 skill 的脚本都不再 source 模板的 `scripts/common.sh`，按 `$(dirname "$0")` 找 skill 自己的文件、按 `git rev-parse --show-toplevel` 找项目，在项目的任意子目录里都能运行；SKILL.md 开头写明各自对项目的要求（`App/AppIcon.icon`、`Configs/Identity.xcconfig`、`make app` 的产物路径、`scripts/make-dmg.sh` 的参数、发版 workflow；2026-10-23 前是 `Bundle/AppIcon.icon`、`Bundle/app.env`），命令里的 skill 目录写成 `<skill>`。两个目录都可以原样搬到单独的仓库。
- **新增**：
  - `PrivacyInfo.xcprivacy` 随所有构建打包。
  - `ci-keychain.sh` 负责 CI 中证书的导入和清理。
  - `publish-github.sh` 负责上传资产，并给 ad-hoc 的 Release 追加打开说明。
  - `github-setup.sh` 落实仓库设置：只允许 squash、分支保护、`release` environment。
- **结构调整：薄 Xcode 工程 + 本地包（2026-10-23）**。纯 SPM 要自写脚本拼 `.app`（V1–V3、V5、V11、V22、V25），建不了 XCUITest 和 App 扩展，Xcode 的 Run 跑的也不是真正的应用。现在 `App.xcodeproj` 只有 App 和 AppUITests 两个 target，用 buildable folders，构建设置全在 `Configs/*.xcconfig`，加文件不碰 pbxproj；全部代码在 `Packages/AppModules`，按层拆 target：`AppRoot`、每个功能一个 `<Name>Feature`、`Services`（协议和 mock）、`ServicesLive`（真实实现，Sparkle 只链接到这里）。功能 target 不依赖 `ServicesLive`，在功能里直接 new 真实实现会编译失败。原来 App target 里的 `Updates`（`ObservableObject`）改成 `UpdaterService` 协议加 `LiveUpdaterService`；设置页的「默认名字」示例删掉，以免两个功能共用一个 UserDefaults 键。身份从 `Bundle/app.env` 搬到 `Configs/Identity.xcconfig`，Sparkle 公钥搬到 `Configs/Info.plist`。新增 `make test:ui`（不进 `make ci`，V40）和 `scripts/lint-rules.sh`。
- **工程改名（2026-10-23）**：`App.xcodeproj`、`App`/`AppUITests` 两个 target、`App` scheme 和 `App/`、`AppUITests/` 目录改用 app 名，模板里是 Pomelo（先试过 `SwiftUITemplate`，太长）。改名放进 `scripts/rename.sh`，init 调用它，init 删掉自己后它还在，首次发布前改名也用它，名字、显示名、bundle id 一起改；发布后再改名或 bundle id 等于换了一个 app（Sparkle 更新、用户数据、Homebrew），脚本拒绝（V56）。先试过的做法是 init 把模板名当占位词全局替换：模板里安全，但 init 之后 app 名可能是 `Notes`、`Timer` 这样的常见词，再全局替换会改坏别处，所以文档改写 `<App>`、脚本从工程推出名字。用这个模板做的多个 app 在 Xcode 最近项目列表里不再都叫 App。`Configs/App.xcconfig`、`App.entitlements` 按角色命名，和 `UITests.xcconfig` 对应，不改名。rename.sh 拒绝工程里已有的词（`Products`、`Debug` 等）和已存在的路径（如 `Configs`），都在写文件之前。
- **结构调整二：包到仓库根，壳进 `App/`（2026-10-23）**：`Packages/AppModules` 的 `Package.swift`、`Sources/`、`Tests/` 移到仓库根，包名从 `AppModules` 改成 app 名；工程、壳的源码、UI 测试和 `Configs/` 移进 `App/`，源码目录叫 `App/Application/`、`App/UITests/`（按角色命名，避免在 Xcode 里和同名的包并排；`App/Sources/` 会和根目录的 `Sources/` 混淆）。参照的是薄壳 app 的做法（V57），之前举的 IceCubes 等厚工程不适用。脚本从 `App/` 里唯一带 `project.pbxproj` 的工程推出 `<App>`，`PACKAGE_DIR` 和 `--package-path` 去掉；SwiftPM 的 `.build` 和 DerivedData（`.build/xcode`）现在在同一个目录。
- **结构调整三：按领域分目录（2026-10-24）**：按技术层分的 `Services`、`ServicesLive` 在服务一多时会各平铺几十个文件，每个功能 import 的都是同一个大模块。现在换成 `Platform/Core`（target `Platform`）和 `Platform/Live`（target `PlatformLive`），里面按能力分子目录（`Updater/`）。`Platform` 只放任何 Mac app 都需要的系统集成；app 自己的业务按领域建 `Sources/<Domain>/{Core,Live}`，和 app 无关的封装放 `Sources/Kits/`（`AppKitBridge` 也归这里）。`Models/` 取消，多个功能共用的类型、纯逻辑和 model 放进领域的 Core。Core 和 Live 并列，而不是 `<能力>/Live` 嵌套：SwiftPM 不允许两个 target 的目录嵌套（实测报 `overlapping sources`），每个能力一对 target 又太多。`lint-rules.sh` 的两条 import 检查从 `Sources/Services` 推广到所有 `Sources/*/Core` 和 `Sources/*/Live`。

---

## 5. 已知限制与未完成项

| 项 | 说明 |
|----|------|
| UI 测试占用鼠标键盘 | Mac 上没有模拟器，`make test:ui` 运行时不能同时用电脑；本地首次运行要输入管理员密码，或先免认证开启 Automation Mode。CI 上的 `automationmodetool` 步骤还没在 runner 上跑过 |
| `mac-app-store` skill | 2026-10-23 按新结构重写，两种方案只用替代身份构建、签名、打包到 `.pkg`，从没提交过 App Store Connect；`altool --upload-app` 没实际上传过 |
| `dmg` skill 的设计文件 | `Bundle/` 没了，改放 `App/Configs/DMG/`（不能放 `App/Application/`：那是 buildable folder，里面的 `.swift` 会编进 app） |
| 视图快照 | 参考图只对录制它的 macOS 大版本有效：本机和 CI 都是 macOS 15，换版本时两边一起换并整体重录、逐张看图。CI 上（15.7.9 对本机 15.7.2）能否通过、`Snapshot review` 检查和标签流程，都要 push 到 GitHub 后才能验证 |
| 结构调整后的 Developer ID 重签 | 重签逻辑和调整前相同，entitlements 改从 Xcode 签好的 app 里取；只验证了 ad-hoc 路径 |
| 漏写 `bundle: .module` 不会报错 | 已写进 AGENTS.md 的规则 |
| ad-hoc 发布的体验 | 首次打开要在系统设置里点「仍要打开」；每次更新签名都会变，权限和 keychain 访问可能需要重新授权；Homebrew（`homebrew-cask` skill）要么首次打开被拦，要么由 cask 清掉 quarantine |
| ad-hoc 切换到 Developer ID 的首次更新 | 理论上靠 EdDSA 能通过，**尚未实测** |
| `.icon` 在 macOS 14 和 26 上的显示 | macOS 15 已在本机验证；macOS 26 的效果用 ictool（Icon Composer 自己的渲染器）看过，没在 macOS 26 真机上看过；macOS 14 未验证 |
| 设计版 DMG | 深色模式下的标签颜色只有论坛报告，没有实测；skill 加进发版 job 的 setup-python 步骤还没在真实 runner 上跑过 |
| 草稿发版 | 只在本地验证过脚本部分。release-please 的 `draft` 加 `force-tag-creation`、草稿下 action 的 `release_created` 输出、`gh` 往草稿上传再公开，都要等第一次真实发版才能确认。universal 构建、Developer ID 签名、hardened runtime、公证和 appcast 签名合并前都不检查，第一次运行就在 publish job 里 |
| DMG 卷图标 | 直接用 app 的 AppIcon.icns，只有 16–256 px。在 64、128 pt 下的渲染与全尺寸版逐字节相同（桌面图标最大就是 128 pt），画得比 128 pt 大时（Quick Look、放大的图标视图）会糊，512 pt 下实测可见。补全尺寸要加 `--standalone-icon-behavior all`，代价是每份 icns 多 0.8 MB，设计版 DMG 里有两份（实测 debug DMG 从 3.0 MB 涨到 4.7 MB），所以没加 |
| app-icon skill | lighting、混合模式和不透明度只核对了格式，没有逐项看渲染效果；属性名清单按 Icon Composer 1.2 整理，换新版 Xcode 时要补充。构思好不好取决于模型和用户的选择，skill 只能靠对比和轮数上限把关。完整流程还没有真实跑过一遍 |
| mermaid 图 | 只用 mermaid 11.4.1 在本地 Chrome 里渲染过（浅色、深色主题）；GitHub 上的渲染要 push 后确认 |
| SwiftUI Preview | 视图都在 library target 中，但 Preview 只能在 Xcode GUI 里确认，我没有实测 |
| `make run` 输出到真实终端 | 机制已用文件路径验证；我的执行环境没有 tty，没能直接测试 |
| Developer ID、公证、MAS、所有 GitHub 侧流程 | 需要证书或 push 后才能验收，见 ACCEPTANCE.md |
