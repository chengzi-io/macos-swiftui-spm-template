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
| 6 | A5 | 看 Dock 和 Finder 里的应用图标；看按钮颜色 | 橙色圆角方形加白色橙子切面；默认按钮是橙色 | ✅ 强调色 / 👀 图标 |
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
| 18 | G1–G8 | 完成 17 后执行 `make release` | `dist/` 下有 `SwiftUITemplate-0.0.0.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；日志里有 `smoke ok: dist/…` 和两行 `skipping notarization (ad-hoc build)` | ✅（我用 openssl 生成的临时密钥） |
| 19 | Q3 | `lipo -archs dist/SwiftUITemplate.app/Contents/MacOS/SwiftUITemplate` | `x86_64 arm64` | ✅ |
| 20 | G1 | `codesign -dv dist/SwiftUITemplate.app 2>&1 \| grep flags` | ad-hoc 构建显示 `flags=0x2(adhoc)`，**不带** runtime（原因见 TEMPLATE-PLAN V12） | ✅ |
| 21 | H1 | `cat dist/appcast.xml` | 包含 `sparkle:edSignature`，下载地址为 `…/releases/download/v0.0.0/SwiftUITemplate-0.0.0.dmg` | ✅ |
| 22 | H1 | 本地 Sparkle 端到端（可选，见下面的 §1.1） | 0.1.0 自动更新到 0.1.1，更新后的应用正常启动 | ✅ |
| 23 | H3 | `make release-mas` | 报错 `App Store builds need TEAM_ID`（不会落到 ad-hoc） | ✅ |
| 24 | H3 | MAS 构建链路（用替代身份模拟） | `.app` 里没有 Sparkle、没有 `SU*` 键；带 `application-identifier` 和嵌入的 profile；`Package.resolved` 不被改动 | ✅ |
| 25 | H2 | `make release` 之后执行 `scripts/update-cask.sh print \| ruby -c` | `Syntax OK` | ✅ |
| 26 | E5 | 在一个临时 clone 里：`scripts/init.sh --name MyApp --bundle-id com.example.myapp --display-name "My App" --copyright "Jane Doe" --repo acme/my-app --codeowner @jane`，然后 `make ci` | 改动涉及 app.env、LICENSE、README、CODEOWNERS、Issue 模板和 Makefile；init.sh 与两份模板文档被删除；`make ci` 通过，产物是 `MyApp.app`，bundle ID 为 `com.example.myapp` | ✅ |
| 27 | E5 | 工作区不干净时运行 init | 报错 `commit or stash your changes first` | ✅ |
| 28 | 文档 | 阅读 `AGENTS.md`、`README.md`、`docs/RELEASING.md`、`docs/RECIPES.md` | C5–C9、H4 都有说明；RECIPES 里的 Swift 片段能编译 | ✅ 片段已编译 |

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
| 1 | F3 | `make github-setup` | 回读结果显示只允许 squash、标题取 PR_TITLE；必需检查为 `["Validate PR title","Lint, test, build"]`；workflow 权限 `read`；`release` environment 只允许受保护分支 |
| 2 | Q10 | 按 `docs/RELEASING.md` 第 2 节创建 GitHub App，设置 `RELEASE_APP_CLIENT_ID` 和 `RELEASE_APP_PRIVATE_KEY` | — |
| 3 | F4 | 开一个标题为 `update stuff` 的 PR | `Validate PR title` 失败；改成 `docs: update readme` 后通过 |
| 4 | F1 | 同一个 PR | `Lint, test, build` 在 `macos-26` 上通过，包括冒烟测试（runner 能否启动 GUI 应用是待验证项，失败时看 job 日志里 smoke 那一步） |
| 5 | F2 | 等待 Dependabot 按周运行，或在 Insights → Dependency graph → Dependabot 里手动检查 | PR 标题形如 `chore(deps): bump …` / `ci: bump …` |
| 6 | Q9 | 往 `main` 合并一个 `feat:` PR | release-please 开出 `chore(main): release 0.1.0` PR；该 PR 上两个检查都显示 **skipped**，并且可以合并 |
| 7 | H1 | 合并前：完成本地第 17 项，提交公钥，执行 `gh secret set SPARKLE_ED_PRIVATE_KEY --env release` | — |
| 8 | G5 | 合并发版 PR | 出现 tag `v0.1.0`；Release 中有 CHANGELOG 和 ad-hoc 打开说明；资产包括 `.dmg`、`.dSYM.zip`、`appcast.xml`、`SHA256SUMS`；workflow artifact 中有 `dsym-v0.1.0` |
| 9 | H1 | `curl -sL https://github.com/chengzi-io/macos-swiftui-spm-template/releases/latest/download/appcast.xml` | 显示 0.1.0 的条目 |
| 10 | Q2 | 在另一台 Mac 上下载 DMG 并安装 | 首次被拦截；到「隐私与安全性 → 仍要打开」后可以运行 |
| 11 | H1 | 合并一个 `fix:` PR，再合并它的发版 PR，得到 v0.1.1；在已安装的 0.1.0 中点「Check for Updates…」 | 发现 0.1.1，安装并重启后版本号正确 |
| 12 | H2 | 设置 `vars.HOMEBREW_TAP` 和 `HOMEBREW_TAP_TOKEN` 后再发一个版本 | tap 仓库中出现 `Casks/swiftuitemplate.rb`；`brew audit --cask <tap>/swiftuitemplate` 通过 |

## 3. Apple 证书和账号

| # | 项 | 操作 | 预期 |
|---|----|------|------|
| 1 | G1/G2 | 按 `docs/RELEASING.md` 4b 设置 `TEAM_ID` 和 secrets，然后发一个版本 | `spctl --assess --type execute -vv` 输出 `source=Notarized Developer ID`；`xcrun stapler validate` 对 DMG 通过；`codesign -dv` 显示 `runtime` 和正确的 TeamIdentifier |
| 2 | G2 | 本地：`NOTARY_PROFILE=notary make release` | 两次公证都是 `Accepted`，并完成 staple |
| 3 | Q2 | 已安装的 ad-hoc 版本收到第一个 Developer ID 版本的更新 | 更新成功（**尚未验证**） |
| 4 | G6 | 删掉某个 notary secret 后发版 | publish job 在 `ci-keychain.sh setup` 或公证步骤失败，不会退回 ad-hoc |
| 5 | H3 | `MAS_PROVISIONING_PROFILE=… make release-mas`，然后 `make upload-mas` | 生成 `dist/mas/SwiftUITemplate-X.Y.Z.pkg`；构建出现在 App Store Connect 中 |
