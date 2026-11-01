# 参与贡献

感谢你对墨匣的兴趣。无论是报告问题、改进主题、补充文档，还是提交代码，都有帮助。

参与本项目即表示你同意遵守基本的开源协作礼仪：就事论事、尊重不同经验水平的贡献者、不发布他人的隐私信息。

## 报告问题

提交 Issue 前，请先搜索现有 Issue，避免重复。

一个好的 bug 报告通常包含：

- macOS 版本与芯片架构（如 macOS 14.5，Apple Silicon）
- 墨匣的版本或 commit（可在应用包的 `Info.plist` 或仓库提交记录中查看）
- 复现步骤：做了什么、看到了什么、期望看到什么
- 最小可复现的 Markdown 片段
- 截图或录屏，尤其是预览与公众号后台的对比
- 如果是运行时崩溃，附上控制台日志：

  ```bash
  log show --last 5m --predicate 'process == "Moxia"' --style compact
  ```

涉及安全或隐私的问题请不要公开提交 Issue，先通过仓库主页列出的联系方式私下联系维护者。

## 开发环境

- macOS 14 Sonoma 或更高版本
- Xcode 15.3+（Swift 5.10+ 工具链）
- 无需安装第三方 Swift 依赖

常用命令：

```bash
swift build                     # Debug 构建
swift run                       # 直接运行
./scripts/build-app.sh          # 打包 build/Moxia.app（Release）
./scripts/build-app.sh debug    # 打包 Debug 版本
```

开发模式下，渲染资源会优先从 `Sources/Moxia/Resources/Renderer` 读取，因此修改主题 CSS 后无需重新编译。修改 Swift 代码仍需重新构建。

## 代码结构

| 位置 | 职责 |
| --- | --- |
| `Sources/Moxia/AppState.swift` | 文档、设置、渲染调度、草稿、剪贴板 |
| `Sources/Moxia/MarkdownEditor.swift` | `NSTextView` 编辑器、语法高亮、图片粘贴 |
| `Sources/Moxia/EditorActions.swift` | 插入与格式操作、右键菜单 |
| `Sources/Moxia/PreviewController.swift` | `WKWebView` 与 Swift ↔ JS 桥 |
| `Sources/Moxia/ThemeLibrary.swift` | 内置主题、自定义主题、代码主题 |
| `Sources/Moxia/SettingsView.swift` | 快速设置与完整设置窗口 |
| `Examples/welcome.md` | 首次启动的示例文章 |
| `Sources/Moxia/Resources/Renderer/moxia.js` | 渲染核心与 CSS 内联 |
| `Sources/Moxia/Resources/Renderer/themes/` | 文章主题 |
| `Sources/Moxia/Resources/Renderer/code/` | 代码高亮主题 |

渲染逻辑刻意集中在 `moxia.js` 中，Swift 侧只负责调度与原生交互。改动渲染行为时，请先判断它属于哪一层。

## 代码约定

- 使用 4 个空格缩进，保持与现有代码一致。
- UI 文案与注释使用中文；标识符使用英文。
- UI 状态集中在 `AppState`（`@MainActor` + `@Observable`），避免在视图中散落可变状态。
- 不引入第三方 Swift 依赖。前端依赖以文件形式放在 `vendor/`，并同步更新 `ThirdPartyLicenses/`。
- 不重排、不格式化与本次改动无关的代码，保持 PR 聚焦。
- 新增或修改渲染逻辑时，要考虑微信公众号的 HTML 过滤规则，并在公众号后台实际验证复制结果。
- 新增主题时，选择器以 `#moxia` 开头，声明 `--accent`，避免依赖伪元素与 `@media`。
- 提交前至少执行一次 `./scripts/build-app.sh`，确保打包流程可完成。

## 提交 Pull Request

1. Fork 仓库并从 `main` 创建分支，分支名建议使用 `fix/…`、`feat/…`、`theme/…`、`docs/…` 前缀。
2. 完成改动，必要时补充测试或示例 Markdown。
3. 构建并手动验证：输入文字、切换主题、复制到公众号、检查图片占位与公式。
4. 提交 PR，说明：
   - 改了什么、为什么改；
   - 对用户可见的变化；
   - 如何验证；
   - UI 变化请附截图或录屏。
5. 提交信息简洁描述改动即可，例如 `修复表格在窄窗口下的横向滚动` 或 `新增「青瓷」主题`。

PR 可能会被要求补充测试或调整实现；讨论时请保持耐心。

## 贡献主题

主题是最容易参与的部分：

1. 在 `Sources/Moxia/Resources/Renderer/themes/` 新建 CSS，或在应用的主题文件夹中试写。
2. 遵循 README 中[编写主题](README.md#编写主题)的规则。
3. 如果要成为内置主题，请同时修改 `ThemeLibrary.swift` 中的 `builtInThemes`。
4. 在 PR 中附上至少一张预览截图，并说明适合的文章类型。

请确保主题所使用的字体、颜色与素材可以合法分发，且不依赖本机特有的字体文件。

## 贡献文档

文档改动同样需要验证：

- 命令与路径必须能在当前仓库中实际执行或找到；
- 功能描述以代码行为为准，不要描述尚未实现的功能；
- 中文排版遵循仓库现有风格：中英文之间加空格，使用全角标点。

## 测试清单

提交前建议手动检查：

- [ ] `swift build` 与 `./scripts/build-app.sh` 均成功
- [ ] 新建、打开、保存、另存为 `.md` 正常
- [ ] 编辑区与预览区滚动同步
- [ ] 8 套主题与 7 套代码配色切换正常
- [ ] 提示框、数据卡片、柱状图、公式、表格显示正常
- [ ] 复制到公众号后，样式、代码空白、脚注与图片占位符合预期
- [ ] 深浅色外观下界面可读
- [ ] 修改自定义主题后预览自动刷新

## 许可证

贡献的代码、主题与文档将以本项目的 [MIT License](LICENSE) 发布。
