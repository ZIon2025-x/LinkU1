"""
从前端 locale 文件导入法律文档内容到 legal_documents 表。
运行前请确保已执行迁移 076_add_legal_documents.sql。
用法（在项目根目录或 backend 目录）：
  python -m backend.scripts.seed_legal_from_locales
  或
  cd backend && python scripts/seed_legal_from_locales.py
"""

import json
import sys
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(backend_dir))

# 前端 locale 目录（相对于 backend/scripts）
frontend_locales = backend_dir.parent / "frontend" / "src" / "locales"
zh_path = frontend_locales / "zh.json"
en_path = frontend_locales / "en.json"

LEGAL_KEYS = ("privacyPolicy", "termsOfService", "cookiePolicy")
TYPE_MAP = {"privacyPolicy": "privacy", "termsOfService": "terms", "cookiePolicy": "cookie"}


def load_locale(path: Path) -> dict:
    if not path.exists():
        return {}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def main():
    zh_data = load_locale(zh_path)
    en_data = load_locale(en_path)
    if not zh_data and not en_data:
        print("错误：未找到 zh.json 或 en.json，请确认路径：", frontend_locales)
        return 1

    from app.database import SessionLocal
    from app import models

    db = SessionLocal()
    updated = 0
    try:
        for lang, data in (("zh", zh_data), ("en", en_data)):
            if not data:
                continue
            for key in LEGAL_KEYS:
                content = data.get(key)
                if not content or not isinstance(content, dict):
                    print(f"跳过 {lang} / {key}：无内容或非对象")
                    continue
                doc_type = TYPE_MAP[key]
                row = (
                    db.query(models.LegalDocument)
                    .filter(models.LegalDocument.type == doc_type, models.LegalDocument.lang == lang)
                    .first()
                )
                if row:
                    row.content_json = content
                    row.version = row.version or "v1.0"
                    db.commit()
                    print(f"✓ 更新：{doc_type} / {lang}")
                else:
                    db.add(
                        models.LegalDocument(
                            type=doc_type,
                            lang=lang,
                            content_json=content,
                            version="v1.0",
                        )
                    )
                    db.commit()
                    print(f"✓ 插入：{doc_type} / {lang}")
                updated += 1
        print(f"\n完成，共处理 {updated} 条法律文档。")
        return 0
    except Exception as e:
        db.rollback()
        print("错误：", e)
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    sys.exit(main())
