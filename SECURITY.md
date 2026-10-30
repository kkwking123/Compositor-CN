# 安全策略

## 报告漏洞

请通过 [GitHub 的私密漏洞报告](https://github.com/kkwking123/Compositor-CN/security/advisories/new) 提交，不要直接开公开 Issue。

如果上游代码本身就有该漏洞，也请同步报给[上游仓库](https://github.com/robbietilton/Compositor)，那才是根本修复的地方。

报告中请包含：受影响的版本、复现步骤、影响范围（如崩溃、越权读写文件、任意代码执行）、以及你能提供的样例文件。

## 范围说明

本项目是未公证的 ad-hoc 签名构建，用户可以自行从源码编译。因此：

- 「安装包没有 Apple 公证」不是漏洞，是已知限制，见 [README](README.md#安装)
- 已关闭的自动更新不会去拉取任何远程 feed，也没有可用于投毒的更新通道
- 从 Releases 下载的 DMG 与本仓库源码的对应关系以 Release 说明里的提交号为准；自行编译可以获得同等的可验证性

## 支持的版本

只维护最新的发布版本。旧版本的问题如果在新版本里仍然存在，请在新版本上复现后报告。
