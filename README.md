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
| 代码签名 | Developer ID，已公证 | ad-hoc 签名（未公证），首次打开需右键「打开」 |

自动更新被关闭是有原因的：上游的 appcast 用作者自己的 EdDSA 密钥签名，一旦跟着上游更新，装上的会是被替换回英文版的官方包；而 ad-hoc 签名的 App 也无法通过 Sparkle 的自校验来安装更新。

功能、菜单结构、快捷键、`.comp` 工程格式与上游一致，两种版本的工程文件可以互相打开。

## 安装

从 [Releases](https://github.com/kkwking123/Compositor-CN/releases/latest) 下载 `Compositor-CN-<版本>.dmg`，拖进「应用程序」。

因为安装包没有 Apple 公证，首次启动要在图标上**右键 →「打开」**，在系统对话框里再点「打开」一次；之后双击即可正常启动。

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

## 发布

```sh
./scripts/release-local.sh          # 编译 Release 并打成 dist/Compositor-CN-<版本>.dmg（ad-hoc 签名）
REVISION=1 ./scripts/publish.sh     # 上传到 GitHub Releases，tag 为 v<版本>-cn.1
```

`release-local.sh` 只需要 Xcode，不需要开发者账号，也不需要 `create-dmg`。日后拿到 Developer ID 证书，改用 `TEAM=<团队 ID> ./scripts/release.sh` 走签名加公证，再执行 `publish.sh`。

`publish.sh` 需要 `gh` 已登录。版本号沿用上游的 `MARKETING_VERSION`，本分支的修订号由 `REVISION` 区分，发布记录写进 [CHANGELOG.md](CHANGELOG.md)。

## 给 AI 代理的说明

如果你被要求创建或修改一个 `.comp` 工程，不需要本项目的源码：`.comp` 是一个由若干 PNG 图层加一份 manifest 组成的文件夹，格式与写入规则见 [docs/writing-comp-files.md](docs/writing-comp-files.md)（英文，与上游一致）。

## 许可与致谢

- 代码与文档：[MIT](LICENSE)，原始版权归 Wonder Assembly LLC，本分支自己的改动另有版权声明
- 「Compositor」这一名称与应用图标的权利归原作者，本项目只是按 MIT 许可分发代码的派生版本；MIT 许可本身不授予商标权
- 感谢 [Robbie Tilton](https://github.com/robbietilton) 写出并开源 Compositor

如果上游的改动对中文分支有帮助，也欢迎回到上游去点个 star，或者在那边报告功能问题。
