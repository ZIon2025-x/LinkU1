"""
手机号验证码管理模块
处理手机验证码的生成、存储和验证
"""

import secrets
import logging
import json
from datetime import datetime, timedelta
from typing import Optional
from app.redis_cache import get_redis_client
from app.utils.time_utils import get_utc_time, parse_iso_utc

logger = logging.getLogger(__name__)

# 验证码有效期（秒）- 5分钟
VERIFICATION_CODE_EXPIRE_SECONDS = 5 * 60

# Redis键前缀
CODE_KEY_PREFIX = "phone_verification_code"


def generate_verification_code(length: int = 6) -> str:
    """生成数字验证码"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(length)])


def store_verification_code(phone: str, code: str) -> bool:
    """存储验证码到Redis，有效期5分钟"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法存储验证码")
            return False
        
        key = f"{CODE_KEY_PREFIX}:{phone}"
        code_data = {
            "code": code,
            "phone": phone,
            "created_at": get_utc_time().isoformat(),
            "expires_at": (get_utc_time() + timedelta(seconds=VERIFICATION_CODE_EXPIRE_SECONDS)).isoformat()
        }
        
        # 存储验证码，设置5分钟过期时间
        redis_client.setex(
            key,
            VERIFICATION_CODE_EXPIRE_SECONDS,
            json.dumps(code_data)
        )
        
        logger.info(f"手机验证码已存储: phone={phone}, code={code}")
        return True
    except Exception as e:
        logger.error(f"存储手机验证码失败: {e}")
        return False


def verify_and_delete_code(phone: str, code: str) -> bool:
    """验证验证码，验证成功后自动删除"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法验证验证码")
            return False
        
        key = f"{CODE_KEY_PREFIX}:{phone}"
        code_data_raw = redis_client.get(key)
        
        if not code_data_raw:
            logger.warning(f"手机验证码不存在或已过期: phone={phone}")
            return False
        
        # 解码数据
        if isinstance(code_data_raw, bytes):
            code_data_raw = code_data_raw.decode('utf-8')
        
        code_data = json.loads(code_data_raw)
        stored_code = code_data.get("code")
        
        # 验证验证码
        if stored_code != code:
            logger.warning(f"手机验证码不匹配: phone={phone}, provided={code}, stored={stored_code}")
            return False
        
        # 验证成功，删除验证码
        redis_client.delete(key)
        logger.info(f"手机验证码验证成功并已删除: phone={phone}")
        return True
        
    except json.JSONDecodeError as e:
        logger.error(f"解析手机验证码数据失败: {e}")
        # 清理无效数据
        try:
            redis_client = get_redis_client()
            if redis_client:
                redis_client.delete(f"{CODE_KEY_PREFIX}:{phone}")
        except:
            pass
        return False
    except Exception as e:
        logger.error(f"验证手机验证码失败: {e}")
        return False


def get_code_info(phone: str) -> Optional[dict]:
    """获取验证码信息（不删除）"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            return None
        
        key = f"{CODE_KEY_PREFIX}:{phone}"
        code_data_raw = redis_client.get(key)
        
        if not code_data_raw:
            return None
        
        # 解码数据
        if isinstance(code_data_raw, bytes):
            code_data_raw = code_data_raw.decode('utf-8')
        
        code_data = json.loads(code_data_raw)
        
        # 检查是否过期
        expires_at_str = code_data.get("expires_at")
        if expires_at_str:
            expires_at = parse_iso_utc(expires_at_str)
            if get_utc_time() > expires_at:
                # 已过期，删除
                redis_client.delete(key)
                return None
        
        # 不返回验证码本身，只返回元数据
        return {
            "phone": code_data.get("phone"),
            "created_at": code_data.get("created_at"),
            "expires_at": code_data.get("expires_at")
        }
    except Exception as e:
        logger.error(f"获取手机验证码信息失败: {e}")
        return None


def delete_code(phone: str) -> bool:
    """删除验证码"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            return False
        
        key = f"{CODE_KEY_PREFIX}:{phone}"
        deleted = redis_client.delete(key)
        return deleted > 0
    except Exception as e:
        logger.error(f"删除手机验证码失败: {e}")
        return False

