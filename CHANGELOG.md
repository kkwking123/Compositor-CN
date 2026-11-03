# 更新日志

本分支的版本号形如 `<上游版本>-cn.<修订号>`，例如 `1.5.12-cn.1` 表示基于上游 v1.5.12 的第一个中文修订。上游的功能变化记在上游的 Release 里，这里只记中文分支自己的改动。

## [Unreleased]

### 新增

- `scripts/make-pkg.sh`：把编好的 `.app` 封成 PKG 安装包，装到「应用程序」
- `scripts/pkg/postinstall`：安装时以 root 身份清掉 App 上的 `com.apple.quarantine`（以及新系统的 `com.apple.provenance`），其他电脑装完双击就能打开，不必再右键「打开」或手动跑 `xattr`
- `release-local.sh` 与 `release.sh` 在 DMG 之外同时产出 PKG，`publish.sh` 把两个包一起发到 Releases

### 变更

- README 的安装说明改为推荐 PKG，DMG 作为手动拖拽的另一种选择保留

## [1.5.12-cn.1] - 2026-10-30

基于上游 [v1.5.12](https://github.com/robbietilton/Compositor/releases/tag/v1.5.12)。

### 新增

- 简体中文界面，可在「语言」菜单里与英文切换，重启后生效
- `AppLanguage.swift`：写入本 App 自己的 `AppleLanguages`，不改动系统语言设置
- `l10n/`：覆盖度、占位符、新增键的检查脚本，以及若干一次性改写工具

### 变更

- Bundle ID 改为 `com.kkwking.compositor.cn`，可与官方英文版同时安装
- 关闭 Sparkle 自动更新：上游 appcast 用作者的 EdDSA 密钥签名，跟随更新会把中文版换成英文原版，且 ad-hoc 签名的包无法通过 Sparkle 自校验
- 移除 Sparkle 依赖，工程不再需要解析任何 Swift Package
- 清空工程里的开发团队设置，本地构建走「Sign to Run Locally」，不再需要 Apple 开发者账号
- 重写 README，声明这是非官方中文分支，并说明与上游的差异

### 修复

- `ProjectTab.displayTitle` 用了不存在的 `String.stripPrefix`，改为 `hasPrefix` + `dropFirst`，修复编译失败
- LICENSE 保留原作者版权声明，并补上本分支的版权行

---

## 与上游的关系

上游版本号与本仓库不同步递增。每次同步上游后，在「Unreleased」下记录，发版时再归档成 `-cn.N`。
