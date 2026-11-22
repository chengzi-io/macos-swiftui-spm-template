# 工具链

这个仓库用哪个 Xcode、Swift 和 macOS 版本构建，以及怎么改它们。

## 版本

| 什么 | 版本 | 设在哪 |
| --- | --- | --- |
| Xcode | 26.2，与 CI 相同 | `.xcode-version`（CI、发版 workflow 和 `make doctor` 都读它） |
| CI runner | GitHub 上的 `macos-26` | `.github/workflows/ci.yml`、`release.yml` |
| Swift 编译器 | 6.2，即 Xcode 26.2 里那个 | 跟随 Xcode |
| Swift 语言模式 | 6 | `swift-tools-version: 6.2`（`Package.swift`、`App/Package.swift`）；`SWIFT_VERSION = 6.0`（`App/Configs/Project.xcconfig`） |
| 部署目标 | macOS 14 | `Package.swift` 里的 `platforms`；`Project.xcconfig` 里的 `MACOSX_DEPLOYMENT_TARGET` |
| 警告 | 当错误处理 | `Package.swift` 里的 `.treatAllWarnings(as: .error)`；`Project.xcconfig` 里的 `SWIFT_TREAT_WARNINGS_AS_ERRORS` |

「Swift 6.2」指的是编译器和 manifest 格式；代码是按 Swift 6 语言模式写的。`make doctor`
会打印 macOS 版本和选中的 Xcode，并在该 Xcode 与 `.xcode-version` 不一致时警告（在 CI 里
直接失败）。两个部署目标对不上时 `make lint` 失败。

## 规则

- 只用 Xcode 26.2。不要用 Swift 6.3+ 或 Xcode 27 的 API、flag 和构建设置，因为 CI 用 26.2
  构建，会失败。
- 不要提高 `swift-tools-version`，因为它会改变 manifest API 和每个 target 构建时的默认值。
- 只用 Xcode 26 的 Icon Composer 编辑 `App/Application/AppIcon.icon`，因为更新的 Icon
  Composer 会写进这个 Xcode 一声不响就忽略的键。
- 分两个 PR 升级，不要合在一个里：先 `.xcode-version`，再 `swift-tools-version`。
- 在一个 commit 里同时改两个部署目标，并删掉因此变成死代码的 `#available` 判断。

## 升级 Xcode

1. 先确认 GitHub 的 `macos-26` 镜像里有新的 Xcode：否则 CI 会以
   "is not installed on this runner" 失败。
2. 只改 `.xcode-version`；本地装上并选中同一个 Xcode。
3. `make ci`；修掉新的警告。开 PR（`build: use Xcode 26.x`）。

## 升级 swift-tools-version

1. 在之后的 PR 里，改 `Package.swift` 和 `App/Package.swift` 的第一行。
2. 有新的 upcoming feature，就明确地在 `Package.swift` 的 `common` 设置里打开。
3. `make ci`。开 PR（`build: swift-tools-version 6.x`）。

## Xcode MCP（mcpbridge）

在 macOS 26+、Xcode 26.3+、且工程在 Xcode 里打开的情况下，`xcrun mcpbridge` 让 agent 通过
Xcode 构建、跑测试、渲染 Preview、查 Apple 的文档。这比固定的版本新，所以 `make doctor`
会警告；最终以 CI 为准。macOS 15 上它启动不了，那里 make 目标能做上面这些，只是没有
Preview。

## 为什么 CI 跑在 macos-26 上

GitHub 的 `macos-15` 镜像（15.7.9）在编译 Icon Composer 图标（`AppIcon.icon`）时会让
Xcode 26 崩溃；而 macOS 15.7.2 配 Xcode 26.2 在本地编译得好好的。所以 CI 和发版 workflow
跑在 `macos-26` 上，macOS 15 照样能做本地开发。
