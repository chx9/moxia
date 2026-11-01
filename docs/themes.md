# 主题与自定义

[← 返回 README](../README.md)

## 内置主题

| 主题 | 风格 | 适合 |
| --- | --- | --- |
| 墨韵 | 宋体衬线、朱砂点缀 | 人文随笔 |
| 素笺 | 克制、留白 | 大多数文章 |
| 晴空 | 明快的蓝 | 技术与产品 |
| 拾光 | 暖橙荧光笔 | 生活与读书笔记 |
| 格律 | 瑞士网格、黑白配红 | 设计与评论 |
| 焦糖 | 奶油白、深棕、焦糖 | 咖啡、美食与生活 |
| 时评 | 黑白报刊版式、中国红 | 财经、时评与政策解读 |
| 森屿 | 森林绿、奶油白、焦糖金 | 品牌与生活方式文章 |

默认主题为「墨韵」。主题只决定排版与配色，不改变 Markdown 内容。

## 使用自定义主题

1. 打开「设置 → 全部设置 → 通用」。
2. 点击「打开」主题文件夹，放入一个 `.css` 文件。
3. 回到设置窗口点击「重新载入」，或切换到其他应用再切回来，新主题会出现在标题栏的主题菜单中，无需重启。

在外部编辑当前正在使用的主题 CSS 时，文件监听会自动触发预览刷新。

## 编写主题

公众号会丢弃 `<style>` 与 class，墨匣会把主题 CSS 逐条内联到元素上。因此主题需要遵循几条规则：

- **选择器以 `#moxia` 开头**，例如 `#moxia h2`、`#moxia h2 .title`（标题文字包在 `span.title` 中）。
- **规则按书写顺序覆盖，不计算选择器优先级**。后写的规则会覆盖前面的同名属性。
- **伪元素不会生效**（如 `::before`、`::after`）。
- **`@media`、`@font-face` 等 at-rule 不会生效**，内联阶段只处理普通样式规则。
- **不依赖伪类交互**：`#moxia a:hover` 之类的规则不会在静态文章里产生效果。
- 可用变量：`var(--accent)`、`var(--accent-soft)`、`var(--accent-light)`。在 `#moxia { --accent: #xxxxxx; }` 中声明默认值；未声明时，浅色版本会由强调色与白色混合自动生成。
- 建议只使用公众号编辑器能够保留的属性：字体、字号、颜色、背景、边框、圆角、内外边距、行高、字间距、文本对齐等。

一个最小示例：

```css
/* 我的主题：青瓷 */
#moxia {
  --accent: #2f6f5e;
  font-family: "Songti SC", "Noto Serif SC", serif;
  font-size: 16px;
  line-height: 1.9;
  letter-spacing: 0.4px;
  padding: 24px 20px;
  background: #fbfaf6;
}

#moxia h2 .title {
  padding-left: 10px;
  border-left: 3px solid var(--accent);
}

#moxia strong {
  color: var(--accent);
}

#moxia blockquote {
  border-left: 3px solid var(--accent-light);
  background: var(--accent-soft);
}
```

内置主题位于 `Sources/Moxia/Resources/Renderer/themes/`，可以作为更完整的参考。

## 添加到内置主题列表

如果要让主题成为所有用户都能看到的默认主题：

1. 把 `your-theme.css` 放进 `Sources/Moxia/Resources/Renderer/themes/`。
2. 在 `Sources/Moxia/ThemeLibrary.swift` 的 `builtInThemes` 中加入 `("your-theme", "主题名")`。
3. 重新构建。

代码高亮主题同理：CSS 放进 `Sources/Moxia/Resources/Renderer/code/`，再在 `ThemeLibrary.codeThemes` 中登记。

## 贡献主题

1. 在 `Sources/Moxia/Resources/Renderer/themes/` 新建 CSS，或在应用的主题文件夹中试写。
2. 遵循上面的编写规则。
3. 如果要成为内置主题，请同时修改 `ThemeLibrary.swift` 中的 `builtInThemes`。
4. 在 PR 中附上至少一张预览截图，并说明适合的文章类型。

请确保主题所使用的字体、颜色与素材可以合法分发，且不依赖本机特有的字体文件。

---

[← 返回 README](../README.md) · [使用指南](guide.md) · [工作原理与开发](development.md) · [常见问题与限制](faq.md)
