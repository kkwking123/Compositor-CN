# 同步上游更新

本仓库是上游的快照 + 中文化改动。上游每次发版，按这个流程把改动合进来。

## 一次性准备

仓库里应有两个 remote：

```sh
git remote -v
# origin    https://github.com/kkwking123/Compositor-CN.git   ← 自己的仓库
# upstream  https://github.com/robbietilton/Compositor.git    ← 原作者的仓库
```

如果 `upstream` 缺了：

```sh
git remote add upstream https://github.com/robbietilton/Compositor.git
```

如果克隆下来只有一个 commit（`git log` 里显示 `grafted`），说明是浅克隆，先把历史补全，否则没法跟上游比对：

```sh
git fetch --unshallow upstream
```

打开冲突记忆，同样的冲突第二次出现时会自动套用上次的解法：

```sh
git config rerere.enabled true
```

## 每次同步

```sh
git switch main
git fetch upstream --tags
git merge upstream/main
```

合并而不是 rebase：中文化是本地提交，rebase 会把它们全部重写一遍，冲突要重复解决。

如果只想先看看上游动了什么：

```sh
git log --oneline HEAD..upstream/main        # 上游领先的提交
git diff --stat HEAD..upstream/main          # 哪些文件会被改动
```

## 解决冲突

冲突集中在**被中文化改过字面量的文件**里（`Compositor/UI/` 与 `Compositor/Document/` 下的那几十个）。原则：

1. **代码逻辑一律取上游**。不要为了保中文而留下被上游改掉或删掉的逻辑。
2. **只保留 `"…".localized` 这一层包装**。上游的 `Button("Save")` 若被改成 `Button("Save As")`，结果应是 `Button("Save As")`（SwiftUI 直接查表），而不是把旧的 `"Save".localized` 塞回去。
3. **新增的英文字面量不要顺手翻译**。先合干净、编译通过，再单独用一个 PR 补翻译。
4. 每个文件解决完先看一眼 `git diff`，确认没有整块逻辑被中文注释或旧版本覆盖回去。

冲突太多、状态乱了，随时可以放弃这次合并重来：

```sh
git merge --abort
```

## 合并后的检查单

按顺序做完再提交，缺一步都可能把编译不过的东西推上去。

1. 编译

   ```sh
   xcodebuild -project Compositor.xcodeproj -scheme Compositor \
     -configuration Debug -derivedDataPath DerivedData \
     CODE_SIGN_IDENTITY=- build
   ```

2. 测试

   ```sh
   xcodebuild -project Compositor.xcodeproj -scheme Compositor \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- test -only-testing:CompositorTests
   ```

3. 翻译检查

   ```sh
   perl l10n/check_coverage.pl Compositor Compositor/zh-Hans.lproj/Localizable.strings
   perl l10n/check_placeholders.pl
   ```

   覆盖度检查会列出上游新加的、还没翻译的键；占位符检查不通过必须修，那是会崩的。

4. 本地过一遍界面：切到简体中文，看上游新功能所在的菜单和面板有没有漏译、文字被截断。

5. 更新记录

   - `CHANGELOG.md` 的 `Unreleased` 下记一条
   - 上游改了 `docs/project-format.md` 的格式版本时，本仓库对应文件与 `ProjectManifest.current` 一起看，别只合一半

6. 提交并推送

   ```sh
   git commit -am "Merge upstream vX.Y.Z"
   git push origin main
   ```

   提交信息里写清对应的上游 tag，方便以后回溯。

## 需要一直守住的几条

- **不要把中文化的改动推给上游**。作者明确表示暂不接受本地化 PR，见 [README](https://github.com/robbietilton/Compositor#translations)。
- **不要合掉本分支的身份设置**：`PRODUCT_BUNDLE_IDENTIFIER = com.kkwking.compositor.cn`、`DEVELOPMENT_TEAM = ""`、`Config/Info.plist` 里关掉自动更新的注释。这三处一旦被上游的值覆盖，中文版会被官方更新顶掉，或者装不上。
- 上游新增或修改的 Swift Package 依赖可以照合；本分支已经把 Sparkle 移除，如果上游改了 Sparkle 的用法，忽略即可。

## 自动化

`.github/workflows/upstream-watch.yml` 每周检查一次上游有没有新提交，有就开一个 Issue 提醒，不会自动改代码 —— 中文化的冲突没法可靠地自动解决，自动合并只会把问题藏起来。
