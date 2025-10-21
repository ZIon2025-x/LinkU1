#!/usr/bin/env python3
"""
自动百度URL推送系统
定期推送网站URL到百度搜索引擎
"""

import requests
import json
import time
from datetime import datetime
import schedule

class AutoBaiduPusher:
    def __init__(self):
        self.site = "https://www.link2ur.com"
        self.token = "TD7frdY0ZCi4irYj"
        self.push_url = "http://data.zz.baidu.com/urls"
        
    def get_sitemap_urls(self):
        """从sitemap.xml获取URL列表"""
        try:
            sitemap_url = f"{self.site}/sitemap.xml"
            response = requests.get(sitemap_url, timeout=30)
            
            if response.status_code == 200:
                import xml.etree.ElementTree as ET
                root = ET.fromstring(response.text)
                
                urls = []
                for url in root.findall('.//{http://www.sitemaps.org/schemas/sitemap/0.9}url'):
                    loc = url.find('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')
                    if loc is not None:
                        urls.append(loc.text)
                
                return urls
            else:
                print(f"获取sitemap失败，状态码: {response.status_code}")
                return []
                
        except Exception as e:
            print(f"获取sitemap时发生错误: {e}")
            return []
    
    def push_urls(self, urls):
        """推送URL到百度"""
        if not urls:
            print("没有URL需要推送")
            return None
            
        url_text = "\n".join(urls)
        
        params = {
            "site": self.site,
            "token": self.token
        }
        
        headers = {
            "Content-Type": "text/plain"
        }
        
        try:
            print(f"正在推送 {len(urls)} 个URL到百度...")
            
            response = requests.post(
                self.push_url,
                params=params,
                data=url_text,
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ 推送成功! 成功: {result.get('success', 0)}, 剩余: {result.get('remain', 0)}")
                return result
            else:
                print(f"❌ 推送失败，状态码: {response.status_code}")
                return None
                
        except Exception as e:
            print(f"❌ 推送错误: {e}")
            return None
    
    def daily_push(self):
        """每日推送任务"""
        print(f"\n开始每日推送任务 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 50)
        
        # 获取sitemap中的URL
        urls = self.get_sitemap_urls()
        
        if urls:
            result = self.push_urls(urls)
            
            # 记录推送结果
            log_entry = {
                "timestamp": datetime.now().isoformat(),
                "urls_count": len(urls),
                "result": result
            }
            
            with open("baidu_push_log.json", "a", encoding="utf-8") as f:
                f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")
                
            print("推送记录已保存")
        else:
            print("没有获取到URL，跳过推送")
        
        print("=" * 50)
    
    def manual_push(self):
        """手动推送主要页面"""
        print("手动推送主要页面")
        print("-" * 30)
        
        main_urls = [
            "https://www.link2ur.com/",
            "https://www.link2ur.com/tasks",
            "https://www.link2ur.com/partners",
            "https://www.link2ur.com/about",
            "https://www.link2ur.com/contact"
        ]
        
        result = self.push_urls(main_urls)
        return result

def main():
    """主函数"""
    pusher = AutoBaiduPusher()
    
    print("百度URL自动推送系统")
    print("=" * 40)
    print("1. 手动推送主要页面")
    print("2. 从sitemap推送所有页面")
    print("3. 启动定时推送（每日一次）")
    print("4. 退出")
    
    while True:
        choice = input("\n请选择操作 (1-4): ").strip()
        
        if choice == "1":
            pusher.manual_push()
        elif choice == "2":
            urls = pusher.get_sitemap_urls()
            if urls:
                pusher.push_urls(urls)
            else:
                print("无法获取sitemap中的URL")
        elif choice == "3":
            print("启动定时推送，按Ctrl+C停止...")
            schedule.every().day.at("09:00").do(pusher.daily_push)
            
            while True:
                schedule.run_pending()
                time.sleep(60)
        elif choice == "4":
            print("退出程序")
            break
        else:
            print("无效选择，请重新输入")

if __name__ == "__main__":
    main()
