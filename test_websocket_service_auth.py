#!/usr/bin/env python3
"""
测试客服WebSocket认证
"""

import asyncio
import websockets
import requests
import json

async def test_service_websocket():
    """测试客服WebSocket连接"""
    
    print("🧪 测试客服WebSocket认证")
    print("=" * 50)
    
    # 1. 先登录获取Cookie
    print("1. 客服登录...")
    login_data = {
        "cs_id": "CS8888",
        "password": "password123"
    }
    
    session = requests.Session()
    response = session.post(
        "https://api.link2ur.com/api/auth/service/login",
        json=login_data
    )
    
    if response.status_code != 200:
        print(f"❌ 登录失败: {response.status_code}")
        print(f"响应: {response.text}")
        return
    
    print("✅ 登录成功")
    
    # 2. 获取Cookie
    cookies = session.cookies.get_dict()
    print(f"获取到的Cookie: {cookies}")
    
    # 3. 测试WebSocket连接
    print("\n2. 测试WebSocket连接...")
    
    # 构建WebSocket URL
    ws_url = "wss://api.link2ur.com/ws/chat/CS8888"
    
    try:
        # 注意：websockets库可能不支持直接传递cookies
        # 我们需要手动构建Cookie头
        cookie_header = "; ".join([f"{k}={v}" for k, v in cookies.items()])
        
        print(f"WebSocket URL: {ws_url}")
        print(f"Cookie Header: {cookie_header}")
        
        # 尝试连接WebSocket
        async with websockets.connect(
            ws_url,
            extra_headers={"Cookie": cookie_header}
        ) as websocket:
            print("✅ WebSocket连接成功")
            
            # 发送测试消息
            test_message = {
                "type": "test",
                "message": "Hello from service"
            }
            
            await websocket.send(json.dumps(test_message))
            print("✅ 消息发送成功")
            
            # 等待响应
            try:
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                print(f"✅ 收到响应: {response}")
            except asyncio.TimeoutError:
                print("⚠️ 未收到响应（超时）")
            
    except Exception as e:
        print(f"❌ WebSocket连接失败: {e}")
        print(f"错误类型: {type(e).__name__}")

def test_http_api():
    """测试HTTP API是否正常"""
    print("\n3. 测试HTTP API...")
    
    try:
        response = requests.get("https://api.link2ur.com/api/health")
        print(f"健康检查: {response.status_code}")
        
        response = requests.get("https://api.link2ur.com/")
        print(f"根路径: {response.status_code}")
        
    except Exception as e:
        print(f"❌ HTTP API测试失败: {e}")

if __name__ == "__main__":
    print("开始测试客服WebSocket认证...")
    
    # 测试HTTP API
    test_http_api()
    
    # 测试WebSocket
    asyncio.run(test_service_websocket())
    
    print("\n测试完成")
