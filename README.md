# 墨匣 Moxia

> 为微信公众号而生的 Markdown 排版工具。左侧书写，右侧即见成稿；一次复制，直接粘贴到公众号后台。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

**Moxia** is a native macOS Markdown editor for WeChat Official Accounts. Write on the left, preview the publish-ready layout on the right, then copy once and paste into the WeChat editor. Themes, code highlighting, math and footnotes are preserved.

It is local-first: no account, no cloud, no telemetry. Rendering happens entirely on your Mac.

![墨匣界面：左侧编辑示例文章，右侧以「拾光」主题实时预览公众号排版](docs/screenshot.png)

> 当前为 0.1.0 早期版本，主题格式与设置项可能调整。

## 为什么是墨匣

公众号编辑器不是浏览器：它会丢弃 `<style>` 与 class、过滤外链、折叠代码空白，也读不到本机图片。墨匣在复制前把主题样式逐条内联、把外链收进文末脚注、保留代码空白，并把公式渲染为 SVG，因此粘进去的排版更接近预览。

## 功能

- **8 套文章主题**、8 组强调色、7 套代码高亮配色，代码块可选 Mac 窗口装饰
- **公众号适配**：CSS 内联、外链转脚注、代码空白保留、本地图片占位、公式转 SVG
- **增强组件**：GitHub 风格提示框、数据卡片、柱状图
- **写作体验**：分栏实时预览、滚动同步、字数统计、自动保存草稿、粘贴或拖入图片、标题栏重命名
- **本地优先**：渲染与数据都在本机，无账号、无云端、无统计

## 快速开始

需要 macOS 14+、Xcode 15.3+（Swift 5.10+）。没有第三方 Swift 依赖。

```bash
git clone https://github.com/chx9/moxia.git
cd moxia
./scripts/build-app.sh
open build/Moxia.app
```

首次启动会载入 `Examples/welcome.md`，直接删改即可开始写作。调试构建用 `./scripts/build-app.sh debug`，开发时也可以 `swift run`。

安装到「应用程序」：

```bash
cp -R build/Moxia.app /Applications/
```

应用使用 ad-hoc 签名，未做 Apple 公证。如果被 Gatekeeper 拦截，右键选择「打开」，或执行：

```bash
xattr -dr com.apple.quarantine /Applications/Moxia.app
```

## 文档

| 文档 | 内容 |
| --- | --- |
| [使用指南](docs/guide.md) | 基本流程、Markdown 语法、front matter、提示框、卡片、图表、图片、快捷键、复制原理与数据位置 |
| [主题与自定义](docs/themes.md) | 8 套内置主题、自定义主题、编写规则、内置主题贡献方式 |
| [工作原理与开发](docs/development.md) | 架构、项目结构、构建命令、资源热更新、示例文章与测试 |
| [常见问题与限制](docs/faq.md) | 已知限制、复制与排版问题排查 |
| [参与贡献](CONTRIBUTING.md) | 开发环境、代码约定、提交 PR 与测试清单 |

更多实现细节以代码为准；文档中的命令均可在仓库根目录执行。

## 参与贡献

欢迎提交 Issue 与 Pull Request。报告排版问题时，请附上最小可复现的 Markdown、macOS 版本与截图；新增主题时请附预览图与适用场景。提交前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目以 [MIT License](LICENSE) 发布，Copyright © 2026 Moxia Contributors。

第三方组件及其许可证见 [ThirdPartyLicenses/](ThirdPartyLicenses/)：[markdown-it](https://github.com/markdown-it/markdown-it)（MIT）、[highlight.js](https://github.com/highlightjs/highlight.js)（BSD 3-Clause）、[MathJax](https://www.mathjax.org/)（Apache-2.0）。

## 致谢

感谢上述开源项目的作者与维护者。文章主题、应用图标与界面均在本项目中原创实现。
