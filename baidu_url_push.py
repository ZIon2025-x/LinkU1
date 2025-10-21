#!/usr/bin/env python3
"""
百度URL推送工具
自动将网站URL推送到百度搜索引擎
"""

import requests
import json
from datetime import datetime
import time

class BaiduUrlPusher:
    def __init__(self, site, token):
        """
        初始化百度URL推送器
        
        Args:
            site (str): 网站域名，如 https://www.link2ur.com
            token (str): 百度推送token
        """
        self.site = site
        self.token = token
        self.push_url = "http://data.zz.baidu.com/urls"
        self.session = requests.Session()
        
    def push_urls(self, urls):
        """
        推送URL列表到百度
        
        Args:
            urls (list): 要推送的URL列表
            
        Returns:
            dict: 推送结果
        """
        if not urls:
            return {"error": "URL列表为空"}
            
        # 准备推送数据
        url_text = "\n".join(urls)
        
        # 设置请求参数
        params = {
            "site": self.site,
            "token": self.token
        }
        
        headers = {
            "Content-Type": "text/plain"
        }
        
        try:
            print(f"正在推送 {len(urls)} 个URL到百度...")
            print(f"推送地址: {self.push_url}")
            print(f"网站: {self.site}")
            print("-" * 50)
            
            # 发送推送请求
            response = self.session.post(
                self.push_url,
                params=params,
                data=url_text,
                headers=headers,
                timeout=30
            )
            
            print(f"响应状态码: {response.status_code}")
            
            if response.status_code == 200:
                result = response.json()
                print("推送成功!")
                print(f"成功推送: {result.get('success', 0)} 个URL")
                print(f"剩余配额: {result.get('remain', 0)} 个URL")
                
                if result.get('not_same_site'):
                    print(f"非本站URL: {result['not_same_site']}")
                    
                if result.get('not_valid'):
                    print(f"无效URL: {result['not_valid']}")
                    
                return result
            else:
                print(f"推送失败，状态码: {response.status_code}")
                print(f"响应内容: {response.text}")
                return {"error": f"推送失败，状态码: {response.status_code}"}
                
        except Exception as e:
            print(f"推送过程中发生错误: {e}")
            return {"error": str(e)}
    
    def push_from_sitemap(self, sitemap_url):
        """
        从sitemap.xml获取URL并推送
        
        Args:
            sitemap_url (str): sitemap.xml的URL
        """
        try:
            print(f"正在获取sitemap: {sitemap_url}")
            response = self.session.get(sitemap_url, timeout=30)
            
            if response.status_code == 200:
                # 解析sitemap.xml
                import xml.etree.ElementTree as ET
                root = ET.fromstring(response.text)
                
                # 提取URL
                urls = []
                for url in root.findall('.//{http://www.sitemaps.org/schemas/sitemap/0.9}url'):
                    loc = url.find('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')
                    if loc is not None:
                        urls.append(loc.text)
                
                print(f"从sitemap获取到 {len(urls)} 个URL")
                return self.push_urls(urls)
            else:
                print(f"获取sitemap失败，状态码: {response.status_code}")
                return {"error": "获取sitemap失败"}
                
        except Exception as e:
            print(f"处理sitemap时发生错误: {e}")
            return {"error": str(e)}

def main():
    """主函数"""
    print("百度URL推送工具")
    print("=" * 50)
    
    # 配置信息
    SITE = "https://www.link2ur.com"
    TOKEN = "TD7frdY0ZCi4irYj"
    
    # 创建推送器
    pusher = BaiduUrlPusher(SITE, TOKEN)
    
    # 方法1: 从sitemap推送
    print("\n方法1: 从sitemap推送")
    sitemap_url = f"{SITE}/sitemap.xml"
    result = pusher.push_from_sitemap(sitemap_url)
    
    if result.get("error"):
        print(f"从sitemap推送失败: {result['error']}")
        
        # 方法2: 手动推送主要页面
        print("\n方法2: 手动推送主要页面")
        main_urls = [
            "https://www.link2ur.com/",
            "https://www.link2ur.com/tasks",
            "https://www.link2ur.com/partners", 
            "https://www.link2ur.com/about",
            "https://www.link2ur.com/contact"
        ]
        
        result = pusher.push_urls(main_urls)
    
    # 保存推送记录
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "site": SITE,
        "result": result
    }
    
    with open("baidu_push_log.json", "a", encoding="utf-8") as f:
        f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
    
    print(f"\n推送记录已保存到 baidu_push_log.json")
    print("=" * 50)

if __name__ == "__main__":
    main()
