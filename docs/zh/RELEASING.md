# 发版

怎么把应用的一个版本发出去，给跑发版、验收构建的人看。不用读代码；每条命令都在仓库根目录
执行。

一次**发版**是 GitHub Releases 页面上的一个 DMG，加上已安装的副本会读的更新源，也就是
**appcast**。一个**草稿** Release 只有你看得见：它还没有 tag，Releases 页面显示的还是上一个
版本，在你发布之前，谁都不会被提示更新。

## 一次发版是怎么跑的

| 步骤 | 谁 | 做什么 | 检查什么 |
| --- | --- | --- | --- |
| 1 | 你或者你的 agent | 写 PR 标题，`feat: …` 或 `fix: …` | 你懂这个标题，因为用户会把它当发版说明的一行读；它遵循 Conventional Commits（[CONTRIBUTING](../../.github/CONTRIBUTING.md)），其他类型什么都不发 |
| 2 | 你 | 合并 PR；它的标题变成 `main` 上的 commit | CI 是绿的 |
| 3 | 你 | Actions → **Release** → **Run workflow**，分支选 `main`，`version` 留空 | 或者在终端里：`gh workflow run release.yml` |
| 4 | CI | 构建、签名并检查应用，然后留下一个草稿，里面有 DMG、dSYM zip、`appcast.xml` 和 `SHA256SUMS` | 这次运行是绿的，它的 summary 里有草稿的链接 |
| 5 | 你 | 从草稿的资产里下载 DMG 并验收 | 下面的检查单全部通过 |
| 6 | 你 | 点 **Publish release** | tag `vX.Y.Z` 出现，已安装的副本被提示更新 |

**被拒的草稿**——第 5 步发现了 bug，或者说明你不想这么发——用一个 `fix:` PR 再跑一次就
解决：新的运行会删掉草稿，用同一个版本号重新构建，再留下一个新草稿。草稿没有 tag，所以没有
任何东西挡着它。

如果自上一个版本以来只有 `chore:`、`docs:`、`ci:` 这类 commit，运行会在第一步失败，报
"nothing to release since vX.Y.Z"。这不是出了问题：这些 commit 什么都不发，等 `main` 上有了
`feat` 或 `fix` 再跑。

## 版本号

下一个版本号来自自上一个版本以来的 Conventional Commit 标题：

| 自上一个版本以来的 commit | 版本 |
| --- | --- |
| 有一个 `feat` | 次版本号：1.4.2 → 1.5.0 |
| 有一个 `fix` | 修订号：1.4.2 → 1.4.3 |
| 1.0 之前的破坏性变更 | 次版本号：0.4.2 → 0.5.0 |
| 只有 `docs`、`chore`、`ci`、`refactor`、`test` … | 什么都不发；运行就此停下 |
| 还没有，第一次发版 | `0.1.0` |

第 3 步的 `version` 输入接受你手写的 `X.Y.Z`，并覆盖那个数字：除非你要发一个特定版本，否则
留空；它必须比上一个高，而且不能是已经存在的 tag。

`CFBundleVersion` 是 `main` 上的 commit 数，Sparkle 比的就是它：它只增不减，所以已安装的
副本总能看见更新的构建。Dependabot 以 `fix(deps)` 提安全更新，它们随下一次发版出去。

Releases 页面就是 changelog：每个 Release 的说明就是它那一节，没有 `CHANGELOG.md` 要编辑。

## 首次发版之前

每个应用做一次。`make status` 会说还差什么：`todo releases` 那行列出缺的步骤，`ok releases`
表示第一次发版可以跑了。

1. **`make github-settings`** 创建 GitHub 环境 `release`，并把它限制到受保护的分支，所以只有
   从 `main` 起的运行能读到它的 secret。
2. **`make sparkle-key`** 创建 Sparkle key——签每一次更新的 key，所以已安装的副本只接受来自
   这个应用的更新——放进你的登录钥匙串，并把它的公钥写进 `App/Configs/Info.plist` 的
   `SUPublicEDKey`。提交那个文件。
3. **把私钥那一半导出**到文件。`<bundle id>` 是 `App/Configs/Identity.xcconfig` 里的
   `BUNDLE_ID`；`make sparkle-key` 会带着它把这个命令打印出来：

   ```bash
   ./.build/artifacts/sparkle/Sparkle/bin/generate_keys --account <bundle id> -x sparkle-private-key
   ```

4. **离线备份那个文件**，放进密码管理器或 U 盘，再往下走。交给 GitHub 的那份不算备份：
   secret 写得进去，读不出来，也下载不了。
