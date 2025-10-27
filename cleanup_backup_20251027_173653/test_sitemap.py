#!/usr/bin/env python3
"""
测试sitemap.xml访问和格式
"""

import requests
import xml.etree.ElementTree as ET
from datetime import datetime

def test_sitemap_access():
    """测试sitemap.xml访问"""
    print("测试sitemap.xml访问和格式")
    print("=" * 50)
    
    sitemap_url = "https://www.link2ur.com/sitemap.xml"
    
    try:
        print(f"正在访问: {sitemap_url}")
        response = requests.get(sitemap_url, timeout=10)
        
        print(f"状态码: {response.status_code}")
        print(f"Content-Type: {response.headers.get('content-type', 'Not set')}")
        print(f"Content-Length: {len(response.content)} bytes")
        
        if response.status_code == 200:
            content_type = response.headers.get('content-type', '').lower()
            
            if 'xml' in content_type or 'text/xml' in content_type:
                print("正确返回XML格式")
                
                # 验证XML格式
                try:
                    root = ET.fromstring(response.text)
                    print(f"XML格式有效，根元素: {root.tag}")
                    
                    # 检查命名空间
                    if 'sitemap' in root.tag:
                        print("正确的sitemap命名空间")
                        
                        # 统计URL数量
                        urls = root.findall('.//{http://www.sitemaps.org/schemas/sitemap/0.9}url')
                        print(f"包含 {len(urls)} 个URL")
                        
                        # 显示URL列表
                        print("\n📋 URL列表:")
                        for i, url in enumerate(urls, 1):
                            loc = url.find('{http://www.sitemaps.org/schemas/sitemap/0.9}loc')
                            if loc is not None:
                                print(f"  {i}. {loc.text}")
                        
                    else:
                        print("不是有效的sitemap格式")
                        
                except ET.ParseError as e:
                    print(f"XML解析错误: {e}")
                    print("内容预览:")
                    print(response.text[:500])
                    
            elif 'html' in content_type:
                print("返回HTML格式 - 路由配置问题")
                print("内容预览:")
                print(response.text[:500])
            else:
                print(f"未知内容类型: {content_type}")
                print("内容预览:")
                print(response.text[:200])
                
        else:
            print(f"访问失败，状态码: {response.status_code}")
            
    except requests.exceptions.RequestException as e:
        print(f"请求失败: {e}")
    except Exception as e:
        print(f"其他错误: {e}")

def test_robots_txt():
    """测试robots.txt访问"""
    print("\n测试robots.txt访问")
    print("-" * 30)
    
    robots_url = "https://www.link2ur.com/robots.txt"
    
    try:
        response = requests.get(robots_url, timeout=10)
        print(f"状态码: {response.status_code}")
        print(f"Content-Type: {response.headers.get('content-type', 'Not set')}")
        
        if response.status_code == 200:
            print("robots.txt访问正常")
            print("内容:")
            print(response.text)
        else:
            print(f"robots.txt访问失败: {response.status_code}")
            
    except Exception as e:
        print(f"robots.txt测试失败: {e}")

def test_google_search_console():
    """提供Google Search Console测试建议"""
    print("\nGoogle Search Console测试建议")
    print("-" * 40)
    print("1. 访问: https://search.google.com/search-console")
    print("2. 添加属性: https://www.link2ur.com")
    print("3. 验证网站所有权")
    print("4. 在'站点地图'部分提交: https://www.link2ur.com/sitemap.xml")
    print("5. 使用'URL检查'工具测试sitemap.xml")

if __name__ == "__main__":
    test_sitemap_access()
    test_robots_txt()
    test_google_search_console()
    
    print("\n" + "=" * 50)
    print("修复说明:")
    print("1. 已更新vercel.json路由配置")
    print("2. 添加了sitemap.xml和robots.txt的专门路由")
    print("3. 重新部署后sitemap.xml应该返回正确的XML格式")
    print("4. 如果仍有问题，请检查Vercel部署状态")
