"""
双语字段自动填充辅助函数
用于在创建板块和排行榜时，自动检测语言并翻译到对应的双语字段
"""
import logging
import re
from typing import Optional, Tuple

logger = logging.getLogger(__name__)


def detect_language_simple(text: str) -> str:
    """
    简单检测文本语言（中文或英文）
    返回: 'zh' 或 'en'
    """
    if not text or not text.strip():
        return 'en'  # 默认为英文
    
    # 检查是否包含中文字符
    chinese_pattern = re.compile(r'[\u4e00-\u9fff]+')
    if chinese_pattern.search(text):
        return 'zh'
    
    # 默认为英文
    return 'en'


async def auto_fill_bilingual_fields(
    name: str,
    description: Optional[str] = None,
    name_en: Optional[str] = None,
    name_zh: Optional[str] = None,
    description_en: Optional[str] = None,
    description_zh: Optional[str] = None,
) -> Tuple[str, Optional[str], Optional[str], Optional[str], Optional[str]]:
    """
    自动填充双语字段
    
    逻辑：
    1. 如果用户已经填写了双语字段，使用用户填写的值
    2. 如果用户只填写了name/description，自动检测语言并翻译到对应的双语字段
    
    返回: (name, name_en, name_zh, description_en, description_zh)
    """
    from app.translation_manager import get_translation_manager
    from app.utils.translation_async import translate_async
    
    # 处理名称
    detected_lang = detect_language_simple(name)
    
    # 如果用户已经填写了双语字段，优先使用用户填写的值
    if detected_lang == 'zh':
        # 用户填写的是中文
        if not name_zh:
            name_zh = name  # 使用原文本作为中文
        if not name_en:
            # 需要翻译成英文
            try:
                translation_manager = get_translation_manager()
                name_en = await translate_async(
                    translation_manager,
                    text=name,
                    target_lang='en',
                    source_lang='zh-CN',
                    max_retries=2
                )
                if not name_en:
                    logger.warning(f"翻译名称失败: {name}")
                    name_en = None
            except Exception as e:
                logger.warning(f"翻译名称时出错: {e}")
                name_en = None
    else:
        # 用户填写的是英文
        if not name_en:
            name_en = name  # 使用原文本作为英文
        if not name_zh:
            # 需要翻译成中文
            try:
                translation_manager = get_translation_manager()
                name_zh = await translate_async(
                    translation_manager,
                    text=name,
                    target_lang='zh-CN',
                    source_lang='en',
                    max_retries=2
                )
                if not name_zh:
                    logger.warning(f"翻译名称失败: {name}")
                    name_zh = None
            except Exception as e:
                logger.warning(f"翻译名称时出错: {e}")
                name_zh = None
    
    # 处理描述
    if description:
        detected_desc_lang = detect_language_simple(description)
        
        if detected_desc_lang == 'zh':
            # 用户填写的是中文
            if not description_zh:
                description_zh = description  # 使用原文本作为中文
            if not description_en:
                # 需要翻译成英文
                try:
                    translation_manager = get_translation_manager()
                    description_en = await translate_async(
                        translation_manager,
                        text=description,
                        target_lang='en',
                        source_lang='zh-CN',
                        max_retries=2
                    )
                    if not description_en:
                        logger.warning(f"翻译描述失败: {description[:50]}...")
                        description_en = None
                except Exception as e:
                    logger.warning(f"翻译描述时出错: {e}")
                    description_en = None
        else:
            # 用户填写的是英文
            if not description_en:
                description_en = description  # 使用原文本作为英文
            if not description_zh:
                # 需要翻译成中文
                try:
                    translation_manager = get_translation_manager()
                    description_zh = await translate_async(
                        translation_manager,
                        text=description,
                        target_lang='zh-CN',
                        source_lang='en',
                        max_retries=2
                    )
                    if not description_zh:
                        logger.warning(f"翻译描述失败: {description[:50]}...")
                        description_zh = None
                except Exception as e:
                    logger.warning(f"翻译描述时出错: {e}")
                    description_zh = None
    
    return (name, name_en, name_zh, description_en, description_zh)
