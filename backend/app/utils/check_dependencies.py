"""
依赖检查工具
在启动时检查必要的依赖是否已安装，并提供清晰的安装提示
"""
import logging
import sys

logger = logging.getLogger(__name__)


def check_translation_dependencies():
    """检查翻译服务依赖"""
    missing_deps = []
    available_services = []
    
    # 检查 deep-translator
    try:
        import deep_translator
        available_services.append("deep-translator (Google, MyMemory等)")
    except ImportError:
        missing_deps.append("deep-translator")
    
    # 检查 google-cloud-translate
    try:
        import google.cloud.translate_v2
        available_services.append("google-cloud-translate (Google Cloud API)")
    except ImportError:
        missing_deps.append("google-cloud-translate")
    
    if missing_deps:
        logger.warning("=" * 60)
        logger.warning("翻译服务依赖缺失警告")
        logger.warning("=" * 60)
        logger.warning(f"缺失的依赖: {', '.join(missing_deps)}")
        logger.warning("")
        logger.warning("安装方法:")
        if "deep-translator" in missing_deps:
            logger.warning("  pip install deep-translator")
        if "google-cloud-translate" in missing_deps:
            logger.warning("  pip install google-cloud-translate")
        logger.warning("")
        logger.warning("或者安装所有翻译依赖:")
        logger.warning("  pip install deep-translator google-cloud-translate")
        logger.warning("")
        logger.warning("注意: 如果只使用部分翻译服务，可以只安装对应的依赖")
        logger.warning("=" * 60)
    else:
        logger.info("✓ 所有翻译服务依赖已安装")
    
    return {
        "missing": missing_deps,
        "available": available_services,
        "all_installed": len(missing_deps) == 0
    }


def check_all_dependencies():
    """检查所有关键依赖"""
    results = {
        "translation": check_translation_dependencies()
    }
    
    return results


if __name__ == "__main__":
    # 命令行直接运行时，检查并显示结果
    logging.basicConfig(level=logging.INFO)
    results = check_all_dependencies()
    
    if not results["translation"]["all_installed"]:
        print("\n❌ 部分翻译服务依赖缺失")
        print("请按照上述提示安装缺失的依赖")
        sys.exit(1)
    else:
        print("\n✅ 所有翻译服务依赖已安装")
        sys.exit(0)
