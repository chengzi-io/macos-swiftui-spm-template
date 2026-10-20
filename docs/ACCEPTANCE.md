# 验收清单

> 对应 [TEMPLATE-PLAN.md](TEMPLATE-PLAN.md) 的 A–H 各项。分支 `feat/template-infrastructure`，未 push。
> 前置条件：Xcode 26.2 已用 `xcode-select` 选中；已 `brew install lefthook`。

「我的结果」一列的含义：

- ✅ 我已在本机执行，结果与预期一致。
- 👀 需要你看界面或做交互确认。
- ⏳ 需要 push 到 GitHub 之后验收。
- 🔑 需要 Apple 证书或外部账号。

## 1. 本地：现在就能跑

| # | 项 | 命令 / 操作 | 预期 | 我的结果 |
|---|----|-------------|------|----------|
| 1 | E3 | `make doctor` | 每行 `ok`；最后一行 `warn TEAM_ID empty…` | ✅ |
| 2 | B3 | `make setup` | 打印 `sync hooks: ✔️ (pre-commit)` | ✅ |
| 3 | 全链路 | `make ci` | lint 无输出；3 个测试通过；`==> smoke ok: .build/app/Debug/SwiftUITemplate.app` | ✅ |
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
| 15 | B4 | `make test` | `Test run with 3 tests … passed` | ✅ |
| 16 | E4 | `xed .`，打开 `Sources/AppCore/ContentView.swift`，看 Canvas | Preview 能渲染 | 👀 未验证 |
| 17 | H1 | `make sparkle-keys`（会在登录 keychain 创建密钥，这本来就是发版的一次性步骤） | `Bundle/app.env` 中写入 `SPARKLE_PUBLIC_KEY=…`；终端打印导出私钥、设置 secret 的命令 | 🔑 没跑，会写 keychain |
| 18 | G1–G8 | 完成 17 后执行 `make release` | `dist/` 下有 `SwiftUITemplate-0.0.0.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；日志里有 `smoke ok: dist/…`、`dmg ok: dist/…` 和两行 `skipping notarization (ad-hoc build)` | ✅（我用临时生成的密钥对） |
| 19 | Q3 | `lipo -archs dist/SwiftUITemplate.app/Contents/MacOS/SwiftUITemplate` | `x86_64 arm64` | ✅ |
| 20 | G1 | `codesign -dv dist/SwiftUITemplate.app 2>&1 \| grep flags` | ad-hoc 构建显示 `flags=0x2(adhoc)`，**不带** runtime（原因见 TEMPLATE-PLAN V12） | ✅ |
| 21 | H1 | `cat dist/appcast.xml` | 包含 `sparkle:edSignature`，下载地址为 `…/releases/download/v0.0.0/SwiftUITemplate-0.0.0.dmg` | ✅ |
| 22 | H1 | 本地 Sparkle 端到端（可选，见下面的 §1.1） | 0.1.0 自动更新到 0.1.1，更新后的应用正常启动 | ✅ |
| 23 | H3 | `make release-mas` | 报错 `App Store builds need TEAM_ID`（不会落到 ad-hoc） | ✅ |
| 24 | H3 | MAS 构建链路（用替代身份模拟） | `.app` 里没有 Sparkle、没有 `SU*` 键；带 `application-identifier` 和嵌入的 profile；`Package.resolved` 不被改动 | ✅ |
| 25 | H2 | `make release` 之后执行 `scripts/update-cask.sh print \| ruby -c` | `Syntax OK` | ✅ |
| 26 | E5 | 在一个临时 clone 里：`scripts/init.sh --name MyApp --bundle-id com.example.myapp --display-name "My App" --copyright "Jane Doe" --repo acme/my-app --codeowner @jane`，然后 `make ci` | 改动涉及 app.env、LICENSE、README、AGENTS.md、CODEOWNERS、Issue 模板和 Makefile：README 整个换成「My App」的应用页面（介绍占位、从 `acme/my-app` 的 latest release 安装、首次打开、更新、开发文档链接），AGENTS.md 的「Before init」一节被删除；init.sh 与两份模板文档被删除；仓库里不再有指向它们的引用，剩下的 Markdown 相对链接都有效；`make ci` 通过，产物是 `MyApp.app`，bundle ID 为 `com.example.myapp` | ✅ |
| 27 | E5 | 工作区不干净时运行 init | 报错 `commit or stash your changes first` | ✅ |
| 28 | 文档 | 阅读 `AGENTS.md`、`README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md`、`docs/RECIPES.md` | C5–C9、H4 都有说明；RECIPES 里的 Swift 片段能编译 | ✅ 片段已编译 |
| 29 | A5 | `open -a "Icon Composer" Bundle/AppIcon.icon`（Icon Composer 在 Xcode 菜单 Open Developer Tool 里） | 左栏有两个 Group（segments、rind），右栏 Fill 为两色渐变；画布是 Liquid Glass 预览，底部能切换 Default、Dark、Mono | ✅（截图） |
| 30 | A5 | `.agents/skills/app-icon/scripts/check-icon.sh`，打开 `.build/app-icon/AppIcon-check.png` 和 `AppIcon-dock.png` | 第一张：macOS 26 的六种外观（深色外观下白色果皮环变成橙色，这是系统自动生成深色版的结果）、32 pt 三种外观，以及本机 Finder 图标（macOS 15 上是扁平图，与 Dock 里一致）。第二张：图标夹在 Safari、Notes、Photos、App Store 中间，128 pt 和 32 pt 各一行，Safari 不带替身箭头 | ✅ macOS 15 |
| 31 | G3 | 没有 `Bundle/DMG/` 时：`make app && scripts/make-dmg.sh .build/app/Debug/SwiftUITemplate.app .build/dmg/plain.dmg`，再挂载 | 卷里只有 `.app` 和 `Applications`，没有 `.background.tiff`；Finder 窗口是普通样式 | ✅ 卷内容 / 👀 窗口样式 |
| 32 | G3 | 设计版 DMG：`mkdir -p Bundle/DMG && cp .agents/skills/dmg/templates/* Bundle/DMG/ && .agents/skills/dmg/scripts/render-dmg-background.sh && make app && .agents/skills/dmg/scripts/preview-dmg.sh`，打开 `.build/dmg/dmg.png`。验收完执行 `rm -rf Bundle/DMG` | 第一次运行会打印 `install dmgbuild into .build/dmgbuild-1.6.7`。截图是 1320×856 的正常窗口（开着台前调度也一样）：白底，两个图标之间有一个灰色小箭头，没有文字；应用图标和 Applications 位于背景预留的位置；标题栏显示应用图标 | ✅（终端需要「屏幕录制」权限） |
| 33 | G3 | 保留第 32 项的 `Bundle/DMG/` 执行 `make release`（临时公钥的做法见 §1.1），然后挂载 `dist/*.dmg`，对卷内的 `.app` 执行 `codesign --verify --deep --strict` | 日志中有 `package … with the Bundle/DMG design`；签名校验通过；`lipo` 显示 `x86_64 arm64` | ✅ |
| 34 | A10 | 在 Claude Code 里说「给这个 app 做个图标」 | agent 一次问清缺的信息（用途、现成的 logo 或图片、颜色、两到四个你喜欢的已装应用）。没有素材时先出 6–8 个黑白构思（`.build/app-icon/concepts.png`）让你挑；再做两三个草稿放在 `.build/app-icon/`，每个都附 check 和 dock 两张图。你认可之前 `Bundle/AppIcon.icon` 不变；认可后替换，`make ci` 通过并提交。两轮都选不出时，agent 停下并建议走生图或找设计师 | 👀 完整流程未跑；脚本见第 37、42–45 项 |
| 35 | B5 | `make app`，把 `.app` 复制一份，删掉其中的 `Contents/Resources/Assets.car`，用 `codesign --force --sign -` 重新签名，再执行 `scripts/smoke.sh <副本>` | 报错 `has no Assets.car`，退出码 1 | ✅ |
| 36 | A11 | 在 Claude Code 里说「美化一下 DMG」，再输入 `/dmg`（Codex 里是 `$dmg`） | 前一句不会触发 dmg skill；`/dmg` 后 agent 铺好白底默认窗口并截图，问你要默认、轻品牌还是标准品牌化；轻品牌给出 2–3 个变体截图（`.build/dmg/a.png` 等）；标准品牌化先用文字提 2–3 个场景，代码画不了的写出生图提示词，你把生成的图交回后放进 `Bundle/DMG/art.png` 再截图；选定后提交 `Bundle/DMG/` | ✅ Claude Code 和 Codex 的自动调用列表里都只有 app-icon（改名前是 brand；Codex 去掉 `agents/openai.yaml` 后会列出 dmg）；✅ 生图提示词里的区域坐标：按坐标画的色块图放进真实 Finder 窗口，图标、标签和箭头都落在预留区域内；👀 完整流程 |
| 37 | A10/A11 | 分别从 `.agents/skills/...` 和 `.claude/skills/...` 两个路径运行 `render-dmg-background.sh`、`check-icon.sh` 与 `concepts.sh` | 两个路径都能跑；`.claude/skills/app-icon`、`.claude/skills/dmg` 是指向 `.agents/skills` 的符号链接 | ✅ |
| 38 | G9 | 第 18 项之后：`scripts/verify-dmg.sh dist/SwiftUITemplate-0.0.0.dmg`；再把 debug 包复制一份，用 `xattr -wx com.apple.FinderInfo 0000000000000000001000000000000000000000000000000000000000000000` 给它加上 Finder 标记，打成 DMG 后同样校验 | 前者输出卷内 app 的 `smoke ok` 和 `dmg ok`；后者报 `resource fork, Finder information, or similar detritus not allowed`，退出码 1（就是之前 `hide_extensions` 那个问题） | ✅ |
| 39 | G9 | 第 18 项之后，换一把不匹配的私钥：`SPARKLE_ED_PRIVATE_KEY=<另一把私钥> scripts/appcast.sh` | `generate_appcast` 本身照常签名、不报错；随后的校验报 `is not signed with the key matching SPARKLE_PUBLIC_KEY`，退出码 1。错误的下载地址、长度和空公钥也都会报错 | ✅ |
| 40 | G10 | `SPARKLE_PUBLIC_KEY` 已设置时执行 `make release-dry-run`；再在 `Bundle/app.env` 里临时填一个 `TEAM_ID` 重跑 | 最后一行是 `dry run: release build and DMG ok`，`dist/` 里只有 `.app` 和 `.dmg`；填了 `TEAM_ID` 时仍是 `identity: -`，并跳过公证 | ✅ |
| 41 | E6 | 把 `README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md` 里的 6 张 mermaid 图用 mermaid 11.4.1 渲染（浅色和深色主题） | 都能渲染，没有报错，也没有 `Unsupported markdown` 节点；文字不重叠 | ✅（本地 Chrome 截图） |
| 42 | A10 | 对一个图层图片缺失的 `.icon`、一个有 5 个组的 `.icon` 分别运行 `check-icon.sh`；再传一个不存在的应用 | 依次报 `actool warned about …`、`actool rejected …`（`Too many visible groups`）、`no app at …`，退出码都是 1 | ✅ |
| 43 | A10 | `image-layer.swift` 依次处理：浅色底的不透明 JPG；透明 PNG，指定 `300 700 300`；32 px 的小图；错误参数 | JPG：提示没有透明、已用 Vision 抠图，输出 1024 × 1024 带透明的图层（主体内部的白色部分被挖空，提示里已说明）；PNG：主体缩到 300 pt，中心在 (700, 300)；小图：提示放大了 24.6 倍；错误参数打印用法并退出 1。用前两张拼成的双组 `.icon` 通过 `check-icon.sh` | ✅ |
| 44 | A10 | 在 `.build/app-icon/concepts/` 放 4 个黑色 SVG，运行 `concepts.sh`；再对空目录运行 | 生成 `concepts.png`，每个构思一大一小（128 pt、32 pt）并排；线条细的构思在 32 pt 下明显发糊；空目录报 `no .svg in …` | ✅ |
| 45 | B5 | 临时移走 `Bundle/AppIcon.icon/Assets/rind.svg`，`make app`，再放回 | 构建失败，日志中有 `Icon export exited with status 255` 和 `actool warned`；放回后 `make app` 通过 | ✅ |

### 1.1 本地 Sparkle 端到端（第 22 项的复现步骤）

用一个临时 worktree 构建旧版和新版，再用本地 HTTP 服务模拟 GitHub Releases：

```bash
W=$(mktemp -d)/wt; git worktree add --detach "$W" HEAD; cd "$W"
openssl genpkey -algorithm ed25519 -out key.pem
PRIV=$(openssl pkey -in key.pem -outform DER | tail -c 32 | base64)
PUB=$(openssl pkey -in key.pem -pubout -outform DER | tail -c 32 | base64)
sed -i '' "s|^SPARKLE_PUBLIC_KEY=.*|SPARKLE_PUBLIC_KEY=$PUB|; s|^RELEASES_URL=.*|RELEASES_URL=http://127.0.0.1:8765|" Bundle/app.env

echo 0.1.0 > version.txt && scripts/build-app.sh release
ditto dist/SwiftUITemplate.app ../install/SwiftUITemplate.app
git -c user.name=t -c user.email=t@t commit -q --allow-empty --no-verify -m tmp   # 新版构建号 +1
echo 0.1.1 > version.txt && SPARKLE_ED_PRIVATE_KEY=$PRIV scripts/release.sh
mkdir -p ../srv/latest/download ../srv/download/v0.1.1
cp dist/appcast.xml ../srv/latest/download/; cp dist/*.dmg ../srv/download/v0.1.1/

# 让旧版启动后立即自动检查并自动安装，然后重签
A=../install/SwiftUITemplate.app
codesign -d --entitlements :- "$A" > ../ents.plist
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" -c "Add :SUAutomaticallyUpdate bool true" "$A/Contents/Info.plist"
codesign --force --sign - --entitlements ../ents.plist "$A"

(cd ../srv && python3 -m http.server 8765 --bind 127.0.0.1 &)
open "$A"; sleep 60                                   # 服务日志里应出现 GET appcast.xml 和 GET …0.1.1.dmg
osascript -e 'tell application id "io.chengzi.SwiftUITemplate" to quit'; sleep 20
plutil -p "$A/Contents/Info.plist" | grep ShortVersion   # => 0.1.1
```

验收完清理：停掉 `http.server`，然后执行 `git worktree remove --force "$W"`。

## 2. GitHub：push 之后

| # | 项 | 操作 | 预期 |
|---|----|------|------|
| 1 | F3 | `make github-setup` | 回读结果显示只允许 squash、标题取 PR_TITLE；必需检查为 `["Validate PR title","Lint, test, build","Release dry run"]`；workflow 权限 `read`；`release` environment 只允许受保护分支 |
| 2 | Q10 | 按 `docs/RELEASING.md` 第 2 节创建 GitHub App，设置 `RELEASE_APP_CLIENT_ID` 和 `RELEASE_APP_PRIVATE_KEY` | — |
| 3 | F4 | 开一个标题为 `update stuff` 的 PR | `Validate PR title` 失败；改成 `docs: update readme` 后通过 |
| 4 | F1 | 同一个 PR | `Lint, test, build` 在 `macos-26` 上通过，包括冒烟测试（runner 能否启动 GUI 应用是待验证项，失败时看 job 日志里 smoke 那一步） |
| 5 | F2 | 等待 Dependabot 按周运行，或在 Insights → Dependency graph → Dependabot 里手动检查 | PR 标题形如 `chore(deps): bump …` / `ci: bump …` |
| 6 | Q9 | 往 `main` 合并一个 `feat:` PR | release-please 开出**草稿** PR `chore(main): release 0.1.0`，三个检查都显示 **skipped**，合并按钮不可用；再合并一个 PR 进 main，发版 PR 更新后演练仍不跑。点「Ready for review」后 `Release dry run` 开始运行，通过后才能合并 |
| 7 | H1 | 合并前：完成本地第 17 项，提交公钥，执行 `gh secret set SPARKLE_ED_PRIVATE_KEY --env release` | — |
| 8 | G5 | 合并发版 PR | 立刻出现 tag `v0.1.0` 和一个**草稿** Release，publish job 成功后才公开；Release 中有 CHANGELOG 和 ad-hoc 打开说明；资产包括 `.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；workflow artifact 中有 `dsym-v0.1.0` |
| 9 | H1 | `curl -sL https://github.com/chengzi-io/macos-swiftui-spm-template/releases/latest/download/appcast.xml` | 显示 0.1.0 的条目 |
| 10 | Q2 | 在另一台 Mac 上下载 DMG 并安装 | 首次被拦截；到「隐私与安全性 → 仍要打开」后可以运行 |
| 11 | H1 | 合并一个 `fix:` PR，再合并它的发版 PR，得到 v0.1.1；在已安装的 0.1.0 中点「Check for Updates…」 | 发现 0.1.1，安装并重启后版本号正确 |
| 12 | H2 | 设置 `vars.HOMEBREW_TAP` 和 `HOMEBREW_TAP_TOKEN` 后再发一个版本 | tap 仓库中出现 `Casks/swiftuitemplate.rb`；`brew audit --cask <tap>/swiftuitemplate` 通过 |
| 13 | G3 | 在一个提交了 `Bundle/DMG/` 的项目里发版 | 发版 PR 上的 `Release dry run` 和 publish job 都执行了 `actions/setup-python`（Python 3.13），日志中有 `install dmgbuild`；Release 里的 DMG 打开后带背景。没有 `Bundle/DMG/` 的项目里这一步显示 skipped |
| 14 | A5 | 在 `macos-14` 和 `macos-26` runner 上渲染图标（可选，一次性 workflow：下载 `.app`，运行 `.agents/skills/app-icon/scripts/render-icon.swift`，上传 PNG）。macOS 26 的效果本地已能用 ictool 看到，这一项只是在真机上确认 | 14 上是扁平图；26 上是 Liquid Glass，与第 30 项的 ictool 渲染一致 |
| 15 | G5 | 让一次发版失败：发版前临时删掉 `SPARKLE_ED_PRIVATE_KEY` secret，合并发版 PR | publish job 失败，Release 停在草稿；`releases/latest/download/appcast.xml` 仍是上一版。恢复 secret 后点 Re-run failed jobs，同一个 tag 构建成功并公开 |
| 16 | E6 | 在 GitHub 上打开 `README.md`、`docs/DEVELOPMENT.md`、`docs/RELEASING.md` | mermaid 图都渲染成图，和第 41 项的截图一致（浅色、深色模式） |

## 3. Apple 证书和账号

| # | 项 | 操作 | 预期 |
|---|----|------|------|
| 1 | G1/G2 | 按 `docs/RELEASING.md` 4b 设置 `TEAM_ID` 和 secrets，然后发一个版本 | `spctl --assess --type execute -vv` 输出 `source=Notarized Developer ID`；`xcrun stapler validate` 对 DMG 通过；`codesign -dv` 显示 `runtime` 和正确的 TeamIdentifier |
| 2 | G2 | 本地：`NOTARY_PROFILE=notary make release` | 两次公证都是 `Accepted`，并完成 staple |
| 3 | Q2 | 已安装的 ad-hoc 版本收到第一个 Developer ID 版本的更新 | 更新成功（**尚未验证**） |
| 4 | G6 | 删掉某个 notary secret 后发版 | publish job 在 `ci-keychain.sh setup` 或公证步骤失败，不会退回 ad-hoc |
| 5 | H3 | `MAS_PROVISIONING_PROFILE=… make release-mas`，然后 `make upload-mas` | 生成 `dist/mas/SwiftUITemplate-X.Y.Z.pkg`；构建出现在 App Store Connect 中 |
