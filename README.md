# Compositor 简体中文版

**本项目是 [Compositor](https://github.com/robbietilton/Compositor) 的非官方简体中文分支，与原作者 [Robbie Tilton](https://github.com/robbietilton)（Wonder Assembly LLC）无关，也未获得其背书或支持。**

代码来自上游，按 MIT 许可使用；界面中文化由本仓库维护。上游目前不接受本地化 PR，所以中文相关的改动只在本仓库进行，请不要拿这里的改动去向原作者提交 PR。上游的问题请报给上游仓库，中文分支的问题（漏译、错译、中文界面下的排版或崩溃）请报给[本仓库的 Issues](https://github.com/kkwking123/Compositor-CN/issues)。

Compositor 是一款用于合成与照片后期的 macOS 图像编辑器，用 Swift 编写（SwiftUI 与 AppKit，部分像素处理用 C）。层、蒙版、调整层、图层效果、变换、选区、画笔与修复、Camera Raw、PSD/PSB 导入、动图 GIF、导出与通道打包等，功能与原版一致。

## 与上游的差异

| 项目 | 上游 | 本分支 |
| --- | --- | --- |
| 界面语言 | 仅英文 | 英文 + 简体中文，可在「语言」菜单里切换，重启后生效 |
| 应用名称 | Compositor | Compositor-CN，与官方版同时安装时能分辨 |
| Bundle ID | `com.wonderassembly.compositor` | `com.kkwking.compositor.cn`（可与官方版同时安装） |
| 自动更新 | Sparkle，从上游 appcast 更新 | 已关闭，从本仓库 Releases 下载新版本 |
| 代码签名 | Developer ID，已公证 | ad-hoc 签名（未公证） |
| 安装包 | DMG | PKG 与 DMG 两种，见下 |

自动更新被关闭是有原因的：上游的 appcast 用作者自己的 EdDSA 密钥签名，一旦跟着上游更新，装上的会是被替换回英文版的官方包；而 ad-hoc 签名的 App 也无法通过 Sparkle 的自校验来安装更新。

功能、菜单结构、快捷键、`.comp` 工程格式与上游一致，两种版本的工程文件可以互相打开。

## 安装

从 [Releases](https://github.com/kkwking123/Compositor-CN/releases/latest) 下载 `Compositor-CN-<版本>.pkg`，双击装进「应用程序」。装完直接双击图标就能打开。

PKG 里的安装脚本会以 root 身份清掉 App 上的 `com.apple.quarantine`（以及新系统上的 `com.apple.provenance`）属性。没有这两个属性，Gatekeeper 就不会拦下未公证的 App——不装 PKG 的话，其他电脑首次打开要在图标上**右键 →「打开」**，在系统对话框里再点一次「打开」，也可以自己在终端执行：

```sh
xattr -dr com.apple.quarantine "/Applications/Compositor CN.app"
```

想自己拖进「应用程序」的，下载 `Compositor-CN-<版本>.dmg`，只是首次启动要多一次右键「打开」（或上面那条命令）。PKG 和 DMG 里的 App 完全一样，包本身同样没有公证，所以从浏览器下载后第一次打开 PKG 也需要右键「打开」一次。

系统要求：

- macOS 26.0 或更高，Apple 芯片的 Mac
- 从源码编译需要 Xcode 26 或更高

## 从源码编译

```sh
git clone https://github.com/kkwking123/Compositor-CN.git
cd Compositor-CN
open Compositor.xcodeproj
```

在 Xcode 里运行 **Compositor** scheme 即可，不需要 Apple 开发者账号：工程不设置开发团队，走「Sign to Run Locally」。

命令行构建：

```sh
xcodebuild -project Compositor.xcodeproj -scheme Compositor \
  -configuration Debug -derivedDataPath DerivedData \
  CODE_SIGN_IDENTITY=- build
```

产物在 `DerivedData/Build/Products/Debug/Compositor.app`。

跑测试：

```sh
xcodebuild -project Compositor.xcodeproj -scheme Compositor \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- test -only-testing:CompositorTests
```

## 中文化

- 界面文案走 `"…".localized`，落到 `Compositor/en.lproj/Localizable.strings` 与 `Compositor/zh-Hans.lproj/Localizable.strings`
- 语言在 App 内切换，通过写入本 App 自己的 `AppleLanguages` 实现，不影响系统设置（`Compositor/AppLanguage.swift`）
- `l10n/` 是维护用的 Perl 脚本，检查键的覆盖、占位符一致性和新增字面量，详见 [CONTRIBUTING.md](CONTRIBUTING.md)

## 同步上游

本仓库跟踪上游，`upstream` remote 指向原作者的仓库：

```sh
git fetch upstream
git merge upstream/main
```

冲突通常落在中文化改过字面量的那些文件里。解决方案与注意事项见 [docs/syncing-with-upstream.md](docs/syncing-with-upstream.md)。

## 同步到 GitHub

`scripts/auto-sync.sh` 是同步脚本：先看工作区有没有改动，有就先编译，**编译通过才**提交并推送；没有改动就直接退出，不会留下空提交。手动跑一次：

```sh
./scripts/auto-sync.sh
```

定时执行在这个仓库上暂时做不到，卡点不在脚本，在 macOS 的隐私机制：工程放在外置卷上，而 `launchd` 拉起的进程读不到外置卷，连 `ls` 都返回 `Operation not permitted`。`scripts/launchd/` 留了一份 plist 模板，等仓库搬到启动卷（例如 `~/Projects/`）后可以直接用；另一条路是给 `/bin/sh` 开「完全磁盘访问」，那等于让机器上所有脚本都能读全盘，不划算。

所以这里的节奏是两条：改完代码当场推送，以及需要周期性兜底时用 Qoder 的定时任务排一次。推送走 SSH，`~/.ssh` 里那把密钥加到 GitHub 账号即可，私钥不需要密码短语；`upstream` 只读，脚本不会向它推任何东西。

## 发布

```sh
./scripts/release-local.sh          # 编译 Release，打成 dist/Compositor-CN-<版本>.pkg 与同名的 .dmg（ad-hoc 签名）
REVISION=1 ./scripts/publish.sh     # 两个包一起上传到 GitHub Releases，tag 为 v<版本>-cn.1
```

`release-local.sh` 只需要 Xcode，不需要开发者账号，也不需要 `create-dmg`。包内的 `scripts/pkg/postinstall` 是 PKG 能直接打开的关键，它只改安装到的那个盘上的 App，不回去动启动盘上的副本。只想出 PKG 的话，拿一个已经编好的 `.app` 直接跑 `./scripts/make-pkg.sh <app> <文件名> <版本> <输出.pkg>`。日后拿到 Developer ID 证书，改用 `TEAM=<团队 ID> ./scripts/release.sh` 走签名加公证（那条路下两个包都会被公证），再执行 `publish.sh`。

`publish.sh` 需要 `gh` 命令行工具（`brew install gh`）。没装也能发：跑完 `release-local.sh`，在仓库的 Releases → Draft a new release 里手动填 tag `v<版本>-cn.<修订号>`，把 `dist/` 里的 PKG 和 DMG 拖上去即可，效果相同。版本号沿用上游的 `MARKETING_VERSION`，本分支的修订号由 `REVISION` 区分，发布记录写进 [CHANGELOG.md](CHANGELOG.md)。

## 给 AI 代理的说明

如果你被要求创建或修改一个 `.comp` 工程，不需要本项目的源码：`.comp` 是一个由若干 PNG 图层加一份 manifest 组成的文件夹，格式与写入规则见 [docs/writing-comp-files.md](docs/writing-comp-files.md)（英文，与上游一致）。

## 许可与致谢

- 代码与文档：[MIT](LICENSE)，原始版权归 Wonder Assembly LLC，本分支自己的改动另有版权声明
- 「Compositor」这一名称与应用图标的权利归原作者，本项目只是按 MIT 许可分发代码的派生版本；MIT 许可本身不授予商标权
- 感谢 [Robbie Tilton](https://github.com/robbietilton) 写出并开源 Compositor

如果上游的改动对中文分支有帮助，也欢迎回到上游去点个 star，或者在那边报告功能问题。
