"""
数据匿名化模块
用于保护用户隐私，对敏感数据进行匿名化处理
"""

import logging
import hashlib
from typing import Dict, Any, Optional
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models import UserTaskInteraction, RecommendationFeedback
from app.crud import get_utc_time

logger = logging.getLogger(__name__)


class DataAnonymizer:
    """数据匿名化器"""
    
    @staticmethod
    def anonymize_user_id(user_id: str, salt: Optional[str] = None) -> str:
        """
        匿名化用户ID
        
        Args:
            user_id: 原始用户ID
            salt: 盐值（可选，用于增强安全性）
        
        Returns:
            匿名化的用户ID（哈希值）
        """
        if not user_id:
            return ""
        
        # 使用SHA256哈希
        hash_input = user_id
        if salt:
            hash_input = f"{user_id}:{salt}"
        
        return hashlib.sha256(hash_input.encode()).hexdigest()[:16]
    
    @staticmethod
    def anonymize_device_info(device_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        匿名化设备信息
        
        保留设备类型、操作系统类型等统计信息
        移除或模糊化具体版本号等可识别信息
        """
        if not device_info:
            return {}
        
        anonymized = {}
        
        # 保留设备类型（用于统计分析）
        if "type" in device_info:
            anonymized["type"] = device_info["type"]
        
        # 保留操作系统类型，但模糊化版本号
        if "os" in device_info:
            anonymized["os"] = device_info["os"]
            # 版本号只保留主版本号（如 17.0 -> 17.x）
            if "os_version" in device_info:
                version = device_info["os_version"]
                try:
                    major_version = version.split(".")[0]
                    anonymized["os_version"] = f"{major_version}.x"
                except:
                    anonymized["os_version"] = "unknown"
        
        # 保留浏览器类型，但模糊化版本号
        if "browser" in device_info:
            anonymized["browser"] = device_info["browser"]
            if "browser_version" in device_info:
                version = device_info["browser_version"]
                try:
                    major_version = version.split(".")[0]
                    anonymized["browser_version"] = f"{major_version}.x"
                except:
                    anonymized["browser_version"] = "unknown"
        
        # 屏幕尺寸范围化（保留大致范围，不保留精确值）
        if "screen_width" in device_info and "screen_height" in device_info:
            width = device_info["screen_width"]
            height = device_info["screen_height"]
            
            # 将屏幕尺寸归类到常见范围
            width_range = DataAnonymizer._get_screen_range(width)
            height_range = DataAnonymizer._get_screen_range(height)
            
            anonymized["screen_range"] = f"{width_range}x{height_range}"
        
        # 保留触摸支持信息（用于统计分析）
        if "is_touch_device" in device_info:
            anonymized["is_touch_device"] = device_info["is_touch_device"]
        
        return anonymized
    
    @staticmethod
    def _get_screen_range(size: int) -> str:
        """将屏幕尺寸归类到范围"""
        if size < 480:
            return "<480"
        elif size < 768:
            return "480-768"
        elif size < 1024:
            return "768-1024"
        elif size < 1440:
            return "1024-1440"
        elif size < 1920:
            return "1440-1920"
        else:
            return ">1920"
    
    @staticmethod
    def anonymize_interaction_metadata(metadata: Dict[str, Any], user_id: Optional[str] = None) -> Dict[str, Any]:
        """
        匿名化交互元数据
        
        保留统计相关信息，移除可识别信息
        """
        if not metadata:
            return {}
        
        anonymized = {}
        
        # 保留推荐相关统计信息
        if "is_recommended" in metadata:
            anonymized["is_recommended"] = metadata["is_recommended"]
        
        if "recommendation_algorithm" in metadata:
            anonymized["recommendation_algorithm"] = metadata["recommendation_algorithm"]
        
        if "match_score" in metadata:
            # 匹配分数范围化（保留到小数点后1位）
            score = metadata["match_score"]
            if isinstance(score, (int, float)):
                anonymized["match_score_range"] = f"{int(score * 10) / 10:.1f}"
        
        # 保留来源页面类型（用于统计分析）
        if "source_page" in metadata:
            anonymized["source_page_type"] = metadata["source_page"]
        
        # 列表位置范围化（保留大致位置，不保留精确值）
        if "list_position" in metadata:
            pos = metadata["list_position"]
            if isinstance(pos, int):
                if pos <= 5:
                    anonymized["list_position_range"] = "top5"
                elif pos <= 10:
                    anonymized["list_position_range"] = "top10"
                elif pos <= 20:
                    anonymized["list_position_range"] = "top20"
                else:
                    anonymized["list_position_range"] = "below20"
        
        # 匿名化设备信息
        if "device_info" in metadata:
            anonymized["device_info"] = DataAnonymizer.anonymize_device_info(metadata["device_info"])
        
        return anonymized


def anonymize_old_interactions(db: Session, days_old: int = 90) -> int:
    """
    匿名化旧的用户交互数据
    
    Args:
        db: 数据库会话
        days_old: 多少天前的数据需要匿名化（默认90天）
    
    Returns:
        匿名化的记录数
    """
    try:
        cutoff_date = get_utc_time() - timedelta(days=days_old)
        
        # 获取需要匿名化的交互记录
        interactions = db.query(UserTaskInteraction).filter(
            UserTaskInteraction.interaction_time < cutoff_date,
            UserTaskInteraction.interaction_metadata.isnot(None)
        ).all()
        
        anonymized_count = 0
        salt = datetime.now().strftime("%Y%m")
        
        for interaction in interactions:
            try:
                if interaction.interaction_metadata:
                    # 匿名化metadata
                    anonymized_metadata = DataAnonymizer.anonymize_interaction_metadata(
                        interaction.interaction_metadata,
                        interaction.user_id
                    )
                    
                    # 更新metadata
                    interaction.interaction_metadata = anonymized_metadata
                    anonymized_count += 1
            except Exception as e:
                logger.warning(f"匿名化交互记录 {interaction.id} 失败: {e}")
        
        if anonymized_count > 0:
            db.commit()
            logger.info(f"成功匿名化 {anonymized_count} 条交互记录")
        
        return anonymized_count
        
    except Exception as e:
        logger.error(f"匿名化交互数据失败: {e}", exc_info=True)
        db.rollback()
        return 0


def anonymize_old_feedback(db: Session, days_old: int = 90) -> int:
    """
    匿名化旧的推荐反馈数据
    
    Args:
        db: 数据库会话
        days_old: 多少天前的数据需要匿名化（默认90天）
    
    Returns:
        匿名化的记录数
    """
    try:
        cutoff_date = get_utc_time() - timedelta(days=days_old)
        
        # 获取需要匿名化的反馈记录
        feedbacks = db.query(RecommendationFeedback).filter(
            RecommendationFeedback.feedback_time < cutoff_date,
            RecommendationFeedback.feedback_metadata.isnot(None)
        ).all()
        
        anonymized_count = 0
        
        for feedback in feedbacks:
            try:
                if feedback.feedback_metadata:
                    # 匿名化metadata（移除可识别信息）
                    anonymized_metadata = {}
                    
                    # 只保留统计相关信息
                    if "device_info" in feedback.feedback_metadata:
                        anonymized_metadata["device_info"] = DataAnonymizer.anonymize_device_info(
                            feedback.feedback_metadata["device_info"]
                        )
                    
                    feedback.feedback_metadata = anonymized_metadata
                    anonymized_count += 1
            except Exception as e:
                logger.warning(f"匿名化反馈记录 {feedback.id} 失败: {e}")
        
        if anonymized_count > 0:
            db.commit()
            logger.info(f"成功匿名化 {anonymized_count} 条反馈记录")
        
        return anonymized_count
        
    except Exception as e:
        logger.error(f"匿名化反馈数据失败: {e}", exc_info=True)
        db.rollback()
        return 0
