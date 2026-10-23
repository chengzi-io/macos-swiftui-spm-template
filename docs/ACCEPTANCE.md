# 验收清单

> 对应 [TEMPLATE-PLAN.md](TEMPLATE-PLAN.md) 的 A–H 各项。分支 `feat/template-infrastructure`，未 push。
> 前置条件：Xcode 26.2 已用 `xcode-select` 选中；已 `brew install lefthook`。
> 2026-10-23 起结构改为薄 Xcode 工程加本地包（[TEMPLATE-PLAN.md](TEMPLATE-PLAN.md) 第 4 节末尾），新结构的验收在第 0 节，分支 `feat/thin-xcode-project`。第 1 节起是调整前在旧结构上的结果，其中的 `Bundle/`、`Sources/`、`.build/app/`、`make build` 已不存在。

「我的结果」一列的含义：

- ✅ 我已在本机执行，结果与预期一致。
- 👀 需要你看界面或做交互确认。
- ⏳ 需要 push 到 GitHub 之后验收。
- 🔑 需要 Apple 证书或外部账号。

## 0. 结构调整后（2026-10-23）

| # | 项 | 命令 / 操作 | 预期 | 我的结果 |
|---|----|-------------|------|----------|
| N1 | 全链路 | `make ci` | lint（`swift format` 和 `lint-rules.sh`）无输出；2 个单测通过；`==> smoke ok: .build/xcode/Build/Products/Debug/Pomelo.app` | ✅ |
| N2 | A1 | `xcodebuild -list -project Pomelo.xcodeproj` | Targets 为 Pomelo、PomeloUITests；Schemes 里有 Pomelo | ✅ |
| N3 | B1 | 在 `GreetingModel` 的 init 里加 `let unused = 1`，分别跑 `swift build --package-path Packages/AppModules` 和 `scripts/build-app.sh debug` | 两者都报 `never used` 并失败：包里的警告在 Xcode 构建中同样是错误（V33） | ✅ |
| N4 | B5 | `make app`，删掉 `.app` 里的 `AppModules_SettingsFeature.bundle` 并 ad-hoc 重签，再 `make smoke`；之后删掉整个 `.app` 再 `make app` | 报 `has no AppModules_SettingsFeature.bundle`；不重签时在签名校验处失败。增量构建不会修复被手动改过的产物，`build-app.sh` 的签名校验会报出来 | ✅ |
| N5 | B2 | 在 Greeting、Services、AppRoot 里各放一个违规文件（`ObservableObject` 和 `@Published`、`NavigationView`、`foregroundColor(`、Services 里 `import SwiftUI` 和 `import AppKit`、AppRoot 里 `NSViewRepresentable`），跑 `scripts/lint-rules.sh` | 6 条规则各报一次，退出码 1；删掉后 `make lint` 通过 | ✅ |
| N6 | A6、H1 | `make app` 后 `plutil -p` 看 Info.plist，`codesign -d --entitlements - --xml` 看 entitlements | `SUFeedURL` 指向 `GITHUB_REPOSITORY` 的 releases；mach-lookup 例外是 `<bundle id>-spks`、`-spki`；Debug 带 `get-task-allow`；`Contents/Resources` 有三个资源包、`Assets.car`、`AppIcon.icns`、`PrivacyInfo.xcprivacy`，`Contents/Frameworks` 有 Sparkle | ✅ |
| N7 | G1–G9 | 用 `set_sparkle_public_key` 临时写入公钥，`scripts/build-app.sh release`、`scripts/smoke.sh dist/Pomelo.app`、`scripts/package-dmg.sh`、`scripts/verify-dmg.sh`，再清空公钥 | app 和 Sparkle 都是 `x86_64 arm64`；release 的 entitlements 不含 `get-task-allow`；`smoke ok`、`dmg ok` | ✅（appcast 要 keychain 里的私钥，没跑） |
| N8 | E5 | 在临时 clone 里 `scripts/init.sh --name Demo --bundle-id com.example.demo --display-name "Demo App" --repo acme/demo`，再 `scripts/build-app.sh debug` | `Configs/Identity.xcconfig` 各行更新，`TEAM_ID =` 后没有空格，`SUPublicEDKey` 为空；产物是 `Demo.app`，bundle ID、显示名、版权和 `SUFeedURL` 都对 | ✅ |
| N13 | B5 | 临时移走 `Pomelo/AppIcon.icon/Assets/rind.svg`，跑 `make app`、`make smoke`、`scripts/lint-assets.sh`，再放回 | `make app` 和 `make smoke` 都通过，`.app` 里留着旧图标（V43）；`lint-assets.sh` 报 `Icon export exited with status 255` 和 `actool warned`，退出码 1；放回后 `make lint` 通过 | ✅ |
| N14 | A11 | 在仓库副本里按 dmg skill 第 1、2 步：拷 `wiring/` 两个文件到 `scripts/`，`templates/` 到 `Configs/DMG/`，`render-dmg-background.sh`，`make app`，用接好的 `scripts/make-dmg.sh` 打 DMG 并挂载 | 渲染出 `background.png` 和 `@2x`；首次安装 dmgbuild 1.6.7；卷里有 `.background.tiff`、`.DS_Store`、`.VolumeIcon.icns`、`Applications` 和 app，app 签名校验通过 | ✅（`preview-dmg.sh` 会开 Finder 窗口截图，没跑） |
| N15 | H2 | 同一副本里按 homebrew-cask skill 3.3：拷 `update-cask.sh`，在 `Configs/Identity.xcconfig` 末尾加 `HOMEBREW_TAP`、`HOMEBREW_UNSIGNED = xattr`，`scripts/update-cask.sh print`；再把 `HOMEBREW_UNSIGNED` 清空 | cask 过 `ruby -c`，`depends_on macos: :sonoma` 取自 `Configs/Project.xcconfig`，带 `postflight_steps` 和两条 `zap`；清空后报 `set HOMEBREW_UNSIGNED`；加了这两个键 `make app` 照常 | ✅ |
| N16 | H3 | 仓库副本里按 mac-app-store skill 走「双渠道」（第 2、3a 步）：拷 wiring，拆出 `SparkleUpdater`（模板的 `ServicesLive` 随之删掉），updater 改成可选，`xcodeproj.py link App AppRoot Services SparkleUpdater`、`add-app-store-target AppRoot Services`；`make ci`；AppStore scheme 的 Debug 构建；临时公钥下 `build-app.sh release`；替代身份（假 `TEAM_ID`、假 profile、`find_identity` 返回 `-`）下 `build-app.sh mas`，再 `productbuild` | `xcodebuild -list` 有 AppStore target 和 scheme；`make ci` 通过；AppStore 构建没有 `Frameworks`、没有 `SU*` 键、entitlements 没有 mach-lookup；release 版照常带 Sparkle 和 3 个 `SU*` 键；mas 版 `x86_64 arm64`，带 `embedded.provisionprofile`、`application-identifier` 和 `team-identifier`，`productbuild` 能打成 pkg；没有 profile 时报 `set MAS_PROVISIONING_PROFILE` | ✅ |
| N17 | H3 | 另一个副本里走「只上 App Store」（第 2、3b 步），`make fmt`、`make ci`，替代身份下 `build-app.sh mas` | `make ci` 通过（不先 `make fmt` 时 lint 报格式问题，skill 里因此写了这一步）；Xcode 删掉工程里的 `Package.resolved`；mas 版同 N16 | ✅ |
| N18 | H3 | `xcodeproj.py` 的反例：重复 `add-app-store-target`、链接不存在的产品、不存在的 target、不带参数 | 各自报错退出 1，pbxproj 的哈希不变 | ✅ |
| N19 | B4 | 视图快照：首次 `make test` 录制、再跑；`CI=true make test`；`SNAPSHOT_TESTING_RECORD=all make test`；`xcodebuild test -only-testing:GreetingFeatureTests`；看三张 PNG | 首次 3 个快照报 `No reference was found` 并录下，再跑全过；`CI=true` 时套件跳过；重录的图逐字节相同；xcodebuild 下 5 个用例全过（scheme 固定英文后，V49）；亮色、暗色都像真实窗口（V48） | ✅ |
| N20 | B4 | 录制关卡：删掉一张参考图跑 `make test`；内边距改 36 跑 `make test`；`make snapshots` | 参考图缺失时报 `New snapshot was not recorded because recording is disabled`，文件没被补回；改内边距 3 张都失败（容差 0.98 下）；`make snapshots` 第一轮录制、第二轮通过，图固定 720×400 | ✅ |
| N21 | B4 | `scripts/check-snapshot-review.sh` 在临时 git 仓库里模拟 7 种 PR 情况，`gh` 换成记录调用的假命令 | 没改截图通过；改了没标签失败；有标签通过；之后的推送没碰截图保留标签；推送改了截图或强推后摘标签并失败；只有别的标签失败 | ✅（GitHub 上的真实运行要 push 后看） |
| N22 | E5 | 临时 clone 里 `scripts/init.sh --name Demo …`，接着 `make test`、`make snapshots`、`make ci`；把 `ci.yml` 的 runner 临时改成 `macos-26` 跑 `make doctor`；init 的 runner 替换换成 26 在副本上跑 | init 打印 `CI and releases on macos-15 like this Mac`，两个 workflow 的 macOS runner 跟本机一致，示例的 3 张参考图被删；随后 `make test` 报 `recording is disabled`；`make snapshots` 录下 3 张后 `make ci` 通过；runner 不一致时 doctor 给 warn 和修法；替换只动 `macos-*`，不动 `ubuntu-latest` | ✅（`make snapshots` 时是否弹出 Claude Code 的询问，要用户确认） |
| N23 | C5 | 临时 clone 里照 RECIPES 加开机启动（服务、mock、live、设置页开关、`MainApp` 装配），`make ci`；临时测试把 `SettingsView` 按 `disabled`、`requiresApproval` 两种状态渲染成 PNG | `make ci` 通过；`requiresApproval` 时开关变灰，下面是说明和「Open Login Items…」按钮；真实的 System Settings 来回没试 | ✅（系统设置里关掉再打开要装到 `/Applications` 后手动试） |
| N24 | C10 | 同一个 clone 里照 RECIPES 加 KeyboardShortcuts 3.1.0、`Shortcuts.swift`、录制控件和 `AppModel` 的监听，`make fmt`、`make ci`；看 N23 渲染的 PNG | `make fmt` 没改动；`make ci` 通过，`.app` 里有 `KeyboardShortcuts_KeyboardShortcuts.bundle`；设置页多出「Show app」一行和「Record Shortcut」录制框 | ✅（录一个快捷键、切到别的 app 按下去要手动试） |
| N25 | A1、E5 | 本仓库 `make ci`（根目录还留着 Xcode 写出的空壳 `App.xcodeproj`）；临时 clone 里 `scripts/init.sh --name Kumquat …`，再 `scripts/rename.sh Notes`，加 mac-app-store 的 AppStore target 后 `scripts/rename.sh Timer`，每次之后 `make lint`、`make app`、`make smoke`；另跑 `swift test --skip GreetingViewSnapshotTests`、UI 测试的 `build-for-testing`、不带参数的 `check-icon.sh`、`xcodeproj.py link`；rename.sh 用 `Timer`（同名）、`Configs`、`Products`、`bad-name`、脏工作区、两个带 pbxproj 的工程各跑一次 | `make ci` 通过，空壳目录被忽略；init 后没有 `Pomelo` 残留，scheme 里 `Kumquat.app`、`container:Kumquat.xcodeproj`；改成 Notes 的 diff 只有 pbxproj、scheme、`Identity.xcconfig`、`UITests.xcconfig` 和四个路径，check-icon.sh 里的 `Notes.app` 没被改；三个名字下 lint、构建、冒烟都通过，UI 测试 target 能编译，check-icon 找到 `Notes/AppIcon.icon`；改成 Timer 后 Targets 为 Timer、TimerUITests、AppStore，AppStore 的 scheme 指向 `Timer.xcodeproj`；出错的几种都在写文件前退出并说明原因，两个工程时 `make` 也报错 | ✅（init 删掉参考图后，`exclude: ["__Snapshots__"]` 让 SwiftPM 报 `Invalid Exclude … File not found`，第一次 `make snapshots` 建出目录后消失；用 Xcode 打开改名后的工程，`git status` 是否干净要手动看；`make test:ui` 没在本机跑） |
| N9 | B4 | `make test:ui` | 应用启动，自动输入 `Ada` 并点击 Greet，测试通过 | ✅（前两次失败：启动参数让应用没有窗口，V44；macOS 上文本的内容在 `value` 里，V45） |
| N10 | E4 | `xed Pomelo.xcodeproj`，打开 `Features/Greeting/GreetingView.swift` 看 Canvas，再点 Run | Preview 能渲染；Run 启动真正的 `.app` | 👀 |
| N11 | E2 | Xcode 26.3，工程在 Xcode 里打开时，agent 通过 `xcrun mcpbridge` 构建、跑测试、渲染 Preview | 都成功 | ❌ macOS 15.7.2 上 `mcpbridge` 启动即崩（V46），要 macOS 26；Xcode 26.3 下 `make ci` 通过 |
| N12 | F1 | PR 上的 CI | `make ci` 之后，`automationmodetool` 和 `make test:ui` 两步通过 | ⏳ |

