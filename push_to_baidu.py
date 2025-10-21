#!/usr/bin/env python3
"""
简化的百度URL推送脚本
"""

import requests
import json

def push_urls_to_baidu():
    """推送URL到百度"""
    
    # 百度推送配置
    SITE = "https://www.link2ur.com"
    TOKEN = "TD7frdY0ZCi4irYj"
    PUSH_URL = "http://data.zz.baidu.com/urls"
    
    # 要推送的URL列表
    urls = [
        "https://www.link2ur.com/",
        "https://www.link2ur.com/tasks",
        "https://www.link2ur.com/partners",
        "https://www.link2ur.com/about", 
        "https://www.link2ur.com/contact"
    ]
    
    # 准备推送数据
    url_text = "\n".join(urls)
    
    # 设置请求参数
    params = {
        "site": SITE,
        "token": TOKEN
    }
    
    headers = {
        "Content-Type": "text/plain"
    }
    
    print("百度URL推送工具")
    print("=" * 40)
    print(f"网站: {SITE}")
    print(f"推送URL数量: {len(urls)}")
    print(f"推送地址: {PUSH_URL}")
    print("-" * 40)
    
    try:
        # 发送推送请求
        response = requests.post(
            PUSH_URL,
            params=params,
            data=url_text,
            headers=headers,
            timeout=30
        )
        
        print(f"响应状态码: {response.status_code}")
        
        if response.status_code == 200:
            result = response.json()
            print("✅ 推送成功!")
            print(f"成功推送: {result.get('success', 0)} 个URL")
            print(f"剩余配额: {result.get('remain', 0)} 个URL")
            
            if result.get('not_same_site'):
                print(f"⚠️  非本站URL: {result['not_same_site']}")
                
            if result.get('not_valid'):
                print(f"❌ 无效URL: {result['not_valid']}")
                
            return result
        else:
            print(f"❌ 推送失败，状态码: {response.status_code}")
            print(f"响应内容: {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ 推送过程中发生错误: {e}")
        return None

if __name__ == "__main__":
    push_urls_to_baidu()
