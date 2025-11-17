"""
修改邮箱/手机号验证码管理模块
处理修改邮箱/手机号时的验证码生成、存储和验证
"""

import secrets
import logging
import json
from datetime import datetime, timedelta
from typing import Optional
from app.redis_cache import get_redis_client
from app.utils.time_utils import get_utc_time, format_iso_utc

logger = logging.getLogger(__name__)

# 验证码有效期（秒）- 5分钟
VERIFICATION_CODE_EXPIRE_SECONDS = 5 * 60

# Redis键前缀
EMAIL_UPDATE_CODE_KEY_PREFIX = "email_update_verification_code"
PHONE_UPDATE_CODE_KEY_PREFIX = "phone_update_verification_code"


def generate_verification_code(length: int = 6) -> str:
    """生成数字验证码"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(length)])


def store_email_update_code(user_id: str, new_email: str, code: str) -> bool:
    """存储邮箱修改验证码到Redis，有效期5分钟"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法存储验证码")
            return False
        
        key = f"{EMAIL_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_email}"
        code_data = {
            "code": code,
            "user_id": user_id,
            "new_email": new_email,
            "created_at": format_iso_utc(get_utc_time()),
            "expires_at": format_iso_utc(get_utc_time() + timedelta(seconds=VERIFICATION_CODE_EXPIRE_SECONDS))
        }
        
        # 存储验证码，设置5分钟过期时间
        redis_client.setex(
            key,
            VERIFICATION_CODE_EXPIRE_SECONDS,
            json.dumps(code_data)
        )
        
        logger.info(f"邮箱修改验证码已存储: user_id={user_id}, new_email={new_email}, code={code}")
        return True
    except Exception as e:
        logger.error(f"存储邮箱修改验证码失败: {e}")
        return False


def store_phone_update_code(user_id: str, new_phone: str, code: str) -> bool:
    """存储手机号修改验证码到Redis，有效期5分钟"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法存储验证码")
            return False
        
        key = f"{PHONE_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_phone}"
        code_data = {
            "code": code,
            "user_id": user_id,
            "new_phone": new_phone,
            "created_at": format_iso_utc(get_utc_time()),
            "expires_at": format_iso_utc(get_utc_time() + timedelta(seconds=VERIFICATION_CODE_EXPIRE_SECONDS))
        }
        
        # 存储验证码，设置5分钟过期时间
        redis_client.setex(
            key,
            VERIFICATION_CODE_EXPIRE_SECONDS,
            json.dumps(code_data)
        )
        
        logger.info(f"手机号修改验证码已存储: user_id={user_id}, new_phone={new_phone}, code={code}")
        return True
    except Exception as e:
        logger.error(f"存储手机号修改验证码失败: {e}")
        return False


def verify_email_update_code(user_id: str, new_email: str, code: str) -> bool:
    """验证邮箱修改验证码，验证成功后自动删除"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法验证验证码")
            return False
        
        key = f"{EMAIL_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_email}"
        code_data_raw = redis_client.get(key)
        
        if not code_data_raw:
            logger.warning(f"邮箱修改验证码不存在或已过期: user_id={user_id}, new_email={new_email}")
            return False
        
        # 解码数据
        if isinstance(code_data_raw, bytes):
            code_data_raw = code_data_raw.decode('utf-8')
        
        code_data = json.loads(code_data_raw)
        stored_code = code_data.get("code")
        
        # 验证验证码
        if stored_code != code:
            logger.warning(f"邮箱修改验证码不匹配: user_id={user_id}, new_email={new_email}, provided={code}, stored={stored_code}")
            return False
        
        # 验证成功，删除验证码
        redis_client.delete(key)
        logger.info(f"邮箱修改验证码验证成功并已删除: user_id={user_id}, new_email={new_email}")
        return True
        
    except json.JSONDecodeError as e:
        logger.error(f"解析邮箱修改验证码数据失败: {e}")
        # 清理无效数据
        try:
            redis_client = get_redis_client()
            if redis_client:
                redis_client.delete(f"{EMAIL_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_email}")
        except:
            pass
        return False
    except Exception as e:
        logger.error(f"验证邮箱修改验证码失败: {e}")
        return False


def verify_phone_update_code(user_id: str, new_phone: str, code: str) -> bool:
    """验证手机号修改验证码，验证成功后自动删除"""
    try:
        redis_client = get_redis_client()
        if not redis_client:
            logger.error("Redis客户端不可用，无法验证验证码")
            return False
        
        key = f"{PHONE_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_phone}"
        code_data_raw = redis_client.get(key)
        
        if not code_data_raw:
            logger.warning(f"手机号修改验证码不存在或已过期: user_id={user_id}, new_phone={new_phone}")
            return False
        
        # 解码数据
        if isinstance(code_data_raw, bytes):
            code_data_raw = code_data_raw.decode('utf-8')
        
        code_data = json.loads(code_data_raw)
        stored_code = code_data.get("code")
        
        # 验证验证码
        if stored_code != code:
            logger.warning(f"手机号修改验证码不匹配: user_id={user_id}, new_phone={new_phone}, provided={code}, stored={stored_code}")
            return False
        
        # 验证成功，删除验证码
        redis_client.delete(key)
        logger.info(f"手机号修改验证码验证成功并已删除: user_id={user_id}, new_phone={new_phone}")
        return True
        
    except json.JSONDecodeError as e:
        logger.error(f"解析手机号修改验证码数据失败: {e}")
        # 清理无效数据
        try:
            redis_client = get_redis_client()
            if redis_client:
                redis_client.delete(f"{PHONE_UPDATE_CODE_KEY_PREFIX}:{user_id}:{new_phone}")
        except:
            pass
        return False
    except Exception as e:
        logger.error(f"验证手机号修改验证码失败: {e}")
        return False

