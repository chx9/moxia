/*
 * 墨匣渲染核心：Markdown → 适配微信公众号的内联样式 HTML
 *
 * 流程：解析 front matter → markdown-it 渲染 → DOM 后处理（图片、表格、脚注、代码块、公式）
 *      → 将主题 CSS 逐条内联到元素 style 上（公众号会丢弃 <style> 与 class）
 */
(() => {
  'use strict'

  // ---------- 基础样式：所有主题共享，主题 CSS 在其后叠加 ----------
  const BASE_CSS = `
#moxia { font-size: 16px; line-height: 1.75; color: #333; text-align: left; word-wrap: break-word;
  font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Helvetica Neue", Arial, sans-serif; }
#moxia p { margin: 1em 0; }
#moxia h1, #moxia h2, #moxia h3, #moxia h4, #moxia h5, #moxia h6 { margin: 1.8em 0 0.9em; font-weight: bold; line-height: 1.4; }
#moxia h1 { font-size: 22px; }
#moxia h2 { font-size: 19px; }
#moxia h3 { font-size: 17px; }
#moxia h4, #moxia h5, #moxia h6 { font-size: 16px; }
#moxia ul, #moxia ol { margin: 1em 0; padding-left: 1.6em; }
#moxia li { margin: 0.3em 0; }
#moxia li p { margin: 0.3em 0; }
#moxia strong { font-weight: bold; }
#moxia img { display: block; max-width: 100%; margin: 0 auto; border-radius: 4px; }
#moxia figure { margin: 1.6em 0; text-align: center; }
#moxia figcaption { margin-top: 0.6em; font-size: 13px; line-height: 1.5; color: #999; }
#moxia blockquote { margin: 1.4em 0; padding: 0.6em 1em; border-left: 3px solid #e3e3e3; color: #777; }
#moxia blockquote p { margin: 0.4em 0; }
#moxia hr { height: 1px; margin: 2.4em 0; border: 0; background: #e8e8e8; }
#moxia a { color: var(--accent); text-decoration: none; }
#moxia :not(pre) > code { margin: 0 2px; padding: 2px 5px; border-radius: 4px; font-size: 0.875em;
  font-family: Menlo, Monaco, Consolas, "SF Mono", monospace; color: var(--accent); background: var(--accent-soft); }
#moxia pre { margin: 1.4em 0; padding: 16px; border-radius: 8px; overflow-x: auto; font-size: 13px; line-height: 1.65; }
#moxia pre code { display: block; padding: 0; white-space: nowrap; color: inherit; background: none;
  font-family: Menlo, Monaco, Consolas, "SF Mono", monospace; font-size: inherit; }
#moxia .mac-dots { display: block; margin-bottom: 12px; }
#moxia .table-wrap { margin: 1.4em 0; overflow-x: auto; }
#moxia table { width: 100%; border-collapse: collapse; font-size: 14px; line-height: 1.6; }
#moxia th, #moxia td { padding: 7px 10px; border: 1px solid #e6e6e6; }
#moxia th { font-weight: bold; background: #f7f7f7; }
#moxia .math-block { margin: 1.4em 0; text-align: center; overflow-x: auto; }
#moxia .math-inline svg { vertical-align: middle; }
#moxia .fn-ref { font-size: 12px; color: var(--accent); }
#moxia .footnotes { margin-top: 2.8em; padding-top: 1em; border-top: 1px solid #eee; font-size: 13px; color: #888; }
#moxia .footnotes-title { margin: 0 0 0.6em; font-size: 14px; font-weight: bold; color: #555; }
#moxia .footnote-item { margin: 0.3em 0; line-height: 1.6; word-break: break-all; }
#moxia .footnote-url { color: #aaa; }
#moxia .eyebrow { margin: 0 0 0.6em; font-size: 12px; font-weight: bold; letter-spacing: 2px; color: var(--accent); }
#moxia .brand-footer { margin: 3em 0 0.5em; font-size: 13px; letter-spacing: 2px; text-align: center; color: var(--accent); }
#moxia .callout { margin: 1.4em 0; padding: 0.8em 1em; border-radius: 6px; background: var(--accent-soft); }
#moxia .callout p { margin: 0.4em 0; }
#moxia .callout-title { font-weight: bold; color: var(--accent); }
#moxia .callout-warning, #moxia .callout-caution { background: #fdf2ec; }
#moxia .callout-warning .callout-title, #moxia .callout-caution .callout-title { color: #b4532a; }
#moxia .data-cards { display: flex; flex-wrap: wrap; margin: 1.4em -4px; }
#moxia .data-card { flex: 1 1 0; min-width: 0; margin: 4px; padding: 14px 10px; border-radius: 8px; background: var(--accent-soft); }
#moxia .data-label, #moxia .data-note { margin: 0; font-size: 12px; line-height: 1.5; color: #888; }
#moxia .data-value { margin: 4px 0; font-size: 20px; font-weight: bold; line-height: 1.3; color: var(--accent);
  font-family: "DIN Alternate", "DIN Condensed", Arial, sans-serif; }
#moxia .bar-chart { margin: 1.4em 0; padding: 16px 12px 12px; border-radius: 8px; background: #fafafa; }
#moxia .chart-title { margin: 0 0 12px; font-size: 14px; font-weight: bold; }
#moxia .bar-row { display: flex; align-items: flex-end; }
#moxia .bar-col { flex: 1 1 0; margin: 0 4px; text-align: center; }
#moxia .bar-value { display: block; font-size: 12px; line-height: 1.4; color: #666; }
#moxia .bar { width: 70%; margin: 4px auto 0; border-radius: 4px 4px 0 0; background: var(--accent); }
#moxia .bar-label { display: block; margin-top: 6px; font-size: 12px; line-height: 1.4; color: #888; }
#moxia .chart-note { margin: 10px 0 0; font-size: 12px; color: #999; }
`

  const MAC_DOTS = '<svg class="mac-dots" xmlns="http://www.w3.org/2000/svg" width="52" height="12" viewBox="0 0 52 12">' +
    '<circle cx="6" cy="6" r="5.5" fill="#ff5f57"/><circle cx="26" cy="6" r="5.5" fill="#febc2e"/>' +
    '<circle cx="46" cy="6" r="5.5" fill="#28c840"/></svg>'

  const escapeHTML = (s) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c])

  // ---------- Markdown 解析器 ----------
  const md = window.markdownit({ html: true, linkify: true, breaks: false })

  md.inline.ruler.after('escape', 'math_inline', mathInline)
  md.block.ruler.after('blockquote', 'math_block', mathBlock, { alt: ['paragraph', 'reference', 'blockquote', 'list'] })
  md.renderer.rules.math_inline = (tokens, i) => `<span class="math-inline" data-tex="${escapeHTML(tokens[i].content)}"></span>`
  md.renderer.rules.math_block = (tokens, i) => `<section class="math-block" data-tex="${escapeHTML(tokens[i].content)}"></section>\n`

  md.renderer.rules.fence = (tokens, i) => {
    const token = tokens[i]
    const lang = token.info.trim().split(/\s+/)[0].toLowerCase()
    if (componentFence[lang]) return componentFence[lang](token.content)
    let body
    try {
      if (lang && hljs.getLanguage(lang)) {
        body = hljs.highlight(token.content, { language: lang, ignoreIllegals: true }).value
      } else if (!lang && token.content.trim()) {
        // 未标注语言时自动识别
        body = hljs.highlightAuto(token.content).value
      } else {
        body = escapeHTML(token.content)
      }
    } catch {
      body = escapeHTML(token.content)
    }
    return `<pre class="hljs"><code>${body.replace(/\n$/, '')}</code></pre>\n`
  }

  // ---------- 组件：```cards 数据卡片、```chart 柱状图 ----------
  /** 每行按 | 拆成若干单元格，单元格支持行内 Markdown；以「title:」「note:」开头的行作为标题与注释 */
  function parseRows(content) {
    const meta = {}
    const rows = []
    for (const line of content.split('\n')) {
      if (!line.trim()) continue
      const m = /^(title|note)\s*[:：]\s*(.*)$/i.exec(line.trim())
      if (m) meta[m[1].toLowerCase()] = md.renderInline(m[2])
      else rows.push(line.split('|').map((cell) => md.renderInline(cell.trim())))
    }
    return { meta, rows }
  }

  /** 每行「标签 | 数值 | 说明」 */
  function renderCards(content) {
    const cards = parseRows(content).rows.map(([label = '', value = '', note = '']) =>
      '<section class="data-card">' +
      (label ? `<p class="data-label">${label}</p>` : '') +
      `<p class="data-value">${value}</p>` +
      (note ? `<p class="data-note">${note}</p>` : '') +
      '</section>')
    return `<section class="data-cards">${cards.join('')}</section>\n`
  }

  /** 每行「标签 | 数值」，柱高按最大值等比缩放；数值可带单位，如 12%、¥3,000 */
  function renderChart(content) {
    const { meta, rows } = parseRows(content)
    const numbers = rows.map(([, value = '']) => parseFloat(value.replace(/<[^>]*>|[^\d.-]/g, '')) || 0)
    const max = Math.max(...numbers.map(Math.abs), 1)
    const cols = rows.map(([label = '', value = ''], i) =>
      '<section class="bar-col">' +
      `<span class="bar-value">${value}</span>` +
      `<section class="bar" style="height: ${Math.max(2, Math.round(Math.abs(numbers[i]) / max * 120))}px;"></section>` +
      `<span class="bar-label">${label}</span>` +
      '</section>')
    return '<section class="bar-chart">' +
      (meta.title ? `<p class="chart-title">${meta.title}</p>` : '') +
      `<section class="bar-row">${cols.join('')}</section>` +
      (meta.note ? `<p class="chart-note">${meta.note}</p>` : '') +
      '</section>\n'
  }

  const componentFence = { cards: renderCards, chart: renderChart }

  // 标题文字包一层 span，便于主题做下划线、色块等装饰
  md.renderer.rules.heading_open = (tokens, i) => `<${tokens[i].tag}><span class="title">`
  md.renderer.rules.heading_close = (tokens, i) => `</span></${tokens[i].tag}>\n`

  /** 行内公式 $...$：开头不接空白、结尾不接数字，避免误伤 "$5 和 $10" */
  function mathInline(state, silent) {
    const src = state.src
    const start = state.pos
    if (src[start] !== '$' || src[start + 1] === '$') return false
    if (!src[start + 1] || /\s/.test(src[start + 1])) return false

    let end = start + 1
    while ((end = src.indexOf('$', end)) !== -1 && src[end - 1] === '\\') end++
    if (end === -1 || /\s/.test(src[end - 1]) || /\d/.test(src[end + 1] || '')) return false

    if (!silent) state.push('math_inline', 'math', 0).content = src.slice(start + 1, end)
    state.pos = end + 1
    return true
  }

  /** 块级公式：$$ 开头的行，直到以 $$ 结尾的行 */
  function mathBlock(state, startLine, endLine, silent) {
    const lineText = (n) => state.src.slice(state.bMarks[n] + state.tShift[n], state.eMarks[n])
    if (state.sCount[startLine] - state.blkIndent >= 4) return false
    const first = lineText(startLine)
    if (!first.startsWith('$$')) return false

    const lines = []
    let rest = first.slice(2)
    let line = startLine
    for (;;) {
      const trimmed = rest.trimEnd()
      if (trimmed.endsWith('$$') && !(line === startLine && trimmed.length === 0)) {
        lines.push(trimmed.slice(0, -2))
        break
      }
      lines.push(rest)
      if (++line >= endLine) return false
      rest = lineText(line)
    }
    if (silent) return true

    const token = state.push('math_block', 'math', 0)
    token.block = true
    token.content = lines.join('\n').trim()
    token.map = [startLine, line + 1]
    state.line = line + 1
    return true
  }

  // ---------- front matter ----------
  /** 拆出 front matter，只解析单行的「键: 值」 */
  function splitFrontMatter(src) {
    const m = /^---\r?\n([\s\S]*?)\r?\n---[ \t]*(\r?\n|$)/.exec(src)
    if (!m) return { meta: {}, body: src }
    const meta = {}
    for (const line of m[1].split(/\r?\n/)) {
      const kv = /^([\w-]+)\s*:\s*(.*)$/.exec(line)
      if (kv) meta[kv[1].toLowerCase()] = kv[2].trim().replace(/^(["'])(.*)\1$/, '$2')
    }
    return { meta, body: src.slice(m[0].length) }
  }

  /** front matter 中的 label 显示为文首栏目标签，footer 显示为文末署名 */
  function addFrame(root, meta) {
    if (meta.label) root.insertAdjacentHTML('afterbegin', `<p class="eyebrow">${escapeHTML(meta.label)}</p>`)
    if (meta.footer) root.insertAdjacentHTML('beforeend', `<p class="brand-footer">${escapeHTML(meta.footer)}</p>`)
  }

  // ---------- DOM 后处理 ----------
  const CALLOUT_TITLES = { note: '说明', tip: '提示', important: '重点', warning: '注意', caution: '风险提示' }

  /** GitHub 风格提示框：> [!TIP] 可选标题，换行后接正文 */
  function convertCallouts(root) {
    for (const quote of [...root.querySelectorAll('blockquote')]) {
      const first = quote.firstElementChild
      if (!first || first.tagName !== 'P') continue
      const m = /^\s*\[!(note|tip|important|warning|caution)\][ \t]*([^\n]*)\n?/i.exec(first.innerHTML)
      if (!m) continue
      const type = m[1].toLowerCase()
      const box = document.createElement('section')
      box.className = `callout callout-${type}`
      const rest = first.innerHTML.slice(m[0].length).trim()
      if (rest) first.innerHTML = rest
      else first.remove()
      box.innerHTML = `<p class="callout-title">${m[2].trim() || CALLOUT_TITLES[type]}</p>` + quote.innerHTML
      quote.replaceWith(box)
    }
  }

  function resolveImages(root, baseURL) {
    for (const img of root.querySelectorAll('img')) {
      const src = img.getAttribute('src') || ''
      if (baseURL && src && !/^([a-z][a-z0-9+.-]*:|\/\/)/i.test(src)) {
        try { img.setAttribute('src', new URL(src, baseURL).href) } catch { /* 保持原样 */ }
      }
    }
    // 独占一段的图片转为 figure，alt 作为图注
    for (const p of [...root.querySelectorAll('p')]) {
      const nodes = [...p.childNodes].filter((n) => !(n.nodeType === 3 && !n.textContent.trim()))
      if (nodes.length !== 1 || nodes[0].nodeName !== 'IMG') continue
      const img = nodes[0]
      const figure = document.createElement('figure')
      figure.appendChild(img)
      const caption = img.getAttribute('title') || img.getAttribute('alt')
      if (caption) {
        const fc = document.createElement('figcaption')
        fc.textContent = caption
        figure.appendChild(fc)
      }
      p.replaceWith(figure)
    }
  }

  function wrapTables(root) {
    for (const table of root.querySelectorAll('table')) {
      const wrap = document.createElement('section')
      wrap.className = 'table-wrap'
      table.replaceWith(wrap)
      wrap.appendChild(table)
    }
  }

  /** 公众号只允许公众号文章链接，其余外链转为文末脚注 */
  function linksToFootnotes(root) {
    const notes = []
    for (const a of [...root.querySelectorAll('a[href]')]) {
      const href = a.getAttribute('href')
      if (/^https?:\/\/mp\.weixin\.qq\.com\//.test(href) || href.startsWith('#')) continue
      const span = document.createElement('span')
      span.className = 'link'
      span.innerHTML = a.innerHTML
      a.replaceWith(span)
      if (a.textContent.trim() === href) continue

      let index = notes.findIndex((n) => n.href === href) + 1
      if (!index) index = notes.push({ href, text: a.textContent.trim() })
      const sup = document.createElement('sup')
      sup.className = 'fn-ref'
      sup.textContent = `[${index}]`
      span.after(sup)
    }
    if (!notes.length) return

    const section = document.createElement('section')
    section.className = 'footnotes'
    section.innerHTML = '<p class="footnotes-title">参考链接</p>' + notes.map((n, i) =>
      `<p class="footnote-item">[${i + 1}] ${escapeHTML(n.text)}：<span class="footnote-url">${escapeHTML(n.href)}</span></p>`
    ).join('')
    root.appendChild(section)
  }

  /**
   * 公众号编辑器会折叠代码中的空白，故把空格换成 &nbsp;、换行换成 <br>，
   * 同时保留 highlight.js 生成的 span 结构
   */
  function preserveCodeWhitespace(root, macStyle) {
    for (const code of root.querySelectorAll('pre > code')) {
      const walker = document.createTreeWalker(code, NodeFilter.SHOW_TEXT)
      const texts = []
      while (walker.nextNode()) texts.push(walker.currentNode)
      for (const node of texts) {
        const parts = node.textContent.replace(/\t/g, '    ').replace(/ /g, '\u00a0').split('\n')
        const frag = document.createDocumentFragment()
        parts.forEach((part, i) => {
          if (i > 0) frag.appendChild(document.createElement('br'))
          if (part) frag.appendChild(document.createTextNode(part))
        })
        node.replaceWith(frag)
      }
      if (macStyle) code.insertAdjacentHTML('beforebegin', MAC_DOTS)
    }
  }

  // ---------- 公式：按需加载 MathJax，输出自包含的 SVG ----------
  let mathJaxReady = null
  function loadMathJax() {
    if (mathJaxReady) return mathJaxReady
    window.MathJax = {
      tex: { packages: { '[+]': ['ams'] } },
      svg: { fontCache: 'none' },
      startup: { typeset: false },
    }
    mathJaxReady = new Promise((resolve, reject) => {
      const script = document.createElement('script')
      script.src = 'vendor/tex-svg-full.js'
      script.onload = () => window.MathJax.startup.promise.then(resolve, reject)
      script.onerror = reject
      document.head.appendChild(script)
    })
    return mathJaxReady
  }

  async function renderMath(root) {
    const nodes = root.querySelectorAll('.math-inline, .math-block')
    if (!nodes.length) return
    await loadMathJax()
    for (const node of nodes) {
      const display = node.classList.contains('math-block')
      const container = window.MathJax.tex2svg(node.dataset.tex, { display })
      const svg = container.querySelector('svg')
      if (!svg) continue
      if (display) svg.style.maxWidth = '100%'
      node.replaceChildren(svg)
    }
  }

  // ---------- CSS 内联 ----------
  function mixWithWhite(hex, ratio) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim())
    if (!m) return hex
    const n = parseInt(m[1], 16)
    const ch = (shift) => Math.round(((n >> shift) & 255) * ratio + 255 * (1 - ratio))
    return '#' + [16, 8, 0].map((s) => ch(s).toString(16).padStart(2, '0')).join('')
  }

  function inlineStyles(root, cssText, accentOverride) {
    const sheet = new CSSStyleSheet()
    sheet.replaceSync(cssText)
    const rules = [...sheet.cssRules].filter((r) => r instanceof CSSStyleRule)

    // 收集 :root / #moxia 中声明的 CSS 变量，再派生强调色的浅色版本
    const vars = { '--accent': '#333333' }
    for (const rule of rules) {
      if (!/^(:root|#moxia)$/.test(rule.selectorText.trim())) continue
      for (const prop of rule.style) {
        if (prop.startsWith('--')) vars[prop] = rule.style.getPropertyValue(prop).trim()
      }
    }
    if (accentOverride) {
      vars['--accent'] = accentOverride
      delete vars['--accent-soft']
      delete vars['--accent-light']
    }
    vars['--accent-soft'] ??= mixWithWhite(vars['--accent'], 0.08)
    vars['--accent-light'] ??= mixWithWhite(vars['--accent'], 0.2)

    const resolve = (text) => text
      .replace(/--[\w-]+\s*:[^;]*;?/g, '')
      .replace(/var\(\s*(--[\w-]+)\s*(?:,\s*([^)]+))?\)/g, (_, name, fallback) => vars[name] ?? fallback ?? '')
      .trim()

    const styles = new Map()
    for (const rule of rules) {
      if (rule.selectorText.includes('::')) continue
      const decl = resolve(rule.style.cssText)
      if (!decl) continue
      let elements
      try {
        elements = [...root.querySelectorAll(rule.selectorText)]
        if (root.matches(rule.selectorText)) elements.unshift(root)
      } catch {
        continue
      }
      for (const el of elements) styles.set(el, (styles.get(el) || '') + decl + ' ')
    }
    for (const [el, decl] of styles) {
      el.setAttribute('style', decl + (el.getAttribute('style') || ''))
      // 交给浏览器重新序列化：同名属性只保留最后生效的一条
      el.setAttribute('style', el.style.cssText)
    }
  }

  function cleanAttributes(root) {
    for (const el of [root, ...root.querySelectorAll('*')]) {
      el.removeAttribute('class')
      el.removeAttribute('id')
      for (const attr of [...el.attributes]) {
        if (attr.name.startsWith('data-')) el.removeAttribute(attr.name)
      }
    }
  }

  // ---------- 复制输出：本地图片替换为占位框 ----------
  const isLocalImage = (img) => !/^(https?:|data:)/i.test(img.getAttribute('src') || '')

  /** 公众号无法读取本机图片，复制时换成醒目的占位框，方便在公众号编辑器中逐一补图 */
  function withImagePlaceholders(root) {
    const clone = root.cloneNode(true)
    const images = [...clone.querySelectorAll('img')].filter(isLocalImage)
    for (const img of images) {
      let name = (img.getAttribute('src') || '').split(/[\\/]/).pop()
      try { name = decodeURIComponent(name) } catch { /* 保持原样 */ }
      const box = document.createElement('section')
      box.setAttribute('style', 'margin: 0.6em 0; padding: 26px 16px; border: 1px dashed #c9c9c9; border-radius: 6px; ' +
        'background: #fafafa; text-align: center; line-height: 1.6;')
      box.innerHTML =
        '<p style="margin: 0; font-size: 14px; color: #888; letter-spacing: 1px;">图片待上传</p>' +
        `<p style="margin: 4px 0 0; font-size: 12px; color: #b0b0b0; word-break: break-all;">${escapeHTML(name)}</p>`
      img.replaceWith(box)
    }
    return { html: clone.outerHTML, count: images.length }
  }

  // ---------- 对外接口（供 Swift 调用） ----------
  const stage = document.getElementById('stage')
  let renderSeq = 0
  let output = { html: '', text: '' }

  async function render(options) {
    const seq = ++renderSeq
    const root = document.createElement('section')
    root.id = 'moxia'
    const { meta, body } = splitFrontMatter(options.markdown || '')
    root.innerHTML = md.render(body)
    addFrame(root, meta)
    convertCallouts(root)

    resolveImages(root, options.baseURL)
    wrapTables(root)
    if (options.footnotes) linksToFootnotes(root)
    preserveCodeWhitespace(root, options.macStyle)
    try {
      await renderMath(root)
    } catch (err) {
      console.error('MathJax 加载失败', err)
    }
    if (seq !== renderSeq) return false

    inlineStyles(root, BASE_CSS + (options.themeCSS || '') + (options.codeCSS || '') + (options.overrideCSS || ''), options.accent)
    cleanAttributes(root)

    stage.replaceChildren(root)
    const exported = withImagePlaceholders(root)
    output = { html: exported.html, text: root.innerText, localImages: exported.count }
    return true
  }

  function scrollTo(ratio) {
    const scroller = document.getElementById('scroller')
    scroller.scrollTop = Math.max(0, (scroller.scrollHeight - scroller.clientHeight) * ratio)
  }

  window.moxia = { render, scrollTo, getOutput: () => output }
})()
