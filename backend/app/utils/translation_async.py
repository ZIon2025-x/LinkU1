"""
翻译异步处理工具
将同步翻译调用转换为异步，提升并发性能
"""
import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Optional

logger = logging.getLogger(__name__)

# 创建线程池用于执行同步翻译操作
# 限制并发数，避免过多线程导致资源耗尽
_translation_executor = ThreadPoolExecutor(
    max_workers=10,
    thread_name_prefix="translation_worker"
)


async def translate_async(
    translation_manager,
    text: str,
    target_lang: str,
    source_lang: str = 'auto',
    max_retries: int = 3
) -> Optional[str]:
    """
    异步执行翻译（在线程池中运行同步翻译方法）
    
    参数:
    - translation_manager: TranslationManager实例
    - text: 要翻译的文本
    - target_lang: 目标语言
    - source_lang: 源语言（默认auto）
    - max_retries: 每个服务的最大重试次数
    
    返回:
    - 翻译后的文本，如果所有服务都失败则返回None
    """
    try:
        loop = asyncio.get_event_loop()
        # 在线程池中执行同步翻译方法
        translated_text = await loop.run_in_executor(
            _translation_executor,
            lambda: translation_manager.translate(
                text=text,
                target_lang=target_lang,
                source_lang=source_lang,
                max_retries=max_retries
            )
        )
        return translated_text
    except Exception as e:
        logger.error(f"异步翻译失败: {e}", exc_info=True)
        return None


async def translate_batch_async(
    translation_manager,
    texts: list[str],
    target_lang: str,
    source_lang: str = 'auto',
    max_retries: int = 3,
    max_concurrent: int = 5
) -> list[Optional[str]]:
    """
    异步批量翻译（支持并发控制）
    
    参数:
    - translation_manager: TranslationManager实例
    - texts: 要翻译的文本列表
    - target_lang: 目标语言
    - source_lang: 源语言（默认auto）
    - max_retries: 每个服务的最大重试次数
    - max_concurrent: 最大并发数（避免过多并发请求）
    
    返回:
    - 翻译结果列表（与输入列表对应，失败为None）
    """
    if not texts:
        return []
    
    # 使用信号量控制并发数
    semaphore = asyncio.Semaphore(max_concurrent)
    
    async def translate_with_semaphore(text: str) -> Optional[str]:
        async with semaphore:
            return await translate_async(
                translation_manager,
                text,
                target_lang,
                source_lang,
                max_retries
            )
    
    # 并发执行所有翻译任务
    tasks = [translate_with_semaphore(text) for text in texts]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    
    # 处理异常结果
    final_results = []
    for i, result in enumerate(results):
        if isinstance(result, Exception):
            logger.error(f"批量翻译第{i}项失败: {result}")
            final_results.append(None)
        else:
            final_results.append(result)
    
    return final_results
