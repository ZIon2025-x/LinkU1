/**
 * 把任意值序列化为可安全嵌入 <script type="application/ld+json"> 的字符串。
 *
 * `JSON.stringify` 不转义 '<' / '/'，因此用户内容中的 `</script>` 字面值会被 HTML
 * 解析器识别为 script 块结束，提前终止 JSON-LD 块并允许后续 HTML 注入。
 * 这里把 '<'、U+2028、U+2029 编码成 JS 字符串转义序列：JSON 仍然合法，
 * HTML 解析器看不到 '<'。
 *
 * 注意：U+2028 / U+2029 在 JavaScript 中是行终止符，正则字面量必须用
 * \u2028 / \u2029 转义形式书写，否则源码会被解析器截断。
 */
export function stringifyJsonLd(value: unknown, space?: number): string {
  return JSON.stringify(value, null, space)
    .replace(/</g, "\\u003c")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}
