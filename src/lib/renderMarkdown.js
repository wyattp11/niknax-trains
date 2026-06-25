// Minimal, dependency-free Markdown -> HTML renderer.
// Scoped to what the rules/criteria content actually uses: headings (#-###),
// horizontal rules (---), bold/italic, links, and (possibly nested) bulleted
// or numbered lists. Not a general-purpose Markdown engine — intentionally
// small so we don't need a new npm dependency just to render admin-authored
// rules text.

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

// Safe-ish link href: only allow http(s) links through, everything else
// becomes plain text so this never produces a javascript: URL etc.
function safeHref(url) {
  try {
    const parsed = new URL(url, 'https://example.com')
    if (parsed.protocol === 'http:' || parsed.protocol === 'https:') return url
  } catch {}
  return null
}

function renderInline(text) {
  let out = escapeHtml(text)

  // Links: [label](url)
  out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (match, label, url) => {
    const href = safeHref(url)
    if (!href) return label
    return `<a href="${href}" target="_blank" rel="noopener">${label}</a>`
  })

  // Bold: **text**
  out = out.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')

  // Italic: *text* (single asterisks not already consumed by bold above)
  out = out.replace(/\*([^*]+)\*/g, '<em>$1</em>')

  return out
}

export function renderMarkdown(md) {
  const lines = String(md || '').replace(/\r\n/g, '\n').split('\n')
  const htmlParts = []
  let i = 0
  let paragraphBuf = []

  function flushParagraph() {
    if (paragraphBuf.length) {
      htmlParts.push(`<p>${renderInline(paragraphBuf.join(' '))}</p>`)
      paragraphBuf = []
    }
  }

  while (i < lines.length) {
    const rawLine = lines[i]
    const line = rawLine.trim()

    if (line === '') {
      flushParagraph()
      i++
      continue
    }

    if (/^---+$/.test(line)) {
      flushParagraph()
      htmlParts.push('<hr />')
      i++
      continue
    }

    const headingMatch = line.match(/^(#{1,6})\s+(.*)$/)
    if (headingMatch) {
      flushParagraph()
      const level = headingMatch[1].length
      htmlParts.push(`<h${level}>${renderInline(headingMatch[2])}</h${level}>`)
      i++
      continue
    }

    // Bulleted list (supports one level of nested sub-bullets via 2+ space indent)
    if (/^[-*]\s+/.test(line)) {
      flushParagraph()
      const items = []
      while (i < lines.length && /^[-*]\s+/.test(lines[i].trim()) ) {
        const itemText = lines[i].trim().replace(/^[-*]\s+/, '')
        const subItems = []
        i++
        while (i < lines.length && /^\s{2,}[-*]\s+/.test(lines[i])) {
          subItems.push(lines[i].trim().replace(/^[-*]\s+/, ''))
          i++
        }
        items.push({ text: itemText, subItems })
      }
      htmlParts.push('<ul>')
      for (const item of items) {
        htmlParts.push(`<li>${renderInline(item.text)}`)
        if (item.subItems.length) {
          htmlParts.push('<ul>')
          for (const sub of item.subItems) {
            htmlParts.push(`<li>${renderInline(sub)}</li>`)
          }
          htmlParts.push('</ul>')
        }
        htmlParts.push('</li>')
      }
      htmlParts.push('</ul>')
      continue
    }

    // Numbered list
    if (/^\d+\.\s+/.test(line)) {
      flushParagraph()
      htmlParts.push('<ol>')
      while (i < lines.length && /^\d+\.\s+/.test(lines[i].trim())) {
        htmlParts.push(`<li>${renderInline(lines[i].trim().replace(/^\d+\.\s+/, ''))}</li>`)
        i++
      }
      htmlParts.push('</ol>')
      continue
    }

    // Otherwise: part of a paragraph
    paragraphBuf.push(line)
    i++
  }

  flushParagraph()
  return htmlParts.join('\n')
}
