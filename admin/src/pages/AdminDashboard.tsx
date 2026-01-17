import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Layout, Menu, Button, Avatar, Dropdown, message, Typography } from 'antd';
import {
  DashboardOutlined,
  UserOutlined,
  TeamOutlined,
  ShopOutlined,
  MessageOutlined,
  SettingOutlined,
  LogoutOutlined,
  MenuFoldOutlined,
  MenuUnfoldOutlined,
  FileTextOutlined,
  GiftOutlined,
  TrophyOutlined,
  PictureOutlined,
  ExclamationCircleOutlined,
} from '@ant-design/icons';
import type { MenuProps } from 'antd';
import { API_BASE_URL, API_ENDPOINTS, MAIN_SITE_URL } from '../config';

const { Header, Sider, Content } = Layout;
const { Title } = Typography;

type MenuItem = Required<MenuProps>['items'][number];

/**
 * 管理后台主页
 * 
 * TODO: 从 frontend/src/pages/AdminDashboard.tsx 迁移完整功能
 * 当前为骨架版本，需要迁移以下功能：
 * - 用户管理
 * - 管理员管理
 * - 客服管理
 * - 任务达人管理
 * - 论坛管理
 * - 跳蚤市场管理
 * - 邀请码管理
 * - Banner 管理
 * - 排行榜管理
 * - 争议处理
 * - 系统设置
 */
const AdminDashboard: React.FC = () => {
  const navigate = useNavigate();
  const [collapsed, setCollapsed] = useState(false);
  const [selectedKey, setSelectedKey] = useState('dashboard');

  // 菜单项
  const menuItems: MenuItem[] = [
    {
      key: 'dashboard',
      icon: <DashboardOutlined />,
      label: '仪表盘',
    },
    {
      key: 'users',
      icon: <UserOutlined />,
      label: '用户管理',
    },
    {
      key: 'admins',
      icon: <TeamOutlined />,
      label: '管理员管理',
    },
    {
      key: 'customer-service',
      icon: <MessageOutlined />,
      label: '客服管理',
    },
    {
      key: 'task-experts',
      icon: <TeamOutlined />,
      label: '任务达人',
    },
    {
      key: 'forum',
      icon: <FileTextOutlined />,
      label: '论坛管理',
    },
    {
      key: 'flea-market',
      icon: <ShopOutlined />,
      label: '跳蚤市场',
    },
    {
      key: 'invitation-codes',
      icon: <GiftOutlined />,
      label: '邀请码',
    },
    {
      key: 'banners',
      icon: <PictureOutlined />,
      label: 'Banner 管理',
    },
    {
      key: 'leaderboards',
      icon: <TrophyOutlined />,
      label: '排行榜管理',
    },
    {
      key: 'disputes',
      icon: <ExclamationCircleOutlined />,
      label: '争议处理',
    },
    {
      key: 'settings',
      icon: <SettingOutlined />,
      label: '系统设置',
    },
  ];

  // 登出
  const handleLogout = async () => {
    try {
      await fetch(`${API_BASE_URL}${API_ENDPOINTS.ADMIN_LOGOUT}`, {
        method: 'POST',
        credentials: 'include',
      });
      message.success('已退出登录');
      navigate('/login');
    } catch (error) {
      console.error('登出失败:', error);
      navigate('/login');
    }
  };

  // 用户下拉菜单
  const userMenuItems: MenuProps['items'] = [
    {
      key: 'main-site',
      icon: <UserOutlined />,
      label: '访问主站',
      onClick: () => window.open(MAIN_SITE_URL, '_blank'),
    },
    {
      type: 'divider',
    },
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: '退出登录',
      onClick: handleLogout,
    },
  ];

  // 渲染内容
  const renderContent = () => {
    switch (selectedKey) {
      case 'dashboard':
        return (
          <div style={{ padding: 24 }}>
            <Title level={4}>仪表盘</Title>
            <p style={{ color: '#666' }}>
              欢迎使用 LinkU 管理后台。请从左侧菜单选择功能模块。
            </p>
            <div style={{ 
              marginTop: 24,
              padding: 24,
              background: '#fffbe6',
              border: '1px solid #ffe58f',
              borderRadius: 8
            }}>
              <strong>⚠️ 开发提示</strong>
              <p style={{ margin: '8px 0 0' }}>
                此为管理后台骨架版本，需要从 <code>frontend/src/pages/AdminDashboard.tsx</code> 迁移完整功能。
              </p>
            </div>
          </div>
        );
      default:
        return (
          <div style={{ padding: 24 }}>
            <Title level={4}>{menuItems.find(m => m?.key === selectedKey)?.label as string || '功能模块'}</Title>
            <p style={{ color: '#666' }}>
              该功能模块正在开发中，请稍后...
            </p>
          </div>
        );
    }
  };

  return (
    <Layout style={{ minHeight: '100vh' }}>
      {/* 侧边栏 */}
      <Sider 
        trigger={null} 
        collapsible 
        collapsed={collapsed}
        style={{
          background: '#001529',
          boxShadow: '2px 0 8px rgba(0,0,0,0.15)'
        }}
      >
        <div style={{
          height: 64,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'rgba(255,255,255,0.1)',
          margin: 16,
          borderRadius: 8
        }}>
          <span style={{ 
            color: '#fff', 
            fontSize: collapsed ? 16 : 20,
            fontWeight: 'bold'
          }}>
            {collapsed ? 'LU' : 'LinkU Admin'}
          </span>
        </div>
        <Menu
          theme="dark"
          mode="inline"
          selectedKeys={[selectedKey]}
          items={menuItems}
          onClick={({ key }) => setSelectedKey(key)}
        />
      </Sider>

      <Layout>
        {/* 顶部导航 */}
        <Header style={{
          padding: '0 24px',
          background: '#fff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          boxShadow: '0 1px 4px rgba(0,0,0,0.1)'
        }}>
          <Button
            type="text"
            icon={collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />}
            onClick={() => setCollapsed(!collapsed)}
            style={{ fontSize: 16, width: 48, height: 48 }}
          />
          
          <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
            <div style={{ cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 8 }}>
              <Avatar style={{ background: '#1890ff' }} icon={<UserOutlined />} />
              <span>管理员</span>
            </div>
          </Dropdown>
        </Header>

        {/* 内容区 */}
        <Content style={{
          margin: 24,
          padding: 24,
          background: '#fff',
          borderRadius: 8,
          minHeight: 'calc(100vh - 64px - 48px)'
        }}>
          {renderContent()}
        </Content>
      </Layout>
    </Layout>
  );
};

export default AdminDashboard;
