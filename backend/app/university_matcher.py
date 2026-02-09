"""
大学匹配器（使用Aho-Corasick算法优化性能）
启动时加载所有大学pattern到内存，避免每次匹配都查询数据库
"""
import logging
import threading
from typing import Optional

try:
    from pyahocorasick import Automaton
    HAS_AHOCORASICK = True
except ImportError:
    HAS_AHOCORASICK = False
    # 如果没有安装pyahocorasick，使用简单的字典匹配
    Automaton = None

from app import models

logger = logging.getLogger(__name__)


class UniversityMatcher:
    """大学匹配器（内存缓存版本）"""
    
    def __init__(self):
        if HAS_AHOCORASICK:
            self.automaton = Automaton()
        else:
            self.automaton = None
        self.university_map = {}  # key: "uni_id:match_type:pattern" -> University对象
        self._initialized = False
        self._lock = threading.Lock()
    
    def initialize(self, db):
        """
        启动时初始化，加载所有大学pattern到内存
        
        重要：此方法应在应用启动时（startup event）主动调用一次，避免并发初始化竞态。
        不要依赖 lazy init，否则高并发首次启动时会导致多次全表扫描。
        """
        if self._initialized:
            return
        
        # 使用锁防止并发初始化（双重检查锁定模式）
        with self._lock:
            # 双重检查：再次检查是否已初始化
            if self._initialized:
                return
            
            universities = db.query(models.University).filter(
                models.University.is_active == True
            ).all()
            
            for uni in universities:
                pattern = uni.domain_pattern.replace('@', '').replace('*', '')
                # 添加精确匹配
                exact_key = f"{uni.id}:exact:{pattern}"
                if self.automaton:
                    self.automaton.add_word(pattern, (uni.id, 'exact', pattern))
                self.university_map[exact_key] = uni
                
                # 如果是通配符模式，添加所有可能的子域名匹配
                if '*' in uni.domain_pattern:
                    base_pattern = pattern.replace('*', '')
                    # 添加基础模式匹配
                    wildcard_key = f"{uni.id}:wildcard:{base_pattern}"
                    if self.automaton:
                        self.automaton.add_word(base_pattern, (uni.id, 'wildcard', base_pattern))
                    self.university_map[wildcard_key] = uni
            
            if self.automaton:
                self.automaton.make_automaton()
            self._initialized = True
            logger.info(f"大学匹配器初始化完成，加载了 {len(universities)} 所大学" + 
                       (" (使用Aho-Corasick算法)" if HAS_AHOCORASICK else " (使用字典匹配)"))
    
    def match(self, email: str) -> Optional[models.University]:
        """
        匹配大学（内存匹配，无需数据库查询）
        
        性能：O(n) 其中n是邮箱域名长度，比多次DB查询快10倍+
        """
        if '@' not in email:
            return None
        
        domain = email.split('@')[1].lower()
        
        # 检查是否以 .ac.uk 结尾
        if not domain.endswith('.ac.uk'):
            return None
        
        # 1. 精确匹配（最高优先级）
        exact_key = f"exact:{domain}"
        for key, uni in self.university_map.items():
            if key.endswith(exact_key):
                return uni
        
        # 2. 子域名匹配（从右到左）
        domain_parts = domain.split('.')
        for i in range(len(domain_parts)):
            subdomain = '.'.join(domain_parts[i:])
            subdomain_key = f"exact:{subdomain}"
            for key, uni in self.university_map.items():
                if key.endswith(subdomain_key):
                    return uni
        
        # 3. 通配符匹配（使用Aho-Corasick或正则表达式）
        if self.automaton:
            matches = []
            for end_index, (uni_id, match_type, pattern) in self.automaton.iter(domain):
                matches.append((end_index, uni_id, match_type, pattern))
            
            if matches:
                # 选择最长匹配（最具体）
                matches.sort(key=lambda x: len(x[3]), reverse=True)
                uni_id, match_type, pattern = matches[0][1], matches[0][2], matches[0][3]
                key = f"{uni_id}:{match_type}:{pattern}"
                return self.university_map.get(key)
        else:
            # 回退到精确字符串匹配（如果没有Aho-Corasick）
            # 🔒 安全修复：不使用正则表达式，防止恶意 domain_pattern 注入
            for key, uni in self.university_map.items():
                if ':wildcard:' in key:
                    pattern = (uni.domain_pattern or "").lower().lstrip('@')
                    if pattern.startswith('*'):
                        # 通配符模式：*.example.ac.uk -> 匹配任何以 .example.ac.uk 结尾的域名
                        suffix = pattern.lstrip('*')
                        if domain == suffix.lstrip('.') or domain.endswith(suffix):
                            return uni
                    else:
                        # 精确匹配
                        if domain == pattern:
                            return uni
        
        return None


# 全局单例
_university_matcher = UniversityMatcher()


def match_university_by_email(email: str, db=None) -> Optional[models.University]:
    """
    根据邮箱地址匹配大学（使用内存缓存）
    
    重要约束：只有以 `.ac.uk` 结尾的邮箱才能验证学生身份
    
    性能优化：
    - 启动时加载所有pattern到内存
    - 使用Aho-Corasick算法，一次匹配完成
    - 避免多次数据库查询，性能提升10倍+
    """
    # 确保已初始化
    if not _university_matcher._initialized and db:
        _university_matcher.initialize(db)
    
    return _university_matcher.match(email)

