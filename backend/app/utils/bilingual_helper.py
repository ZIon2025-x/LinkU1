"""
双语字段自动填充辅助函数
用于在创建板块和排行榜时，自动检测语言并翻译到对应的双语字段
"""
import logging
import re
import html
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

# 编码标记占位符（用于翻译时保护编码标记）
_ENCODE_PLACEHOLDER_NEWLINE = "___FORUM_NEWLINE_PLACEHOLDER___"
_ENCODE_PLACEHOLDER_SPACE = "___FORUM_SPACE_PLACEHOLDER___"


def _protect_encoding_markers(text: str) -> Tuple[str, bool]:
    """
    保护编码标记，在翻译前替换为占位符
    
    返回: (处理后的文本, 是否包含编码标记)
    """
    has_encoding = False
    result = text
    
    # 检测并保护编码标记
    if '\\n' in text:
        has_encoding = True
        result = result.replace('\\n', _ENCODE_PLACEHOLDER_NEWLINE)
    
    if '\\c' in text:
        has_encoding = True
        result = result.replace('\\c', _ENCODE_PLACEHOLDER_SPACE)
    
    return result, has_encoding


def _restore_encoding_markers(text: str) -> str:
    """
    恢复编码标记，将占位符替换回编码标记
    同时清理 HTML 实体编码（如 &#39; -> '）
    """
    if not text:
        return text
    
    # 先清理 HTML 实体编码
    result = html.unescape(text)
    
    # 恢复编码标记
    result = result.replace(_ENCODE_PLACEHOLDER_NEWLINE, '\\n')
    result = result.replace(_ENCODE_PLACEHOLDER_SPACE, '\\c')
    
    return result


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
                    # 保护编码标记
                    protected_name, has_encoding = _protect_encoding_markers(name)
                    name_en = await translate_async(
                        translation_manager,
                        text=protected_name,
                        target_lang='en',
                        source_lang='zh-CN',
                        max_retries=2
                    )
                    if name_en:
                        # 恢复编码标记并清理 HTML 实体
                        name_en = _restore_encoding_markers(name_en)
                    else:
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
                    # 保护编码标记
                    protected_name, has_encoding = _protect_encoding_markers(name)
                    name_zh = await translate_async(
                        translation_manager,
                        text=protected_name,
                        target_lang='zh-CN',
                        source_lang='en',
                        max_retries=2
                    )
                    if name_zh:
                        # 恢复编码标记并清理 HTML 实体
                        name_zh = _restore_encoding_markers(name_zh)
                    else:
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
                    # 保护编码标记
                    protected_description, has_encoding = _protect_encoding_markers(description)
                    description_en = await translate_async(
                        translation_manager,
                        text=protected_description,
                        target_lang='en',
                        source_lang='zh-CN',
                        max_retries=2
                    )
                    if description_en:
                        # 恢复编码标记并清理 HTML 实体
                        description_en = _restore_encoding_markers(description_en)
                    else:
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
                    # 保护编码标记
                    protected_description, has_encoding = _protect_encoding_markers(description)
                    description_zh = await translate_async(
                        translation_manager,
                        text=protected_description,
                        target_lang='zh-CN',
                        source_lang='en',
                        max_retries=2
                    )
                    if description_zh:
                        # 恢复编码标记并清理 HTML 实体
                        description_zh = _restore_encoding_markers(description_zh)
                    else:
                        logger.warning(f"翻译描述失败: {description[:50]}...")
                        description_zh = None
                except Exception as e:
                    logger.warning(f"翻译描述时出错: {e}")
                    description_zh = None
    
    return (name, name_en, name_zh, description_en, description_zh)
