"""
翻译服务管理器
支持多个翻译服务提供商，自动降级和故障切换
"""
import os
import logging
import time
from typing import Optional, List, Tuple, Callable
from enum import Enum

logger = logging.getLogger(__name__)


class TranslationService(Enum):
    """翻译服务枚举"""
    GOOGLE_CLOUD = "google_cloud"  # Google Cloud Translation API（官方API）
    GOOGLE = "google"  # deep-translator的Google翻译（免费版）
    BAIDU = "baidu"
    YOUDAO = "youdao"
    DEEPL = "deepl"  # DeepL（需要API密钥，但有免费额度）
    MYMEMORY = "mymemory"  # MyMemory（免费）
    LIBRETRANSLATE = "libretranslate"  # LibreTranslate（免费开源）
    PONS = "pons"  # Pons（免费）
    LINGVANEX = "lingvanex"  # Lingvanex（免费）
    QCRI = "qcri"  # QCRI（免费）
    MICROSOFT = "microsoft"


class TranslationManager:
    """翻译服务管理器 - 支持多个翻译服务，自动降级"""
    
    def __init__(self):
        self.services: List[Tuple[TranslationService, callable]] = []
        self.failed_services: set = set()  # 记录失败的服务
        self.service_stats: dict = {}  # 服务统计信息
        
    def _init_services(self):
        """初始化翻译服务列表（按优先级排序）"""
        if self.services:
            return  # 已经初始化
        
        from app.config import get_settings
        settings = get_settings()
        
        # 从配置读取服务列表，如果没有配置则使用默认值
        service_config = getattr(settings, 'TRANSLATION_SERVICES', ['google_cloud', 'google', 'mymemory'])
        
        # 按优先级添加服务
        for service_name in service_config:
            service_name = service_name.strip().lower()
            
            # Google Cloud Translation API（官方API，优先使用）
            if service_name == 'google_cloud':
                try:
                    # 检查配置
                    api_key = getattr(settings, 'GOOGLE_CLOUD_TRANSLATE_API_KEY', '')
                    credentials_path = getattr(settings, 'GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH', '')
                    google_app_credentials = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '')
                    
                    if api_key or credentials_path or google_app_credentials:
                        try:
                            from google.cloud import translate_v2 as translate
                            
                            # 创建Google Cloud翻译客户端工厂函数
                            def create_google_cloud_translator():
                                if api_key:
                                    # 使用API密钥时，需要通过REST API方式调用
                                    # google-cloud-translate v2 的 Client 不支持 api_key 参数
                                    # 创建一个使用REST API的包装器
                                    class GoogleCloudRESTTranslator:
                                        def __init__(self, api_key):
                                            self.api_key = api_key
                                            self.base_url = "https://translation.googleapis.com/language/translate/v2"
                                        
                                        def translate(self, text, source_language=None, target_language='en'):
                                            import requests
                                            # Google Translation API REST v2 使用POST方法
                                            # API密钥作为查询参数，翻译内容在请求体中
                                            url = f"{self.base_url}?key={self.api_key}"
                                            
                                            # 构建请求体
                                            body = {
                                                'q': text,
                                                'target': target_language
                                            }
                                            if source_language:
                                                body['source'] = source_language
                                            
                                            headers = {
                                                'Content-Type': 'application/json'
                                            }
                                            
                                            try:
                                                response = requests.post(url, json=body, headers=headers, timeout=10)
                                                response.raise_for_status()
                                                result = response.json()
                                                
                                                # 检查响应格式
                                                if 'data' in result and 'translations' in result['data']:
                                                    if len(result['data']['translations']) > 0:
                                                        return {
                                                            'translatedText': result['data']['translations'][0]['translatedText']
                                                        }
                                                    else:
                                                        raise Exception("API返回的翻译结果为空")
                                                else:
                                                    logger.error(f"Google Translation API返回格式错误: {result}")
                                                    raise Exception(f"API返回格式错误: {result}")
                                            except requests.exceptions.RequestException as e:
                                                logger.error(f"Google Translation API请求失败: {e}")
                                                if hasattr(e, 'response') and e.response is not None:
                                                    try:
                                                        error_detail = e.response.json()
                                                        logger.error(f"API错误详情: {error_detail}")
                                                    except:
                                                        logger.error(f"API错误响应: {e.response.text}")
                                                raise
                                    
                                    return GoogleCloudRESTTranslator(api_key)
                                elif credentials_path:
                                    return translate.Client.from_service_account_json(credentials_path)
                                else:
                                    # 使用默认凭据（GOOGLE_APPLICATION_CREDENTIALS）
                                    return translate.Client()
                            
                            self.services.append((TranslationService.GOOGLE_CLOUD, create_google_cloud_translator))
                            logger.info("Google Cloud Translation API已配置")
                        except ImportError:
                            logger.warning("google-cloud-translate模块未安装，跳过Google Cloud Translation API。请运行: pip install google-cloud-translate")
                    else:
                        logger.warning("Google Cloud Translation API未配置（需要API密钥或凭据文件），跳过")
                except Exception as e:
                    logger.warning(f"初始化Google Cloud Translation API失败: {e}")
            
            # deep-translator的Google翻译（免费版，作为备选）
            elif service_name == 'google':
                try:
                    from deep_translator import GoogleTranslator
                    self.services.append((TranslationService.GOOGLE, GoogleTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过Google翻译")
            
            # MyMemory翻译（免费备选）
            elif service_name == 'mymemory':
                try:
                    from deep_translator import MyMemoryTranslator
                    self.services.append((TranslationService.MYMEMORY, MyMemoryTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过MyMemory翻译")
            
            # 百度翻译（需要API密钥）
            elif service_name == 'baidu':
                try:
                    from deep_translator import BaiduTranslator
                    appid = getattr(settings, 'BAIDU_TRANSLATE_APPID', '')
                    secret = getattr(settings, 'BAIDU_TRANSLATE_SECRET', '')
                    if appid and secret:
                        self.services.append((TranslationService.BAIDU, BaiduTranslator))
                    else:
                        logger.warning("百度翻译需要API密钥，跳过")
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过百度翻译")
            
            # 有道翻译（需要API密钥）
            elif service_name == 'youdao':
                try:
                    from deep_translator import YoudaoTranslator
                    appid = getattr(settings, 'YOUDAO_TRANSLATE_APPID', '')
                    secret = getattr(settings, 'YOUDAO_TRANSLATE_SECRET', '')
                    if appid and secret:
                        self.services.append((TranslationService.YOUDAO, YoudaoTranslator))
                    else:
                        logger.warning("有道翻译需要API密钥，跳过")
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过有道翻译")
            
            # DeepL翻译（需要API密钥，但有免费额度）
            elif service_name == 'deepl':
                try:
                    from deep_translator import DeeplTranslator
                    api_key = getattr(settings, 'DEEPL_API_KEY', '')
                    if api_key:
                        self.services.append((TranslationService.DEEPL, DeeplTranslator))
                    else:
                        logger.warning("DeepL翻译需要API密钥，跳过")
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过DeepL翻译")
            
            # LibreTranslate（免费开源翻译服务）
            elif service_name == 'libretranslate':
                try:
                    from deep_translator import LibreTranslator
                    # LibreTranslate 可以自建或使用公共实例，不需要API密钥
                    self.services.append((TranslationService.LIBRETRANSLATE, LibreTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过LibreTranslate")
                except Exception as e:
                    logger.warning(f"初始化LibreTranslate失败: {e}")
            
            # Pons翻译（免费）
            elif service_name == 'pons':
                try:
                    from deep_translator import PonsTranslator
                    self.services.append((TranslationService.PONS, PonsTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过Pons翻译")
                except Exception as e:
                    logger.warning(f"初始化Pons翻译失败: {e}")
            
            # Lingvanex翻译（免费，有额度限制）
            elif service_name == 'lingvanex':
                try:
                    from deep_translator import LingvanexTranslator
                    # Lingvanex 可能需要API密钥，但有些功能免费
                    self.services.append((TranslationService.LINGVANEX, LingvanexTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过Lingvanex翻译")
                except Exception as e:
                    logger.warning(f"初始化Lingvanex翻译失败: {e}")
            
            # QCRI翻译（免费）
            elif service_name == 'qcri':
                try:
                    from deep_translator import QcriTranslator
                    self.services.append((TranslationService.QCRI, QcriTranslator))
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过QCRI翻译")
                except Exception as e:
                    logger.warning(f"初始化QCRI翻译失败: {e}")
            
            # Microsoft翻译（需要API密钥）
            elif service_name == 'microsoft':
                try:
                    from deep_translator import MicrosoftTranslator
                    api_key = getattr(settings, 'MICROSOFT_TRANSLATE_KEY', '')
                    if api_key:
                        self.services.append((TranslationService.MICROSOFT, MicrosoftTranslator))
                    else:
                        logger.warning("Microsoft翻译需要API密钥，跳过")
                except ImportError:
                    logger.warning("deep-translator模块未安装，跳过Microsoft翻译")
        
        # 如果没有配置任何服务，使用默认服务
        if not self.services:
            logger.warning("没有可用的翻译服务，尝试使用默认服务")
            try:
                from deep_translator import GoogleTranslator, MyMemoryTranslator, LibreTranslator
                self.services = [
                    (TranslationService.GOOGLE, GoogleTranslator),
                    (TranslationService.MYMEMORY, MyMemoryTranslator),
                    (TranslationService.LIBRETRANSLATE, LibreTranslator),
                ]
            except ImportError:
                try:
                    from deep_translator import GoogleTranslator, MyMemoryTranslator
                    self.services = [
                        (TranslationService.GOOGLE, GoogleTranslator),
                        (TranslationService.MYMEMORY, MyMemoryTranslator),
                    ]
                except ImportError:
                    logger.error("deep-translator模块未安装，无法使用默认翻译服务")
        
        logger.info(f"翻译服务管理器初始化完成，可用服务: {[s.value for s, _ in self.services]}")
    
    def _create_translator(self, service: TranslationService, translator_class_or_factory, source_lang: str, target_lang: str):
        """创建翻译器实例"""
        try:
            from app.config import get_settings
            settings = get_settings()
            
            if service == TranslationService.GOOGLE_CLOUD:
                # Google Cloud Translation API（官方API）
                if callable(translator_class_or_factory):
                    # 如果是工厂函数，调用它创建客户端
                    client = translator_class_or_factory()
                    # 返回一个包装器，使其接口与deep-translator一致
                    class GoogleCloudTranslatorWrapper:
                        def __init__(self, client, source_lang, target_lang):
                            self.client = client
                            self.source_lang = source_lang if source_lang != 'auto' else None
                            self.target_lang = target_lang
                        
                        def translate(self, text):
                            # 检查是否是REST API包装器（有translate方法且接受参数）
                            if hasattr(self.client, 'translate') and callable(self.client.translate):
                                # 检查是否是REST API包装器（通过检查是否有api_key属性）
                                if hasattr(self.client, 'api_key'):
                                    # REST API方式
                                    result = self.client.translate(
                                        text,
                                        source_language=self.source_lang,
                                        target_language=self.target_lang
                                    )
                                    return result['translatedText']
                                else:
                                    # 标准Client方式
                                    result = self.client.translate(
                                        text,
                                        source_language=self.source_lang,
                                        target_language=self.target_lang
                                    )
                                    return result['translatedText']
                            else:
                                # 标准Client方式
                                result = self.client.translate(
                                    text,
                                    source_language=self.source_lang,
                                    target_language=self.target_lang
                                )
                                return result['translatedText']
                    
                    return GoogleCloudTranslatorWrapper(client, source_lang, target_lang)
                return None
            elif service == TranslationService.GOOGLE:
                # deep-translator的Google翻译
                if source_lang != 'auto':
                    return translator_class_or_factory(source=source_lang, target=target_lang)
                else:
                    return translator_class_or_factory(target=target_lang)
            elif service == TranslationService.MYMEMORY:
                # MyMemory支持的语言代码需要转换
                # MyMemory需要完整的语言代码，如 en-US, en-GB, zh-CN 等
                def normalize_lang_for_mymemory(lang: str) -> str:
                    """将语言代码转换为MyMemory支持的格式"""
                    if not lang or lang == 'auto':
                        return 'en'  # 默认使用英文
                    lang_lower = lang.lower()
                    # 映射常见语言代码
                    lang_map = {
                        'zh': 'zh-CN',
                        'zh-cn': 'zh-CN',
                        'zh-tw': 'zh-TW',
                        'zh-hk': 'zh-TW',
                        'en': 'en-US',  # MyMemory需要完整的区域代码
                        'en-us': 'en-US',
                        'en-gb': 'en-GB',
                    }
                    normalized = lang_map.get(lang_lower, lang)
                    # 如果已经是完整格式（包含-），直接返回
                    if '-' in normalized:
                        return normalized
                    # 否则尝试添加默认区域
                    if normalized == 'en':
                        return 'en-US'
                    return normalized
                
                source_normalized = normalize_lang_for_mymemory(source_lang if source_lang != 'auto' else 'en')
                target_normalized = normalize_lang_for_mymemory(target_lang)
                
                try:
                    return translator_class_or_factory(source=source_normalized, target=target_normalized)
                except Exception as e:
                    logger.warning(f"MyMemory翻译器创建失败 (source={source_normalized}, target={target_normalized}): {e}")
                    # 如果失败，尝试使用简化的语言代码
                    source_simple = source_normalized.split('-')[0] if '-' in source_normalized else source_normalized
                    target_simple = target_normalized.split('-')[0] if '-' in target_normalized else target_normalized
                    try:
                        return translator_class_or_factory(source=source_simple, target=target_simple)
                    except Exception as e2:
                        logger.warning(f"MyMemory翻译器创建失败（简化语言代码）: {e2}")
                        return None
            elif service == TranslationService.BAIDU:
                # 百度翻译需要API密钥
                appid = getattr(settings, 'BAIDU_TRANSLATE_APPID', '')
                secret = getattr(settings, 'BAIDU_TRANSLATE_SECRET', '')
                if not appid or not secret:
                    logger.warning("百度翻译API密钥未配置")
                    return None
                return translator_class_or_factory(appid=appid, secret=secret, source=source_lang, target=target_lang)
            elif service == TranslationService.YOUDAO:
                # 有道翻译需要API密钥
                appid = getattr(settings, 'YOUDAO_TRANSLATE_APPID', '')
                secret = getattr(settings, 'YOUDAO_TRANSLATE_SECRET', '')
                if not appid or not secret:
                    logger.warning("有道翻译API密钥未配置")
                    return None
                return translator_class_or_factory(appid=appid, secret=secret, source=source_lang, target=target_lang)
            elif service == TranslationService.DEEPL:
                # DeepL翻译（需要API密钥）
                api_key = getattr(settings, 'DEEPL_API_KEY', '')
                if api_key:
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang,
                        api_key=api_key
                    )
                return None
            elif service == TranslationService.LIBRETRANSLATE:
                # LibreTranslate（免费开源）
                api_key = getattr(settings, 'LIBRETRANSLATE_API_KEY', '')
                base_url = getattr(settings, 'LIBRETRANSLATE_BASE_URL', '')
                
                if base_url:
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang,
                        api_key=api_key if api_key else None,
                        base_url=base_url
                    )
                elif api_key:
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang,
                        api_key=api_key
                    )
                else:
                    # 使用默认公共实例（可能有限制）
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang
                    )
            elif service == TranslationService.PONS:
                # Pons翻译（免费）
                return translator_class_or_factory(
                    source=source_lang if source_lang != 'auto' else 'en',
                    target=target_lang
                )
            elif service == TranslationService.LINGVANEX:
                # Lingvanex翻译
                api_key = getattr(settings, 'LINGVANEX_API_KEY', '')
                if api_key:
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang,
                        api_key=api_key
                    )
                else:
                    # 尝试不使用API密钥（可能有限制）
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang
                    )
            elif service == TranslationService.QCRI:
                # QCRI翻译（免费）
                return translator_class_or_factory(
                    source=source_lang if source_lang != 'auto' else 'en',
                    target=target_lang
                )
            elif service == TranslationService.MICROSOFT:
                # Microsoft翻译（需要API密钥）
                api_key = getattr(settings, 'MICROSOFT_TRANSLATE_KEY', '')
                if api_key:
                    return translator_class_or_factory(
                        source=source_lang if source_lang != 'auto' else 'en',
                        target=target_lang,
                        api_key=api_key
                    )
                return None
            else:
                # 其他服务可能需要特殊处理
                return translator_class_or_factory(source=source_lang, target=target_lang)
        except Exception as e:
            logger.warning(f"创建{service.value}翻译器失败: {e}")
            return None
    
    def _preprocess_text_for_translation(self, text: str) -> tuple[str, dict]:
        """
        预处理文本，处理emoji等特殊字符
        
        返回:
        - (处理后的文本, emoji位置信息字典)
        """
        import re
        import unicodedata
        
        # 检测并记录emoji位置
        emoji_pattern = re.compile(
            "["
            "\U0001F600-\U0001F64F"  # emoticons
            "\U0001F300-\U0001F5FF"  # symbols & pictographs
            "\U0001F680-\U0001F6FF"  # transport & map symbols
            "\U0001F1E0-\U0001F1FF"  # flags (iOS)
            "\U00002702-\U000027B0"
            "\U000024C2-\U0001F251"
            "]+", 
            flags=re.UNICODE
        )
        
        emoji_positions = {}
        emoji_list = []
        
        # 查找所有emoji及其位置
        for match in emoji_pattern.finditer(text):
            emoji = match.group()
            start = match.start()
            emoji_list.append((start, emoji))
            emoji_positions[start] = emoji
        
        # 如果包含emoji，尝试规范化处理
        # 某些翻译API可能对某些emoji有问题，但Google Translation API通常能处理
        # 这里我们保留emoji，但确保文本编码正确
        processed_text = text
        
        # 确保文本是UTF-8编码
        if isinstance(processed_text, bytes):
            try:
                processed_text = processed_text.decode('utf-8')
            except:
                processed_text = processed_text.decode('utf-8', errors='ignore')
        
        # 规范化Unicode字符（NFC格式）
        try:
            processed_text = unicodedata.normalize('NFC', processed_text)
        except:
            pass  # 如果规范化失败，使用原文本
        
        return processed_text, emoji_positions
    
    def translate(
        self,
        text: str,
        target_lang: str,
        source_lang: str = 'auto',
        max_retries: int = 3
    ) -> Optional[str]:
        """
        翻译文本，自动尝试多个服务直到成功
        
        参数:
        - text: 要翻译的文本
        - target_lang: 目标语言
        - source_lang: 源语言（默认auto）
        - max_retries: 每个服务的最大重试次数
        
        返回:
        - 翻译后的文本，如果所有服务都失败则返回None
        """
        if not text or not text.strip():
            return text
        
        self._init_services()
        
        if not self.services:
            logger.error("没有可用的翻译服务")
            return None
        
        # 预处理文本（处理emoji等）
        processed_text, emoji_positions = self._preprocess_text_for_translation(text)
        
        # 转换语言代码格式
        lang_map = {
            'zh': 'zh-CN',
            'zh-cn': 'zh-CN',
            'zh-tw': 'zh-TW',
            'en': 'en'
        }
        target_lang_normalized = lang_map.get(target_lang.lower(), target_lang)
        source_lang_normalized = lang_map.get(source_lang.lower(), source_lang) if source_lang != 'auto' else 'auto'
        
        # 如果源语言和目标语言相同，直接返回原文
        if source_lang_normalized != 'auto' and source_lang_normalized == target_lang_normalized:
            return text
        
        # 按优先级尝试每个服务
        for service, translator_class in self.services:
            # 如果服务之前失败过，跳过（可选：可以定期重置失败记录）
            # 注意：可以设置失败记录的过期时间，这里暂时跳过失败的服务
            if service in self.failed_services:
                logger.debug(f"跳过失败的服务: {service.value}")
                continue
            
            try:
                translator = self._create_translator(service, translator_class, source_lang_normalized, target_lang_normalized)
                if not translator:
                    continue
                
                # 尝试翻译（带智能重试）
                from app.utils.translation_error_handler import handle_translation_error
                
                # 准备移除emoji的正则表达式（如果包含emoji）
                import re
                emoji_pattern = None
                if emoji_positions:
                    emoji_pattern = re.compile(
                        "["
                        "\U0001F600-\U0001F64F"  # emoticons
                        "\U0001F300-\U0001F5FF"  # symbols & pictographs
                        "\U0001F680-\U0001F6FF"  # transport & map symbols
                        "\U0001F1E0-\U0001F1FF"  # flags (iOS)
                        "\U00002702-\U000027B0"
                        "\U000024C2-\U0001F251"
                        "]+", 
                        flags=re.UNICODE
                    )
                
                for attempt in range(max_retries):
                    try:
                        # 根据尝试次数决定使用哪个文本
                        # 第一次尝试使用预处理后的文本（保留emoji）
                        # 如果失败且包含emoji，后续尝试移除emoji
                        text_to_translate = processed_text
                        emoji_removed = False
                        
                        if attempt > 0 and emoji_pattern and emoji_positions:
                            # 移除emoji后重试
                            text_to_translate = emoji_pattern.sub('', processed_text).strip()
                            if not text_to_translate:
                                # 如果移除emoji后文本为空，使用原文本
                                text_to_translate = processed_text
                            else:
                                emoji_removed = True
                                logger.debug(f"尝试 {attempt + 1}: 移除emoji后翻译")
                        
                        translated = translator.translate(text_to_translate)
                        
                        # 如果移除了emoji，尝试将emoji加回（简单方式：加在末尾）
                        if emoji_removed and emoji_positions and translated:
                            # 简单处理：将emoji加在翻译文本末尾
                            emoji_text = ''.join(emoji_positions.values())
                            if emoji_text:
                                translated = translated + ' ' + emoji_text
                        
                        # 翻译成功，更新统计
                        if service not in self.service_stats:
                            self.service_stats[service] = {'success': 0, 'failure': 0}
                        self.service_stats[service]['success'] += 1
                        
                        logger.debug(f"翻译成功: {service.value} -> {translated[:50]}...")
                        return translated
                        
                    except Exception as e:
                        # 使用错误处理器分析错误
                        # 确保text_to_translate变量存在
                        current_text = text_to_translate if 'text_to_translate' in locals() else processed_text
                        error_info = handle_translation_error(e, service.value, current_text, attempt)
                        
                        if error_info['should_retry'] and attempt < max_retries - 1:
                            retry_delay = error_info['retry_delay']
                            logger.warning(
                                f"{service.value}翻译失败（尝试 {attempt + 1}/{max_retries}，"
                                f"错误类型: {error_info['error_type']}，"
                                f"{retry_delay}秒后重试）: {e}"
                            )
                            # 智能延迟重试（使用time.sleep，因为这是同步函数）
                            if retry_delay > 0:
                                time.sleep(retry_delay)
                            continue
                        else:
                            # 所有重试都失败或不应该重试
                            logger.error(
                                f"{service.value}翻译失败（已重试{attempt + 1}次，"
                                f"错误类型: {error_info['error_type']}）: {e}"
                            )
                            if service not in self.service_stats:
                                self.service_stats[service] = {'success': 0, 'failure': 0}
                            self.service_stats[service]['failure'] += 1
                            
                            # 根据错误类型决定是否标记为失败
                            # 如果是速率限制或服务不可用，标记为失败
                            if error_info['error_type'] in ['rate_limit', 'service_unavailable']:
                                self.failed_services.add(service)
                            break
                
            except Exception as e:
                logger.error(f"使用{service.value}翻译服务时出错: {e}")
                self.failed_services.add(service)
                continue
        
        # 所有服务都失败了
        logger.error(f"所有翻译服务都失败，无法翻译文本: {text[:50]}...")
        return None
    
    def reset_failed_services(self):
        """重置失败服务记录（可以定期调用）"""
        self.failed_services.clear()
        logger.info("已重置失败服务记录")
    
    def get_service_stats(self) -> dict:
        """获取服务统计信息"""
        stats = self.service_stats.copy()
        
        # 添加错误统计
        try:
            from app.utils.translation_error_handler import get_error_handler
            error_handler = get_error_handler()
            error_stats = error_handler.get_error_stats()
            stats['error_stats'] = error_stats
        except Exception:
            pass
        
        # 计算平均响应时间（如果有记录）
        for service_name, service_stats in stats.items():
            if isinstance(service_stats, dict) and 'times' in service_stats:
                times = service_stats['times']
                if times:
                    service_stats['avg_time'] = sum(times) / len(times)
                    service_stats['min_time'] = min(times)
                    service_stats['max_time'] = max(times)
        
        # 检查服务健康状态并生成告警
        try:
            from app.utils.translation_alert import check_service_health, record_alert
            for service in TranslationService:
                service_name = service.value
                if service_name in stats:
                    service_stats = stats[service_name]
                    if isinstance(service_stats, dict):
                        alerts = check_service_health(service_name, service_stats, [])
                        for alert in alerts:
                            record_alert(alert)
        except Exception as e:
            logger.debug(f"检查服务健康状态失败: {e}")
        
        return stats
    
    def get_available_services(self) -> List[str]:
        """获取可用服务列表"""
        self._init_services()
        return [s.value for s, _ in self.services if s not in self.failed_services]
    
    def get_all_services(self) -> List[str]:
        """获取所有配置的服务列表（包括失败的）"""
        self._init_services()
        return [s.value for s, _ in self.services]


# 全局单例
_translation_manager: Optional[TranslationManager] = None


def get_translation_manager() -> TranslationManager:
    """获取翻译管理器单例"""
    global _translation_manager
    if _translation_manager is None:
        _translation_manager = TranslationManager()
    return _translation_manager
