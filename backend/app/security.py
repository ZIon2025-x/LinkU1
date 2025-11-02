"""
安全JWT认证模块
实现短期Access Token + 长期Refresh Token的安全认证系统
"""

import hashlib
import json
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional, Tuple

import jwt
import redis
from fastapi import HTTPException, Request, Response, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt import PyJWT
from passlib.context import CryptContext

logger = logging.getLogger(__name__)

# 密码加密上下文
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# 密码验证和哈希函数
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """生成密码哈希"""
    return pwd_context.hash(password)


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """解码访问令牌（兼容旧系统）"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.InvalidTokenError:
        return None

# JWT配置
# 开发环境使用固定密钥，生产环境必须设置环境变量
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production")
ALGORITHM = "HS256"

# Token过期时间配置
ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15")
)  # 15分钟
REFRESH_TOKEN_EXPIRE_HOURS = int(os.getenv("REFRESH_TOKEN_EXPIRE_HOURS", "12"))  # 12小时

# 时钟偏差容忍（秒）
CLOCK_SKEW_TOLERANCE = int(os.getenv("CLOCK_SKEW_TOLERANCE", "300"))  # 5分钟

# Redis配置（用于Token黑名单）
from app.config import Config

redis_client = None

# 检查是否启用Redis
if Config.USE_REDIS:
    try:
        redis_client = redis.from_url(Config.REDIS_URL, decode_responses=True)
        redis_client.ping()  # 测试连接
        logger.info("✅ Redis连接成功")
    except Exception as e:
        logger.warning(f"⚠️ Redis连接失败: {e}，将使用内存存储")
        redis_client = None
else:
    logger.info("ℹ️ Redis已禁用，使用内存存储")

# 内存存储（Redis不可用时的备选方案）
token_blacklist = set()


class SecurityConfig:
    """安全配置类"""

    # Cookie配置 - 统一使用config.py的配置
    from app.config import Config
    COOKIE_SECURE = Config.COOKIE_SECURE
    COOKIE_HTTPONLY = Config.COOKIE_HTTPONLY
    COOKIE_SAMESITE = Config.COOKIE_SAMESITE
    # COOKIE_DOMAIN 已移除 - 现在只使用当前域名

    # CORS配置
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080,https://www.link2ur.com"
    ).split(",")

    # 安全头配置
    SECURITY_HEADERS = {
        "X-Content-Type-Options": "nosniff",
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
        "Referrer-Policy": "strict-origin-when-cross-origin",
    }


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """生成密码哈希"""
    return pwd_context.hash(password)


def generate_strong_password(length: int = 16) -> str:
    """生成强密码（包含大小写字母、数字、特殊字符）"""
    import string
    # 确保包含各种字符类型
    uppercase = string.ascii_uppercase
    lowercase = string.ascii_lowercase
    digits = string.digits
    special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    # 至少每种类型包含一个字符
    password = [
        secrets.choice(uppercase),
        secrets.choice(lowercase),
        secrets.choice(digits),
        secrets.choice(special_chars)
    ]
    
    # 填充剩余长度
    all_chars = uppercase + lowercase + digits + special_chars
    password.extend(secrets.choice(all_chars) for _ in range(length - 4))
    
    # 打乱顺序
    secrets.SystemRandom().shuffle(password)
    
    return ''.join(password)


def create_access_token(
    data: Dict[str, Any], expires_delta: Optional[timedelta] = None
) -> str:
    """创建访问令牌"""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update(
        {
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access",
            "jti": secrets.token_urlsafe(16),  # JWT ID，用于撤销
        }
    )

    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def create_refresh_token(
    data: Dict[str, Any], expires_delta: Optional[timedelta] = None
) -> str:
    """创建刷新令牌"""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(hours=REFRESH_TOKEN_EXPIRE_HOURS)

    # 生成唯一的refresh token ID
    refresh_jti = secrets.token_urlsafe(32)

    to_encode.update(
        {
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "refresh",
            "jti": refresh_jti,
            "version": 1,  # 用于token轮换
        }
    )

    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

    # 存储refresh token信息到Redis
    store_refresh_token(refresh_jti, data.get("sub"), expire)

    return encoded_jwt


def verify_token(token: str, token_type: str = "access") -> Dict[str, Any]:
    """验证令牌"""
    try:
        # 检查token是否在黑名单中
        if is_token_blacklisted(token):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Token已被撤销"
            )

        # 解码token
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],
            options={
                "verify_exp": True,
                "leeway": CLOCK_SKEW_TOLERANCE,  # 时钟偏差容忍
            },
        )

        # 验证token类型
        if payload.get("type") != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"无效的token类型，期望: {token_type}",
            )

        # 验证token是否过期
        exp = payload.get("exp")
        if exp and datetime.fromtimestamp(exp, tz=timezone.utc) < datetime.now(
            timezone.utc
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Token已过期"
            )

        return payload

    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token已过期"
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Token验证失败: {str(e)}"
        )


def refresh_access_token(refresh_token: str) -> Tuple[str, str]:
    """刷新访问令牌（实现token轮换）"""
    try:
        # 验证refresh token
        payload = verify_token(refresh_token, "refresh")

        refresh_jti = payload.get("jti")
        user_id = payload.get("sub")

        if not refresh_jti or not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="无效的refresh token"
            )

        # 检查refresh token是否有效
        if not is_refresh_token_valid(refresh_jti, user_id):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="Refresh token已失效"
            )

        # 撤销旧的refresh token
        revoke_refresh_token(refresh_jti, user_id)

        # 创建新的token对
        new_access_token = create_access_token({"sub": user_id})
        new_refresh_token = create_refresh_token({"sub": user_id})

        logger.info(f"Token轮换成功: 用户 {user_id}")

        return new_access_token, new_refresh_token

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Token刷新失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token刷新失败"
        )


def revoke_token(token: str) -> bool:
    """撤销令牌"""
    try:
        # 解析token获取过期时间
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM], options={"verify_exp": False}
        )
        exp = payload.get("exp")
        jti = payload.get("jti")

        if exp and jti:
            # 计算剩余过期时间
            expire_time = datetime.fromtimestamp(exp, tz=timezone.utc)
            now = datetime.now(timezone.utc)

            if expire_time > now:
                # 添加到黑名单
                ttl = int((expire_time - now).total_seconds())
                add_to_blacklist(jti, ttl)

                logger.info(f"Token已撤销: {jti}")
                return True

        return False

    except Exception as e:
        logger.error(f"撤销token失败: {e}")
        return False


def revoke_refresh_token(refresh_jti: str, user_id: str) -> bool:
    """撤销刷新令牌"""
    try:
        if redis_client:
            # 从Redis中删除
            redis_client.delete(f"refresh_token:{refresh_jti}")
            redis_client.delete(f"user_refresh_tokens:{user_id}")
        else:
            # 从内存中删除
            token_blacklist.add(refresh_jti)

        logger.info(f"Refresh token已撤销: {refresh_jti}")
        return True

    except Exception as e:
        logger.error(f"撤销refresh token失败: {e}")
        return False


def revoke_all_user_tokens(user_id: str) -> bool:
    """撤销用户的所有令牌"""
    try:
        if redis_client:
            # 获取用户的所有refresh token
            user_tokens = redis_client.smembers(f"user_refresh_tokens:{user_id}")

            # 删除所有refresh token
            for token_jti in user_tokens:
                redis_client.delete(f"refresh_token:{token_jti}")

            # 删除用户token集合
            redis_client.delete(f"user_refresh_tokens:{user_id}")

        logger.info(f"用户 {user_id} 的所有token已撤销")
        return True

    except Exception as e:
        logger.error(f"撤销用户所有token失败: {e}")
        return False


def store_refresh_token(refresh_jti: str, user_id: str, expire_time: datetime) -> bool:
    """存储刷新令牌信息"""
    try:
        if redis_client:
            # 存储到Redis
            token_data = {
                "user_id": user_id,
                "created_at": datetime.utcnow().isoformat(),
                "expires_at": expire_time.isoformat(),
            }

            # 设置过期时间
            ttl = int((expire_time - datetime.utcnow()).total_seconds())

            redis_client.setex(
                f"refresh_token:{refresh_jti}", ttl, json.dumps(token_data)
            )

            # 添加到用户token集合
            redis_client.sadd(f"user_refresh_tokens:{user_id}", refresh_jti)
            redis_client.expire(f"user_refresh_tokens:{user_id}", ttl)

        return True

    except Exception as e:
        logger.error(f"存储refresh token失败: {e}")
        return False


def is_refresh_token_valid(refresh_jti: str, user_id: str) -> bool:
    """检查刷新令牌是否有效"""
    try:
        if redis_client:
            # 从Redis检查
            token_data = redis_client.get(f"refresh_token:{refresh_jti}")
            if token_data:
                data = json.loads(token_data)
                return data.get("user_id") == user_id
            return False
        else:
            # Redis不可用时，只验证JWT token本身的有效性
            # 这里我们信任JWT token的签名和过期时间
            logger.info("Redis不可用，跳过refresh token存储验证")
            return True

    except Exception as e:
        logger.error(f"检查refresh token有效性失败: {e}")
        # 出错时，如果Redis不可用，仍然允许验证通过
        if not redis_client:
            logger.warning("Redis不可用且验证出错，允许token验证通过")
            return True
        return False


def is_token_blacklisted(token: str) -> bool:
    """检查令牌是否在黑名单中"""
    try:
        # 解析token获取jti
        payload = jwt.decode(
            token, SECRET_KEY, algorithms=[ALGORITHM], options={"verify_exp": False}
        )
        jti = payload.get("jti")

        if not jti:
            return False

        if redis_client:
            # 从Redis检查
            return redis_client.exists(f"blacklist:{jti}") > 0
        else:
            # 从内存检查
            return jti in token_blacklist

    except Exception:
        return False


def add_to_blacklist(jti: str, ttl: int) -> bool:
    """添加令牌到黑名单"""
    try:
        if redis_client:
            # 存储到Redis
            redis_client.setex(f"blacklist:{jti}", ttl, "1")
        else:
            # 存储到内存
            token_blacklist.add(jti)

        return True

    except Exception as e:
        logger.error(f"添加到黑名单失败: {e}")
        return False


# 已弃用的Cookie函数已移除，请使用 app.cookie_manager.CookieManager


def add_security_headers(response: Response) -> None:
    """添加安全响应头"""
    for header, value in SecurityConfig.SECURITY_HEADERS.items():
        response.headers[header] = value


def get_client_ip(request: Request) -> str:
    """获取客户端IP地址"""
    # 检查代理头
    forwarded_for = request.headers.get("X-Forwarded-For")
    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip

    return request.client.host if request.client else "unknown"


def log_security_event(
    event_type: str, user_id: str, ip_address: str, details: str = ""
) -> None:
    """记录安全事件（暂时禁用以解决异步/同步混用问题）"""
    # 暂时禁用安全事件记录
    pass
    # logger.warning(
    #     f"SECURITY_EVENT: {event_type} | User: {user_id} | IP: {ip_address} | Details: {details}"
    # )


# 自定义HTTPBearer，支持从Cookie获取token
class CookieHTTPBearer(HTTPBearer):
    """支持从Cookie获取token的HTTPBearer"""

    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)

    async def __call__(
        self, request: Request
    ) -> Optional[HTTPAuthorizationCredentials]:
        # 首先尝试从Authorization头获取
        authorization = await super().__call__(request)
        if authorization:
            return authorization

        # 如果Authorization头没有，尝试从Cookie获取session_id
        session_id = request.cookies.get("session_id")
        if session_id:
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        if self.auto_error:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
            )

        return None


# 同步版本的Cookie认证器
class SyncCookieHTTPBearer(HTTPBearer):
    """同步版本的支持从Cookie获取token的HTTPBearer"""

    def __init__(self, auto_error: bool = True):
        super().__init__(auto_error=auto_error)

    def __call__(
        self, request: Request
    ) -> Optional[HTTPAuthorizationCredentials]:
        # 调试信息
        print(f"[DEBUG] SyncCookieHTTPBearer - URL: {request.url}")
        print(f"[DEBUG] SyncCookieHTTPBearer - Headers: {dict(request.headers)}")
        print(f"[DEBUG] SyncCookieHTTPBearer - Cookies: {dict(request.cookies)}")
        
        # 首先尝试从Authorization头获取
        authorization_header = request.headers.get("Authorization")
        if authorization_header and authorization_header.startswith("Bearer "):
            token = authorization_header.split(" ")[1]
            print(f"[DEBUG] 从Authorization头获取token: {token[:20]}...")
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=token
            )

        # 如果Authorization头没有，尝试从X-Session-ID头获取
        session_id = request.headers.get("X-Session-ID")
        if session_id:
            print(f"[DEBUG] 从X-Session-ID头获取session_id: {session_id[:20]}...")
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        
        # 如果X-Session-ID头没有，尝试从Cookie获取session_id
        session_id = request.cookies.get("session_id")
        if session_id:
            print(f"[DEBUG] 从Cookie获取session_id: {session_id[:20]}...")
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        
        # 尝试从其他Cookie名称获取
        session_id = (
            request.cookies.get("mobile_session_id") or
            request.cookies.get("js_session_id")
        )
        if session_id:
            print(f"[DEBUG] 从其他Cookie获取session_id: {session_id[:20]}...")
            return HTTPAuthorizationCredentials(
                scheme="Bearer", credentials=session_id
            )
        
        # 移动端特殊处理：检查是否为移动端且没有Cookie
        user_agent = request.headers.get("user-agent", "")
        is_mobile = any(keyword in user_agent.lower() for keyword in [
            'mobile', 'iphone', 'ipad', 'android', 'blackberry', 
            'windows phone', 'opera mini', 'iemobile'
        ])
        
        if is_mobile:
            print(f"[DEBUG] 移动端检测到Cookie缺失 - User-Agent: {user_agent}")
            print(f"[DEBUG] 移动端Cookie问题 - 可能是SameSite/Secure设置问题")
            print(f"[DEBUG] 建议检查移动端Cookie设置")
        
        print("[DEBUG] 未找到认证信息")
        if self.auto_error:
            print("[DEBUG] 抛出401错误 - 未提供认证信息")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供认证信息"
            )
        
        return None


# 创建认证实例
cookie_bearer = CookieHTTPBearer()
sync_cookie_bearer = SyncCookieHTTPBearer()
