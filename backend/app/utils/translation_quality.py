"""
翻译质量评估工具
评估翻译质量，记录用户反馈
"""
import logging
import re
from typing import Dict, Optional, Tuple

logger = logging.getLogger(__name__)


def assess_translation_quality(
    original_text: str,
    translated_text: str,
    source_lang: str,
    target_lang: str
) -> Dict[str, any]:
    """
    评估翻译质量
    
    参数:
    - original_text: 原始文本
    - translated_text: 翻译后的文本
    - source_lang: 源语言
    - target_lang: 目标语言
    
    返回:
    - 质量评估结果字典
    """
    quality_score = 0.0
    issues = []
    warnings = []
    
    # 1. 长度检查（翻译文本不应该过长或过短）
    original_len = len(original_text)
    translated_len = len(translated_text)
    
    if original_len > 0:
        length_ratio = translated_len / original_len
        
        # 正常范围：0.5 - 2.0（不同语言长度可能不同）
        if length_ratio < 0.3:
            quality_score -= 0.2
            issues.append("翻译文本过短")
        elif length_ratio > 3.0:
            quality_score -= 0.2
            issues.append("翻译文本过长")
        elif 0.5 <= length_ratio <= 2.0:
            quality_score += 0.1
    
    # 2. 空文本检查
    if not translated_text or not translated_text.strip():
        quality_score = 0.0
        issues.append("翻译结果为空")
        return {
            'score': quality_score,
            'issues': issues,
            'warnings': warnings,
            'is_valid': False
        }
    
    # 3. 相同文本检查（可能翻译失败）
    if original_text.strip() == translated_text.strip():
        if source_lang != target_lang:
            quality_score -= 0.3
            warnings.append("翻译结果与原文相同，可能翻译失败")
    
    # 4. 特殊字符检查
    # 检查是否包含大量未翻译的特殊字符或乱码
    non_printable_ratio = sum(1 for c in translated_text if ord(c) < 32 and c not in '\n\r\t') / len(translated_text) if translated_text else 0
    if non_printable_ratio > 0.1:
        quality_score -= 0.2
        issues.append("包含异常字符")
    
    # 5. 编码检查（检查是否有明显的编码错误）
    try:
        translated_text.encode('utf-8')
    except UnicodeEncodeError:
        quality_score -= 0.3
        issues.append("编码错误")
    
    # 6. 基本格式检查
    # 检查标点符号是否合理
    if original_text and translated_text:
        original_punct = len(re.findall(r'[.!?。！？]', original_text))
        translated_punct = len(re.findall(r'[.!?。！？]', translated_text))
        
        if original_punct > 0 and translated_punct == 0:
            warnings.append("翻译结果缺少标点符号")
        elif abs(original_punct - translated_punct) > original_punct * 0.5:
            warnings.append("标点符号数量差异较大")
    
    # 归一化分数到 0-1 范围
    quality_score = max(0.0, min(1.0, 0.5 + quality_score))
    
    return {
        'score': round(quality_score, 2),
        'issues': issues,
        'warnings': warnings,
        'is_valid': quality_score >= 0.3,  # 低于0.3认为无效
        'length_ratio': round(translated_len / original_len, 2) if original_len > 0 else 0
    }


def record_user_feedback(
    translation_id: Optional[int],
    task_id: Optional[int],
    field_type: Optional[str],
    rating: int,  # 1-5
    comment: Optional[str] = None
):
    """
    记录用户反馈
    
    参数:
    - translation_id: 翻译记录ID（可选）
    - task_id: 任务ID（可选）
    - field_type: 字段类型（可选）
    - rating: 评分（1-5）
    - comment: 评论（可选）
    """
    # 这里可以保存到数据库或日志
    # 目前先记录到日志
    logger.info(
        f"翻译质量反馈: translation_id={translation_id}, "
        f"task_id={task_id}, field_type={field_type}, "
        f"rating={rating}, comment={comment}"
    )
    
    # TODO: 可以保存到数据库的 translation_feedback 表
    # 用于后续分析和改进翻译质量


def get_quality_threshold() -> float:
    """获取质量阈值（低于此值的翻译可能需要重新翻译）"""
    return 0.3
