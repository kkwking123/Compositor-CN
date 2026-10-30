# 参与贡献

这是一个简体中文分支，欢迎这几类贡献：修漏译和错译、修中文界面下的排版与崩溃、把上游的新功能同步过来时补齐翻译。功能本身的实现请先跟上游对齐，除非它和中文显示有关。

## 反馈问题

- **中文分支的问题**（漏译、错译、中文下文字被截断、切换语言后异常）→ 开到[本仓库的 Issues](https://github.com/kkwking123/Compositor-CN/issues)
- **上游就有的功能问题、崩溃、性能问题** → 报到[上游仓库](https://github.com/robbietilton/Compositor/issues)，那边才有人能修

报告时请带上：版本号（「关于」或 Release 页）、macOS 版本、芯片型号、复现步骤、截图。漏译的话请写清楚在哪个面板、哪个菜单里。

**请不要把中文化的改动提给上游。** 上游维护者在 [README](https://github.com/robbietilton/Compositor#translations) 里说明了暂不接受本地化 PR，重复提过去只会给别人添麻烦。

## 改界面文案

界面文字有两类，处理方式不同：

1. **源码里的字面量**。SwiftUI 的 `Text("…")`、`Button("…")` 会自己查表，只要字面量和 `.strings` 里的键一致即可。这类不用改代码。
2. **运行期才有的字符串**，比如混合模式名、AppKit 菜单项、拼接出来的标题。它们要靠 `"…".localized` 显式查表。

加一条新翻译的步骤：

1. 在 `Compositor/zh-Hans.lproj/Localizable.strings` 里按字母序加一条
2. 键必须和源码里的英文字面量**逐字一致**，包括标点和省略号（`…` 是 U+2026，不是三个点）
3. 占位符必须与英文一致：`%@`、`%1$@`、`%d`、`%%` 都一样，顺序和类型不能改
4. 同一个词在两处含义不同时，用 `localized(context:)` 加语境键，格式为 `"语境: 原文"`

`Compositor/en.lproj/Localizable.strings` 只在需要固定英文措辞时才有条目，一般情况下英文回落到源码字面量，不必加。

### 维护用的检查脚本

`l10n/` 下是纯 Perl/zsh 脚本，不依赖 Xcode：

```sh
# 代码里要用的键，表里有没有（漏译）
perl l10n/check_coverage.pl Compositor Compositor/zh-Hans.lproj/Localizable.strings

# 键与译文的占位符是否一致（错一个就能崩），默认就读 zh-Hans 表
perl l10n/check_placeholders.pl

# 准备加一批新键前，看看哪些已经有了（避免重复）
perl l10n/check_new_keys.pl
```

`check_coverage.pl` 也会把运行期拼出来的字符串（插值、单个符号）列成 missing，那些查不到是正常的，看的是列表里有没有整句的英文。

提交前请至少跑前两个，CI 也会跑。

## 代码约定

- 跟随周围代码的风格：命名、注释密度、idiom 都保持一致
- 注释和标识符用美式拼写（color、gray、center），界面文案的英文同理
- 中文注释只在解释中文特有问题时使用；与上游共享的代码保持英文注释，减少同步冲突
- 不要把中文硬编码进 Swift 源码，所有界面文字都走 `.strings`
- 枚举的 `rawValue` 不要改动，它同时是工程文件里的存档格式和菜单键

## 构建与测试

见 [README 的构建一节](README.md#从源码编译)。提交前请保证：

```sh
xcodebuild -project Compositor.xcodeproj -scheme Compositor \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- test -only-testing:CompositorTests
```

跑通。改动涉及界面文案时，另外手工启动一次，在「语言」菜单里切到简体中文看一遍相关面板。

## 提交信息

- 第一行是祈使句，说清做了什么改动，句尾不加句号
- 涉及多个方面时，正文分条列出
- 中文或英文都可以，同一个 PR 内保持一致

## 许可

提交的代码按 [MIT](LICENSE) 授权，与上游一致。
