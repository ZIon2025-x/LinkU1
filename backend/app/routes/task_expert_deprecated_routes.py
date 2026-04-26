"""
Deprecation shim for /api/task-experts/* — returns 410 Gone with a clear
"please update" payload for old App Store iOS clients still hitting these
removed endpoints.

The real routes were deleted along with task_expert_routes.py; new clients
go through /api/experts/* and /api/expert-services/*. Admin paths under
/api/admin/task-experts/* live in admin_task_expert_routes.py and are NOT
affected by this shim (different prefix).
"""
from fastapi import APIRouter, status
from fastapi.responses import JSONResponse

router = APIRouter(prefix="/api/task-experts", tags=["deprecated"])

_GONE_PAYLOAD = {
    "error": "endpoint_deprecated",
    "message": "此 API 已停用，请将 App 更新到最新版本",
    "message_en": "This endpoint has been removed. Please update the app to the latest version.",
}

_METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE"]


def _gone() -> JSONResponse:
    return JSONResponse(status_code=status.HTTP_410_GONE, content=_GONE_PAYLOAD)


@router.api_route("", methods=_METHODS, include_in_schema=False)
@router.api_route("/", methods=_METHODS, include_in_schema=False)
async def deprecated_root():
    return _gone()


@router.api_route("/{path:path}", methods=_METHODS, include_in_schema=False)
async def deprecated_subpath(path: str):
    return _gone()