5. **把它存成 secret**：`release` 环境里的 `SPARKLE_ED_PRIVATE_KEY`，然后删掉文件；key 还在
   你的登录钥匙串和离线备份里：

   ```bash
   gh secret set SPARKLE_ED_PRIVATE_KEY --env release < sparkle-private-key
   rm sparkle-private-key
   ```

6. **换新 Mac 时**恢复备份；千万不要在那上面新建 key，因为新 key 对 Sparkle 来说是另一个
   应用，已安装的副本会拒绝每一次更新。`App/Configs/Info.plist` 里已经有一个这台 Mac 没有
   的 key 时，`make sparkle-key` 会拒绝执行，并指向 `RESTORE`：

   ```bash
   make sparkle-key RESTORE=<file>
   ```

### Ad-hoc 还是 Developer ID

Ad-hoc 构建免费，也是默认：第一次启动时 macOS 会拒绝这个应用，发版说明会告诉用户在系统设置
→ 隐私与安全性里点 **Open Anyway**；更新之后，某些权限可能还要再授权一次。

有 Apple Developer Program 会员的话，在 `App/Configs/Identity.xcconfig` 里设 `TEAM_ID`，并
把这五个 secret 存进 `release` 环境；构建就用 Developer ID 签名，并对 DMG 公证。

| Secret | 装什么 |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | 你的 Developer ID Application 证书和它的私钥，base64 编码的 `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | 导出那个 `.p12` 时用的密码 |
| `NOTARY_API_KEY_P8_BASE64` | 你的 App Store Connect API key，base64 编码的 `.p8` |
| `NOTARY_API_KEY_ID` | 那个 key 的 ID |
| `NOTARY_API_ISSUER_ID` | 你的 App Store Connect issuer ID |

## 验收草稿

在草稿上做这些，而且要在发布之前：一发布就等于发给所有人了。

1. 在 Releases 页面上从草稿的资产里下载 DMG（运行的 summary 里有草稿的链接），然后打开它。
2. 把应用拷到一个干净的地方，`/Applications` 或者一个新文件夹，再启动它。ad-hoc 构建第一次
   需要点 **Open Anyway**（系统设置 → 隐私与安全性）。
3. 打开应用的 Settings：窗口打开，里面的 **Check for Updates…** 有回应。
4. 逐条走一遍发版说明：每处改动都像它说的那样工作。
5. 退出，再启动一次；没有东西被第二次询问。
6. 点 **Publish release**：它在构建时的那个 commit 上创建 tag `vX.Y.Z`，这个 Release 成为
   最新的一个。

然后测更新本身：装上上一个版本，打开它，Settings 里的 **Check for
Updates…** 会提示新版本并原地安装。

## 出问题的时候

| 你看到什么 | 怎么办 |
| --- | --- |
| 运行在第一步失败，卡在某个 secret 或 key 上 | 报错会点出缺的是什么；补上它（[首次发版之前](#首次发版之前)） |
| 运行在别的地方失败 | 修掉它点出的问题，然后 **Re-run failed jobs**：外部原因（网络、runner、公证服务）会恢复，重跑会替换草稿 |
| DMG 没过检查单 | 合并一个 `fix:` PR，再跑一次 workflow |
| 发出去的版本是坏的 | 把上一个 Release 标成 **Latest**，然后发一个 `fix:` |

把上一个 Release 标成 **Latest**（编辑那个 Release，然后 **Set as the latest
release**）会让 `releases/latest/download/appcast.xml` 供上一个 appcast，于是 Sparkle 在修复
版出来之前不再提示这个坏掉的更新。发出去的 tag 永远不动、也不删除：已安装的副本和链接都指
着它。

## 给崩溃报告做符号化

每个 Release 都带自己的 dSYM zip，`<App>-X.Y.Z.dSYM.zip`，运行还会把它留成 artifact
`dsym-v<version>`，保留 90 天。崩溃报告里是一堆地址；dSYM 把地址还原成函数名：

```bash
atos -o <App>.app.dSYM/Contents/Resources/DWARF/<App> -arch arm64 -l <load address> <address>
```

`<App>` 是应用的名字，即 `App/Configs/Identity.xcconfig` 里的 `APP_NAME`。开源仓库里 dSYM
可以公开；闭源应用的话，把它从 `scripts/release/draft.sh` 上传的资产里去掉，改读 artifact。

## Beta 渠道

没接：beta 需要自己的 appcast 渠道，就像 [Sparkle 的
channels](https://sparkle-project.org/documentation/publishing/#channels) 里写的那样，而模板
只发稳定源。
