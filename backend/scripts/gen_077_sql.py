"""
从 frontend/src/locales/zh.json 与 en.json 生成法律文档种子迁移 SQL。
用法（在项目根目录）：
  python -m backend.scripts.gen_077_sql           # 生成 077
  python -m backend.scripts.gen_077_sql 078     # 生成 078（077 被跳过时用 078 补齐）
  或
  cd backend && python scripts/gen_077_sql.py [078]
"""
import json
import sys
from pathlib import Path

backend_dir = Path(__file__).resolve().parent.parent
project_root = backend_dir.parent
frontend_locales = project_root / "frontend" / "src" / "locales"
zh_path = frontend_locales / "zh.json"
en_path = frontend_locales / "en.json"
# 支持 077 或 078（077 被跳过时用 078 补齐）
MIGRATION_NUM = (sys.argv[1] if len(sys.argv) > 1 else "077").strip()
if MIGRATION_NUM not in ("077", "078"):
    MIGRATION_NUM = "077"
out_sql = backend_dir / "migrations" / f"{MIGRATION_NUM}_seed_legal_documents_full.sql"

LEGAL_KEYS = ("privacyPolicy", "termsOfService", "cookiePolicy")
TYPE_LANG = [
    ("privacy", "zh"), ("terms", "zh"), ("cookie", "zh"),
    ("privacy", "en"), ("terms", "en"), ("cookie", "en"),
]
KEY_BY_TYPE = {"privacy": "privacyPolicy", "terms": "termsOfService", "cookie": "cookiePolicy"}


def load(path: Path) -> dict:
    if not path.exists():
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    zh = load(zh_path)
    en = load(en_path)
    if not zh and not en:
        print("错误：未找到 zh.json 或 en.json", file=sys.stderr)
        return 1

    lines = [
        f"-- 迁移 {MIGRATION_NUM}：将前端 locale 中的隐私政策、用户协议、Cookie 政策全文写入 legal_documents",
        "-- 依赖：须先执行 076_add_legal_documents.sql（建表并插入 6 条占位行）",
        "-- 由脚本根据 frontend/src/locales/zh.json 与 en.json 生成；重复执行仅覆盖 content_json，幂等",
        "",
    ]

    for doc_type, lang in TYPE_LANG:
        data = zh if lang == "zh" else en
        key = KEY_BY_TYPE[doc_type]
        content = data.get(key) if data else None
        if not content or not isinstance(content, dict):
            print(f"跳过 {doc_type} / {lang}：无内容或非对象", file=sys.stderr)
            continue
        json_str = json.dumps(content, ensure_ascii=False, separators=(",", ":"))
        tag = f"LEGAL{MIGRATION_NUM}_{doc_type}_{lang}"
        line = f"UPDATE legal_documents SET content_json = ${tag}${json_str}${tag}$::jsonb, version = 'v1.0' WHERE type = '{doc_type}' AND lang = '{lang}';"
        lines.append(line)

    out_sql.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"已写入 {out_sql}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