## 1. 本地：现在就能跑

| # | 项 | 命令 / 操作 | 预期 | 我的结果 |
|---|----|-------------|------|----------|
| 1 | E3 | `make doctor` | 每行 `ok`；最后一行 `warn TEAM_ID empty…` | ✅ |
| 2 | B3 | `make setup` | 打印 `sync hooks: ✔️ (pre-commit)` | ✅ |
| 3 | 全链路 | `make ci` | lint 无输出；2 个测试通过；`==> smoke ok: .build/app/Debug/Pomelo.app` | ✅ |
| 4 | A8 | 在终端里 `make run` | 窗口出现在**前台**；终端打印 `[app] launched version=0.0.0 … sandboxed=true`；按 Ctrl-C 后应用退出 | ✅ 无终端模式（日志写到 `.build/app/run.log`）和模拟 Ctrl-C；👀 真实终端输出 |
| 5 | A4 | `make run ARGS="-AppleLanguages '(zh-Hans)'"` | 输入框占位符显示「名字」，按钮显示「打招呼」 | ✅（截图） |
| 6 | A5 | `make run` 后看 Dock 和 Finder 里的应用图标；看按钮颜色 | 橙色渐变圆角方形，上面是白色果皮环和 8 瓣浅色果肉，果肉有玻璃边缘高光；默认按钮是橙色 | ✅ 强调色；✅ 图标（用渲染脚本，同第 30 项）/ 👀 Dock |
| 7 | C2 | 名字留空，点「Greet」 | 弹出 alert，提示 `Please enter a name.`（中文环境下为「请输入名字。」）；`make logs` 里出现 `greet failed: emptyName` | 👀 |
| 8 | C3 | 输入 `Ada`，按回车 | 显示 `Hello, Ada!` | 👀 |
| 9 | C4 | ⌘, → 在 Default name 中填 `Ada` → 退出 → `make run` | 输入框已预填 `Ada` | 👀 |
| 10 | H1 | Debug 构建：应用菜单 →「Check for Updates…」 | 菜单项是灰的（Debug 构建不启动 updater） | 👀 |
| 11 | C1 | 一个终端 `make logs`，另一个 `make run`，然后退出应用 | 依次看到 `launched …` 和 `terminating` | ✅ |
| 12 | B2/B3 | 新建一个 2 空格缩进的 `.swift` 文件并 `git add`，然后 `make lint`，再 `git commit` | `make lint` 报 `[Indentation]` 并失败；提交时钩子把它改成 4 空格并重新暂存 | ✅ |
| 13 | B1 | 在任意函数里加一行 `let unused = 1`，然后 `make build` | 编译错误 `never used`（警告视为错误） | ✅ |
| 14 | B5 | `make app && rm -rf .build/app/Debug/*.app/Contents/Resources/App_AppCore.bundle && make smoke` | 冒烟测试失败。如果先重新签名绕过静态检查，会看到 `Fatal error: unable to find bundle named App_AppCore` 和 `exited during startup` | ✅ |
| 15 | B4 | `make test` | `Test run with 2 tests … passed` | ✅ |
| 16 | E4 | `xed .`，打开 `Sources/AppCore/ContentView.swift`，看 Canvas | Preview 能渲染 | 👀 未验证 |
| 17 | H1 | `make sparkle-keys`（会在登录 keychain 创建密钥，这本来就是发版的一次性步骤） | `Bundle/app.env` 中写入 `SPARKLE_PUBLIC_KEY=…`；终端打印导出私钥、设置 secret 的命令 | 🔑 没跑，会写 keychain |
| 18 | G1–G8 | 完成 17 后执行 `make release` | `dist/` 下有 `Pomelo-0.0.0.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；日志里有 `smoke ok: dist/…`、`dmg ok: dist/…` 和两行 `skipping notarization (ad-hoc build)` | ✅（我用临时生成的密钥对） |
| 19 | Q3 | `lipo -archs dist/Pomelo.app/Contents/MacOS/Pomelo` | `x86_64 arm64` | ✅ |
| 20 | G1 | `codesign -dv dist/Pomelo.app 2>&1 \| grep flags` | ad-hoc 构建显示 `flags=0x2(adhoc)`，**不带** runtime（原因见 TEMPLATE-PLAN V12） | ✅ |
| 21 | H1 | `cat dist/appcast.xml` | 包含 `sparkle:edSignature`，下载地址为 `…/releases/download/v0.0.0/Pomelo-0.0.0.dmg` | ✅ |
| 22 | H1 | 本地 Sparkle 端到端（可选，见下面的 §1.1） | 0.1.0 自动更新到 0.1.1，更新后的应用正常启动 | ✅ |
| 23 | H3 | 模板默认：`grep -rn 'APP_STORE\|release-mas' Package.swift Sources scripts Makefile`，`make help` | grep 没有结果；`make help` 里没有 `release-mas` | ✅ |
| 24 | H3 | 在两个临时 worktree 里按 `mac-app-store` skill 分别走「双渠道」（第 2、3a 步）和「只上 App Store」（第 2、3b 步），各跑 `make ci`；再用替代身份（假 `TEAM_ID`、假 profile、`find_identity` 返回 `-`）执行 `scripts/build-app.sh mas`，不设 profile 时也跑一次 | 双渠道改完后 `Package.swift`、`Sources/`、`Makefile` 与移出前的版本逐字相同；两种方案 `make ci` 都通过；mas 产物没有 Sparkle、没有 `SU*` 键，带 `application-identifier`、`team-identifier` 和嵌入的 profile，`lipo` 为 `x86_64 arm64`，`productbuild` 能打成 pkg；双渠道下 `Package.resolved` 不变，只上 App Store 时它被删除；没有 profile 时报 `set MAS_PROVISIONING_PROFILE`；第 3b 步的 grep 列出剩下要改的文档和配置 | ✅ |
| 25 | H2 | 模板默认：`grep -rn 'HOMEBREW\|update-cask' scripts .github`。再在临时 worktree 里按 `homebrew-cask` skill 接入（`update-cask.sh`、`app.env`、`homebrew` job），`make release` 之后分别生成 C（临时填 `TEAM_ID`）、A（`caveats`）、B（`xattr`）三种 cask，以及 `TEAM_ID` 和 `HOMEBREW_UNSIGNED` 都空的情况；三种 cask 放进本地 tap 跑 `brew style`、`brew audit --cask`；A、B 从本地 HTTP 服务装到临时 `--appdir` | grep 没有结果；都空时报 `set HOMEBREW_UNSIGNED`；三种 cask 的 `ruby -c`、`brew style`、`brew audit` 都通过；`release.yml` 里的 `homebrew` job 依赖 release-please 和 publish；B 装好的 app 没有 `com.apple.quarantine`；A 装好的 app 带 quarantine，安装输出里有 caveats；`zap` 列出 `Application Scripts` 和 `Containers` 两个目录 | ✅ |
| 25a | H2 | 官方 `homebrew/cask`：按 skill 第 2 步用模板的值写 cask，放进本地 tap 跑 `brew style` 和 `brew audit --new --cask`；再对一个真实 GitHub 项目（exelban/stats）的 cask 分别不写 livecheck 和写 `strategy :github_latest`，跑 `brew livecheck --debug` | `brew style` 没有问题；`brew audit --new` 只报仓库不够知名、下载 404 和 GitHub API 404（本仓库还没公开），说明审计会联网检查知名度和下载；不写 livecheck 时策略是 `Git`（读 tag），写了是 `GithubLatest`（读 `releases/latest`），两者都拿到最新版本 | ✅ |
| 26 | E5 | 在一个临时 clone 里：`scripts/init.sh --name MyApp --bundle-id com.example.myapp --display-name "My App" --copyright "Jane Doe" --repo acme/my-app --codeowner @jane`，然后 `make ci` | 改动涉及 app.env、LICENSE、README、AGENTS.md、CODEOWNERS、Issue 模板和 Makefile：README 整个换成「My App」的应用页面（介绍占位、从 `acme/my-app` 的 latest release 安装、首次打开、更新、开发文档链接），AGENTS.md 的「Before init」一节被删除；init.sh 与两份模板文档被删除；仓库里不再有指向它们的引用，剩下的 Markdown 相对链接都有效；`make ci` 通过，产物是 `MyApp.app`，bundle ID 为 `com.example.myapp` | ✅ |
| 27 | E5 | 工作区不干净时运行 init | 报错 `commit or stash your changes first` | ✅ |
| 28 | 文档 | 阅读 `AGENTS.md`、`README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md`、`docs/RECIPES.md` | C5–C9、H4 都有说明；RECIPES 里的 Swift 片段能编译 | ✅ 片段已编译 |
| 29 | A5 | `open -a "Icon Composer" Bundle/AppIcon.icon`（Icon Composer 在 Xcode 菜单 Open Developer Tool 里） | 左栏有两个 Group（segments、rind），右栏 Fill 为两色渐变；画布是 Liquid Glass 预览，底部能切换 Default、Dark、Mono | ✅（截图） |
| 30 | A5 | `.agents/skills/app-icon/scripts/check-icon.sh`，打开 `.build/app-icon/AppIcon-check.png` 和 `AppIcon-dock.png` | 第一张：macOS 26 的六种外观（深色外观下白色果皮环变成橙色，这是系统自动生成深色版的结果）、32 pt 三种外观，以及本机 Finder 图标（macOS 15 上是扁平图，与 Dock 里一致）。第二张：图标夹在 Safari、Notes、Photos、App Store 中间，128 pt 和 32 pt 各一行，Safari 不带替身箭头 | ✅ macOS 15 |
| 31 | G3 | 模板默认（没用过 dmg skill）：`grep -rn 'dmgbuild\|setup-python' scripts .github`；`make app && scripts/make-dmg.sh .build/app/Debug/Pomelo.app .build/dmg/plain.dmg`，再挂载 | grep 没有结果；卷里只有 `.app` 和 `Applications`，没有 `.background.tiff`；Finder 窗口是普通样式 | ✅ grep、卷内容 / 👀 窗口样式 |
| 32 | G3 | 设计版 DMG，在一个临时 worktree 里按 skill 第 1、2 步：`cp .agents/skills/dmg/wiring/* scripts/ && mkdir -p Bundle/DMG && cp .agents/skills/dmg/templates/* Bundle/DMG/ && .agents/skills/dmg/scripts/render-dmg-background.sh && make app && .agents/skills/dmg/scripts/preview-dmg.sh`，打开 `.build/dmg/dmg.png`。先不替换 `make-dmg.sh` 跑一次 `preview-dmg.sh` | 没替换时报 `scripts/make-dmg.sh is the plain one`。替换后第一次运行会打印 `install dmgbuild into .build/dmgbuild-1.6.7`。截图是 1320×856 的正常窗口（开着台前调度也一样）：白底，两个图标之间有一个灰色小箭头，没有文字；应用图标和 Applications 位于背景预留的位置；标题栏显示应用图标 | ✅（终端需要「屏幕录制」权限） |
| 33 | G3 | 在第 32 项的 worktree 里执行 `make release`（临时公钥的做法见 §1.1），然后挂载 `dist/*.dmg`，对卷内的 `.app` 执行 `codesign --verify --deep --strict` | 日志中有 `package … with the Bundle/DMG design`；签名校验通过；`lipo` 显示 `x86_64 arm64` | ✅ |
| 34 | A10 | 在 Claude Code 里说「给这个 app 做个图标」 | agent 一次问清缺的信息（用途、现成的 logo 或图片、颜色、两到四个你喜欢的已装应用）。没有素材时先出 6–8 个黑白构思（`.build/app-icon/concepts.png`）让你挑；再做两三个草稿放在 `.build/app-icon/`，每个都附 check 和 dock 两张图。你认可之前 `Bundle/AppIcon.icon` 不变；认可后替换，`make ci` 通过并提交。两轮都选不出时，agent 停下并建议走生图或找设计师 | 👀 完整流程未跑；脚本见第 37、41–44 项 |
| 35 | B5 | `make app`，把 `.app` 复制一份，删掉其中的 `Contents/Resources/Assets.car`，用 `codesign --force --sign -` 重新签名，再执行 `scripts/smoke.sh <副本>` | 报错 `has no Assets.car`，退出码 1 | ✅ |
| 36 | A11 | 在 Claude Code 里说「美化一下 DMG」，再输入 `/dmg`（Codex 里是 `$dmg`） | 前一句不会触发 dmg skill；`/dmg` 后 agent 先把 dmgbuild 接进构建（替换 `scripts/make-dmg.sh`、加依赖清单、在 `release.yml` 里加 setup-python），再铺好白底默认窗口并截图，问你要默认、轻品牌还是标准品牌化；轻品牌给出 2–3 个变体截图（`.build/dmg/a.png` 等）；标准品牌化先用文字提 2–3 个场景，代码画不了的写出生图提示词，你把生成的图交回后放进 `Bundle/DMG/art.png` 再截图；选定后把 `Bundle/DMG/`、两个脚本和 workflow 改动一起提交 | ✅ Claude Code 和 Codex 的自动调用列表里都只有 app-icon（改名前是 brand；Codex 去掉 `agents/openai.yaml` 后会列出 dmg）；✅ 生图提示词里的区域坐标：按坐标画的色块图放进真实 Finder 窗口，图标、标签和箭头都落在预留区域内；👀 完整流程 |
| 37 | A10/A11 | 分别从 `.agents/skills/...`、`.claude/skills/...` 和复制到仓库外的 skill 目录运行 `render-dmg-background.sh`、`preview-dmg.sh`、`check-icon.sh` 与 `concepts.sh`，当前目录是项目的子目录（如 `Sources/`） | 三个位置都能跑，产物都写在项目根目录的 `.build/` 下；`.claude/skills/app-icon`、`.claude/skills/dmg` 是指向 `.agents/skills` 的符号链接；两个 skill 里没有 `scripts/common.sh` 和 `.agents/skills` 路径的引用（`wiring/make-dmg.sh` 装进项目后才 source `common.sh`） | ✅ |
| 38 | G9 | 第 18 项之后：`scripts/verify-dmg.sh dist/Pomelo-0.0.0.dmg`；再把 debug 包复制一份，用 `xattr -wx com.apple.FinderInfo 0000000000000000001000000000000000000000000000000000000000000000` 给它加上 Finder 标记，打成 DMG 后同样校验 | 前者输出卷内 app 的 `smoke ok` 和 `dmg ok`；后者报 `resource fork, Finder information, or similar detritus not allowed`，退出码 1（就是之前 `hide_extensions` 那个问题） | ✅ |
| 39 | G9 | 第 18 项之后，换一把不匹配的私钥：`SPARKLE_ED_PRIVATE_KEY=<另一把私钥> scripts/appcast.sh` | `generate_appcast` 本身照常签名、不报错；随后的校验报 `is not signed with the key matching SPARKLE_PUBLIC_KEY`，退出码 1。错误的下载地址、长度和空公钥也都会报错 | ✅ |
| 40 | E6 | 把 `README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md` 里的 6 张 mermaid 图用 mermaid 11.4.1 渲染（浅色和深色主题） | 都能渲染，没有报错，也没有 `Unsupported markdown` 节点；文字不重叠 | ✅（本地 Chrome 截图） |
| 41 | A10 | 对一个图层图片缺失的 `.icon`、一个有 5 个组的 `.icon`、一个图层属性拼错成 `glas` 的 `.icon` 分别运行 `check-icon.sh`；再传一个不存在的应用 | 依次报 `actool warned about …`、`actool rejected …`（`Too many visible groups`）、`unknown property "glas"`、`no app at …`，退出码都是 1 | ✅ |
| 42 | A10 | `image-layer.swift` 依次处理：浅色底的不透明 JPG；透明 PNG，指定 `300 700 300`；32 px 的小图；错误参数 | JPG：提示没有透明、已用 Vision 抠图，输出 1024 × 1024 带透明的图层（主体内部的白色部分被挖空，提示里已说明）；PNG：主体缩到 300 pt，中心在 (700, 300)；小图：提示放大了 24.6 倍；错误参数打印用法并退出 1。用前两张拼成的双组 `.icon` 通过 `check-icon.sh` | ✅ |
| 43 | A10 | 在 `.build/app-icon/concepts/` 放 4 个黑色 SVG，运行 `concepts.sh`；再对空目录运行 | 生成 `concepts.png`，每个构思一大一小（128 pt、32 pt）并排；线条细的构思在 32 pt 下明显发糊；空目录报 `no .svg in …` | ✅ |
| 44 | B5 | 临时移走 `Bundle/AppIcon.icon/Assets/rind.svg`，`make app`，再放回 | 构建失败，日志中有 `Icon export exited with status 255` 和 `actool warned`；放回后 `make app` 通过 | ✅ |
| 45 | A10 | 复制模板图标，依次改：只在深色外观生效的深色底和白色果皮环；前组 `specular: false`、`blur-material: 0.8`；果肉层 `position` 缩到 0.7、上移 60；果皮环只在着色外观隐藏。每份都跑 `check-icon.sh`；再用 `lint-icon.swift` 检查 10 个公开仓库里的 `icon.json` | 都通过检查。深色外观下背景变深、果皮环保持白色；关掉 specular 后果肉的玻璃高光消失；果肉缩小并上移；着色外观下只剩果肉。公开文件里只有 VLC 因为 `refractivity` 不通过，其余 9 个通过 | ✅ |

### 1.1 本地 Sparkle 端到端（第 22 项的复现步骤）

用一个临时 worktree 构建旧版和新版，再用本地 HTTP 服务模拟 GitHub Releases：

```bash
W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD; cd "$W"
openssl genpkey -algorithm ed25519 -out key.pem
PRIV=$(openssl pkey -in key.pem -outform DER | tail -c 32 | base64)
PUB=$(openssl pkey -in key.pem -pubout -outform DER | tail -c 32 | base64)
sed -i '' "s|^SPARKLE_PUBLIC_KEY=.*|SPARKLE_PUBLIC_KEY=$PUB|; s|^RELEASES_URL=.*|RELEASES_URL=http://127.0.0.1:8765|" Bundle/app.env

echo 0.1.0 > version.txt && scripts/build-app.sh release
ditto dist/Pomelo.app ../install/Pomelo.app
git -c user.name=t -c user.email=t@t commit -q --allow-empty --no-verify -m tmp   # 新版构建号 +1
echo 0.1.1 > version.txt && SPARKLE_ED_PRIVATE_KEY=$PRIV scripts/release.sh
mkdir -p ../srv/latest/download ../srv/download/v0.1.1
cp dist/appcast.xml ../srv/latest/download/; cp dist/*.dmg ../srv/download/v0.1.1/

# 让旧版启动后立即自动检查并自动安装，然后重签
A=../install/Pomelo.app
codesign -d --entitlements :- "$A" > ../ents.plist
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" -c "Add :SUAutomaticallyUpdate bool true" "$A/Contents/Info.plist"
codesign --force --sign - --entitlements ../ents.plist "$A"

(cd ../srv && python3 -m http.server 8765 --bind 127.0.0.1 &)
open "$A"; sleep 60                                   # 服务日志里应出现 GET appcast.xml 和 GET …0.1.1.dmg
osascript -e 'tell application id "io.chengzi.Pomelo" to quit'; sleep 20
plutil -p "$A/Contents/Info.plist" | grep ShortVersion   # => 0.1.1
```

验收完清理：停掉 `http.server`，然后执行 `git worktree remove --force "$W"`。

## 2. GitHub：push 之后

| # | 项 | 操作 | 预期 |
|---|----|------|------|
| 1 | F3 | `make github-setup` | 回读结果显示只允许 squash、标题取 PR_TITLE；必需检查为 `["Validate PR title","Lint, test, build"]`；workflow 权限 `read`；`release` environment 只允许受保护分支 |
| 2 | Q10 | 按 `docs/RELEASING.md` 第 2 节创建 GitHub App，设置 `RELEASE_APP_CLIENT_ID` 和 `RELEASE_APP_PRIVATE_KEY` | — |
| 3 | F4 | 开一个标题为 `update stuff` 的 PR | `Validate PR title` 失败；改成 `docs: update readme` 后通过 |
| 4 | F1 | 同一个 PR | `Lint, test, build` 在 `macos-26` 上通过，包括冒烟测试（runner 能否启动 GUI 应用是待验证项，失败时看 job 日志里 smoke 那一步） |
| 5 | F2 | 等待 Dependabot 按周运行，或在 Insights → Dependency graph → Dependabot 里手动检查 | PR 标题形如 `chore(deps): bump …` / `ci: bump …` |
| 6 | Q9 | 往 `main` 合并一个 `feat:` PR | release-please 开出 PR `chore(main): release 0.1.0`，两个必需检查都显示 **skipped**，可以直接合并 |
| 7 | H1 | 合并前：完成本地第 17 项，提交公钥，执行 `gh secret set SPARKLE_ED_PRIVATE_KEY --env release` | — |
| 8 | G5 | 合并发版 PR | 立刻出现 tag `v0.1.0` 和一个**草稿** Release，publish job 成功后才公开；Release 中有 CHANGELOG 和 ad-hoc 打开说明；资产包括 `.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；workflow artifact 中有 `dsym-v0.1.0` |
| 9 | H1 | `curl -sL https://github.com/chengzi-io/macos-swiftui-spm-template/releases/latest/download/appcast.xml` | 显示 0.1.0 的条目 |
| 10 | Q2 | 在另一台 Mac 上下载 DMG 并安装 | 首次被拦截；到「隐私与安全性 → 仍要打开」后可以运行 |
| 11 | H1 | 合并一个 `fix:` PR，再合并它的发版 PR，得到 v0.1.1；在已安装的 0.1.0 中点「Check for Updates…」 | 发现 0.1.1，安装并重启后版本号正确 |
| 12 | H2 | 用 `homebrew-cask` skill 接入、设置 `HOMEBREW_TAP_TOKEN` 后再发一个版本 | Release 公开后 `homebrew` job 运行，tap 仓库中出现 `Casks/swiftuitemplate.rb`；`brew install --cask <owner>/<tap>/swiftuitemplate` 能装上；故意填错 token 时只有 `homebrew` job 失败，Release 照常公开，修好后单独重跑这个 job |
| 13 | G3 | 在一个用 dmg skill 加了设计版的项目里发版 | publish job 执行了 `actions/setup-python`（Python 3.13），日志中有 `install dmgbuild`；Release 里的 DMG 打开后带背景。模板默认的 `release.yml` 里没有这一步 |
| 14 | A5 | 在 `macos-14` 和 `macos-26` runner 上渲染图标（可选，一次性 workflow：下载 `.app`，运行 `.agents/skills/app-icon/scripts/render-icon.swift`，上传 PNG）。macOS 26 的效果本地已能用 ictool 看到，这一项只是在真机上确认 | 14 上是扁平图；26 上是 Liquid Glass，与第 30 项的 ictool 渲染一致 |
| 15 | G5 | 让一次发版失败：发版前临时删掉 `SPARKLE_ED_PRIVATE_KEY` secret，合并发版 PR | publish job 失败，Release 停在草稿；`releases/latest/download/appcast.xml` 仍是上一版。恢复 secret 后点 Re-run failed jobs，同一个 tag 构建成功并公开 |
| 16 | E6 | 在 GitHub 上打开 `README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md` | mermaid 图都渲染成图，和第 40 项的截图一致（浅色、深色模式） |

## 3. Apple 证书和账号

| # | 项 | 操作 | 预期 |
|---|----|------|------|
| 1 | G1/G2 | 按 `docs/RELEASING.md` 4b 设置 `TEAM_ID` 和 secrets，然后发一个版本 | `spctl --assess --type execute -vv` 输出 `source=Notarized Developer ID`；`xcrun stapler validate` 对 DMG 通过；`codesign -dv` 显示 `runtime` 和正确的 TeamIdentifier |
| 2 | G2 | 本地：`NOTARY_PROFILE=notary make release` | 两次公证都是 `Accepted`，并完成 staple |
| 3 | Q2 | 已安装的 ad-hoc 版本收到第一个 Developer ID 版本的更新 | 更新成功（**尚未验证**） |
| 4 | G6 | 删掉某个 notary secret 后发版 | publish job 在 `ci-keychain.sh setup` 或公证步骤失败，不会退回 ad-hoc |
| 5 | H3 | 用 `mac-app-store` skill 加入后：`MAS_PROVISIONING_PROFILE=… make release-mas`，然后 `make upload-mas` | 生成 `dist/mas/Pomelo-X.Y.Z.pkg`；构建出现在 App Store Connect 中 |
| 6 | H2 | 仓库有 Developer ID 且够知名后，按 `homebrew-cask` skill 第 2 步给 `Homebrew/homebrew-cask` 提 PR | 本地 `brew install`、`brew audit --new`、`brew lgtm --online` 通过；PR 被合并后 `brew install --cask <token>` 能装上，下一次发版几小时内 BrewTestBot 自动开出版本 PR |
