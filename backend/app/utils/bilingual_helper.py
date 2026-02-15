"""
双语字段自动填充辅助函数
用于在创建板块和排行榜时，自动检测语言并翻译到对应的双语字段
"""
import logging
import re
import html
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

# 编码标记占位符（使用 HTML 标签，多数翻译服务会保留标签不翻译）
_ENCODE_PLACEHOLDER_NEWLINE = "<br/>"   # 换行，翻译后替换回 \n
_ENCODE_PLACEHOLDER_SPACE = "<sp/>"     # 空格，翻译后替换回 \c


def _protect_encoding_markers(text: str) -> Tuple[str, bool]:
    """
    保护编码标记，在翻译前替换为 HTML 标签占位符
    多数翻译 API 会保留 HTML 标签，从而保留换行与空格
    
    返回: (处理后的文本, 是否包含编码标记)
    """
    has_encoding = False
    result = text
    
    if '\\n' in text:
        has_encoding = True
        result = result.replace('\\n', _ENCODE_PLACEHOLDER_NEWLINE)
    
    if '\\c' in text:
        has_encoding = True
        result = result.replace('\\c', _ENCODE_PLACEHOLDER_SPACE)
    
    return result, has_encoding


async def _translate_with_encoding_protection(
    translation_manager,
    text: str,
    target_lang: str,
    source_lang: str,
    max_retries: int = 2
) -> Optional[str]:
    """
    带编码标记保护的翻译函数
    如果占位符方法失败，使用分段翻译策略
    """
    from app.utils.translation_async import translate_async
    
    # 方法1：使用占位符保护（优先）
    protected_text, has_encoding = _protect_encoding_markers(text)
    translated = await translate_async(
        translation_manager,
        text=protected_text,
        target_lang=target_lang,
        source_lang=source_lang,
        max_retries=max_retries
    )
    
    if translated:
        restored = _restore_encoding_markers(translated)
        # 检查占位符是否成功恢复
        if has_encoding and ('\\n' in restored or '\\c' in restored):
            # 占位符成功恢复，返回结果
            return restored
        elif has_encoding:
            # 占位符丢失，使用分段翻译策略
            logger.debug("占位符在翻译中丢失，使用分段翻译策略")
            return await _translate_segmented(
                translation_manager,
                text,
                target_lang,
                source_lang,
                max_retries
            )
        else:
            # 没有编码标记，直接返回
            return restored
    
    return None


async def _translate_segmented(
    translation_manager,
    text: str,
    target_lang: str,
    source_lang: str,
    max_retries: int = 2
) -> Optional[str]:
    """
    分段翻译策略：在编码标记处分割，分别翻译每段，然后重新组合
    """
    from app.utils.translation_async import translate_async
    
    # 按编码标记分割文本
    # 使用正则表达式匹配 \n 和 \c，保留分隔符
    import re
    parts = re.split(r'(\\n+|\\c+)', text)
    
    if len(parts) == 1:
        # 没有编码标记，直接翻译
        return await translate_async(
            translation_manager,
            text=text,
            target_lang=target_lang,
            source_lang=source_lang,
            max_retries=max_retries
        )
    
    # 分段翻译
    translated_parts = []
    for i, part in enumerate(parts):
        if part.startswith('\\'):
            # 这是编码标记，直接保留
            translated_parts.append(part)
        else:
            # 这是文本内容，需要翻译
            if part.strip():  # 只翻译非空部分
                translated = await translate_async(
                    translation_manager,
                    text=part,
                    target_lang=target_lang,
                    source_lang=source_lang,
                    max_retries=max_retries
                )
                if translated:
                    # 清理 HTML 实体编码
                    translated = html.unescape(translated)
                    translated_parts.append(translated)
                else:
                    # 翻译失败，保留原文
                    translated_parts.append(part)
            else:
                # 空部分直接保留
                translated_parts.append(part)
    
    return ''.join(translated_parts)


def _restore_encoding_markers(text: str) -> str:
    """
    恢复编码标记，将 HTML 标签占位符替换回 \\n 和 \\c
    同时清理 HTML 实体编码（如 &#39; -> '）
    """
    if not text:
        return text
    
    # 先清理 HTML 实体编码
    result = html.unescape(text)
    
    # 恢复换行：<br/>、<br>、<br /> 等变体均替换为 \n
    result = re.sub(r'<br\s*/?>', '\\n', result, flags=re.IGNORECASE)
    # 恢复空格：<sp/> 替换为 \c
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
                    # 使用带编码保护的翻译函数
                    name_en = await _translate_with_encoding_protection(
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
                    # 使用带编码保护的翻译函数
                    name_zh = await _translate_with_encoding_protection(
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
                    # 使用带编码保护的翻译函数
                    description_en = await _translate_with_encoding_protection(
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
                    # 使用带编码保护的翻译函数
                    description_zh = await _translate_with_encoding_protection(
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
