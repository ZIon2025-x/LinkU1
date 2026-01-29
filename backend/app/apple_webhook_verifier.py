"""
Apple App Store Server Notifications V2 签名验证
验证 Webhook 请求的 signedPayload 是否来自 Apple
"""
from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

_verifier: Optional[Any] = None


def _cert_dir() -> Path:
    override = os.getenv("APPLE_ROOT_CERT_DIR")
    if override:
        return Path(override)
    base = Path(__file__).resolve().parent
    return base / "certs" / "apple_root"


def _load_root_certificates() -> List[bytes]:
    cert_dir = _cert_dir()
    certs: List[bytes] = []
    for p in sorted(cert_dir.iterdir()):
        if p.suffix.lower() in (".cer", ".crt", ".der") and p.is_file():
            try:
                certs.append(p.read_bytes())
            except Exception as e:
                logger.warning("Failed to load cert %s: %s", p.name, e)
    return certs


def _get_verifier():
    global _verifier
    if _verifier is not None:
        return _verifier

    try:
        from appstoreserverlibrary.models.Environment import Environment
        from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier
    except ImportError as e:
        logger.warning("app-store-server-library not installed: %s", e)
        return None

    root_certs = _load_root_certificates()
    if not root_certs:
        logger.warning(
            "No Apple root certs in %s. Run: python -m app.scripts.download_apple_root_certs",
            _cert_dir(),
        )
        return None

    bundle_id = os.getenv("IAP_BUNDLE_ID", "com.link2ur")
    use_sandbox = os.getenv("IAP_USE_SANDBOX", "false").lower() == "true"
    environment = Environment.SANDBOX if use_sandbox else Environment.PRODUCTION

    app_apple_id_raw = os.getenv("IAP_APP_APPLE_ID")
    app_apple_id: Optional[int] = None
    if app_apple_id_raw:
        try:
            app_apple_id = int(app_apple_id_raw)
        except ValueError:
            logger.warning("Invalid IAP_APP_APPLE_ID: %s", app_apple_id_raw)
    if environment == Environment.PRODUCTION and app_apple_id is None:
        logger.warning("IAP_APP_APPLE_ID required for Production; V2 verification may fail")

    enable_online = os.getenv("APPLE_WEBHOOK_VERIFY_ONLINE", "true").lower() == "true"
    try:
        _verifier = SignedDataVerifier(
            root_certificates=root_certs,
            enable_online_checks=enable_online,
            environment=environment,
            bundle_id=bundle_id,
            app_apple_id=app_apple_id,
        )
        logger.info(
            "Apple Webhook V2 verifier initialized: env=%s bundle_id=%s",
            "sandbox" if use_sandbox else "production",
            bundle_id,
        )
    except Exception as e:
        logger.warning("Failed to init Apple Webhook verifier: %s", e)
        _verifier = None
    return _verifier


def verify_and_decode_notification(signed_payload: str) -> Optional[Dict[str, Any]]:
    """
    验证并解码 App Store Server Notifications V2 的 signedPayload。

    Args:
        signed_payload: 请求体中的 signedPayload 字符串（JWS）

    Returns:
        解码后的 payload 字典（含 notificationType, data 等），验证失败或未配置时返回 None
    """
    v = _get_verifier()
    if not v:
        return None

    try:
        decoded = v.verify_and_decode_notification(signed_payload)
    except Exception as e:
        logger.warning("Apple Webhook V2 verification failed: %s", e)
        return None

    out: Dict[str, Any] = {}
    out["notificationType"] = (
        decoded.rawNotificationType
        if decoded.rawNotificationType
        else (decoded.notificationType.value if decoded.notificationType else None)
    )
    out["subtype"] = (
        decoded.rawSubtype
        if decoded.rawSubtype
        else (decoded.subtype.value if decoded.subtype else None)
    )
    out["notificationUUID"] = decoded.notificationUUID
    out["signedDate"] = decoded.signedDate
    out["version"] = decoded.version
    out["data"] = None
    out["summary"] = None

    if decoded.data:
        d = decoded.data
        out["data"] = {
            "bundleId": d.bundleId,
            "appAppleId": d.appAppleId,
            "environment": d.rawEnvironment or (d.environment.value if d.environment else None),
            "signedTransactionInfo": d.signedTransactionInfo,
            "signedRenewalInfo": d.signedRenewalInfo,
            "status": d.rawStatus,
        }
    elif decoded.summary:
        s = decoded.summary
        out["summary"] = {
            "bundleId": s.bundleId,
            "appAppleId": s.appAppleId,
            "environment": (
                s.rawEnvironment or (s.environment.value if s.environment else None)
            ),
        }

    return out


def is_verification_available() -> bool:
    """是否已配置并可使用 V2 签名验证。"""
    return _get_verifier() is not None
