import React, { useState, useEffect } from 'react';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { Card, Row, Col, Typography, Space, Avatar, Divider } from 'antd';
import { 
  TeamOutlined, 
  RocketOutlined, 
  HeartOutlined, 
  GlobalOutlined,
  TrophyOutlined,
  BulbOutlined,
  SafetyOutlined
} from '@ant-design/icons';
import { fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead } from '../api';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import './About.css';

const { Title, Paragraph, Text } = Typography;

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

const About: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings, setSystemSettings] = useState({});

  // 加载用户数据和通知
  useEffect(() => {
    const loadUserData = async () => {
      try {
        const userData = await fetchCurrentUser();
        console.log('获取用户资料成功:', userData);
        setUser(userData);
        
        // 加载通知数据
        if (userData) {
          try {
            const [notificationsData, unreadCountData] = await Promise.all([
              getNotificationsWithRecentRead(10),
              getUnreadNotificationCount()
            ]);
            setNotifications(notificationsData);
            setUnreadCount(unreadCountData.unread_count);
          } catch (error) {
            console.log('获取通知失败:', error);
          }
        }
      } catch (error: any) {
        console.log('获取用户资料失败:', error);
        setUser(null);
      }
    };
    
    loadUserData();
  }, []);

  // 标记通知为已读
  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markNotificationRead(notificationId);
      setNotifications(prev => 
        prev.map(notif => 
          notif.id === notificationId 
            ? { ...notif, is_read: 1 }
            : notif
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
      console.log('通知标记为已读成功');
    } catch (error) {
      console.error('标记通知已读失败:', error);
      alert(t('notificationPanel.markAsReadFailed'));
    }
  };

  // 标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setNotifications(prev => 
        prev.map(notif => ({ ...notif, is_read: 1 }))
      );
      setUnreadCount(0);
      console.log('所有通知标记为已读成功');
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      alert(t('notificationPanel.markAllReadFailed'));
    }
  };

  const teamMembers = [
    {
      name: t('about.teamMembers.founder.name'),
      role: t('about.teamMembers.founder.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhangzixiong&gender=male",
      description: t('about.teamMembers.founder.description')
    },
    {
      name: t('about.teamMembers.cto.name'),
      role: t('about.teamMembers.cto.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=li",
      description: t('about.teamMembers.cto.description')
    },
    {
      name: t('about.teamMembers.coo.name'),
      role: t('about.teamMembers.coo.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=wang",
      description: t('about.teamMembers.coo.description')
    },
    {
      name: t('about.teamMembers.pm.name'),
      role: t('about.teamMembers.pm.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhao",
      description: t('about.teamMembers.pm.description')
    }
  ];

  const values = [
    {
      icon: <HeartOutlined className="value-icon" />,
      title: t('about.userFirst'),
      description: t('about.userFirstDesc')
    },
    {
      icon: <BulbOutlined className="value-icon" />,
      title: t('about.innovationDriven'),
      description: t('about.innovationDrivenDesc')
    },
    {
      icon: <SafetyOutlined className="value-icon" />,
      title: t('about.safeReliable'),
      description: t('about.safeReliableDesc')
    },
    {
      icon: <TeamOutlined className="value-icon" />,
      title: t('about.teamCollaboration'),
      description: t('about.teamCollaborationDesc')
    }
  ];

  const stats = [
    { number: "50,000+", label: t('about.registeredUsers') },
    { number: "100,000+", label: t('about.completedTasks') },
    { number: "98%", label: t('about.userSatisfaction') },
    { number: "24/7", label: t('about.onlineService') }
  ];

  return (
    <div className="about-page">
      {/* 顶部导航栏 */}
      <header style={{position: 'fixed', top: 0, left: 0, width: '100%', background: '#fff', zIndex: 100, boxShadow: '0 2px 8px #e6f7ff'}}>
        <div style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 60, maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
          {/* Logo */}
          <div 
            style={{
              fontWeight: 'bold', 
              fontSize: 24, 
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)', 
              WebkitBackgroundClip: 'text', 
              WebkitTextFillColor: 'transparent',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0
            }}
            onClick={() => navigate('/')}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.05)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #2563eb, #7c3aed)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #8b5cf6)';
              (e.currentTarget.style as any).webkitBackgroundClip = 'text';
              (e.currentTarget.style as any).webkitTextFillColor = 'transparent';
            }}
          >
            Link²Ur
          </div>
          
          {/* 语言切换器、通知按钮和汉堡菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <LanguageSwitcher />
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  // await logout();
                } catch (error) {
                  console.log('登出请求失败:', error);
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>
      
      {/* 占位，防止内容被导航栏遮挡 */}
      <div style={{height: 60}} />
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      {/* 英雄区域 */}
      <div className="hero-section">
        <div className="hero-content">
          <Title level={1} className="hero-title">
            {t('about.title')}
          </Title>
          <Paragraph className="hero-subtitle">
            {t('about.subtitle')}
          </Paragraph>
          <Paragraph className="hero-description">
            {t('about.missionText')}
          </Paragraph>
        </div>
      </div>

      {/* 统计数据 */}
      <div className="stats-section">
        <Row gutter={[32, 32]} justify="center">
          {stats.map((stat, index) => (
            <Col xs={12} sm={6} key={index}>
              <div className="stat-item">
                <div className="stat-number">{stat.number}</div>
                <div className="stat-label">{stat.label}</div>
              </div>
            </Col>
          ))}
        </Row>
      </div>

      {/* 我们的故事 */}
      <div className="story-section">
        <Row gutter={[48, 48]} align="middle">
          <Col xs={24} lg={12}>
            <div className="story-content">
              <Title level={2}>我们的故事</Title>
              <Paragraph>
                2023年，一群充满激情的年轻人聚在一起，他们看到了传统工作模式的局限性，
                也看到了数字时代带来的无限可能。于是，Link²Ur 应运而生。
              </Paragraph>
              <Paragraph>
                我们相信，每个人都有独特的技能和才华，每个任务都值得被认真对待。
                通过我们的平台，技能者可以找到合适的工作机会，需求方可以获得专业的服务，
                实现真正的双赢。
              </Paragraph>
              <Paragraph>
                从最初的小团队到现在的规模，我们始终坚持初心：
                <Text strong> 让工作更简单，让生活更美好。</Text>
              </Paragraph>
            </div>
          </Col>
          <Col xs={24} lg={12}>
            <div className="story-image">
              <img 
                src="https://images.unsplash.com/photo-1522071820081-009f0129c71c?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80" 
                alt={t('about.ourTeam')} 
                className="story-img"
              />
            </div>
          </Col>
        </Row>
      </div>

      {/* 我们的价值观 */}
      <div className="values-section">
        <div className="section-header">
          <Title level={2}>{t('about.valuesSection.title')}</Title>
          <Paragraph className="section-subtitle">
            {t('about.valuesSection.subtitle')}
          </Paragraph>
        </div>
        <Row gutter={[32, 32]}>
          {values.map((value, index) => (
            <Col xs={24} sm={12} lg={6} key={index}>
              <Card className="value-card" hoverable>
                <div className="value-content">
                  {value.icon}
                  <Title level={4} className="value-title">{value.title}</Title>
                  <Paragraph className="value-description">{value.description}</Paragraph>
                </div>
              </Card>
            </Col>
          ))}
        </Row>
      </div>

      {/* 我们的团队 */}
      <div className="team-section">
        <div className="section-header">
          <Title level={2}>{t('about.teamSection.title')}</Title>
          <Paragraph className="section-subtitle">
            {t('about.teamSection.subtitle')}
          </Paragraph>
        </div>
        <Row gutter={[32, 32]} justify="center">
          {teamMembers.map((member, index) => (
            <Col xs={24} sm={12} lg={6} key={index}>
              <Card className="team-card" hoverable>
                <div className="team-member">
                  <Avatar size={80} src={member.avatar} className="member-avatar" />
                  <Title level={4} className="member-name">{member.name}</Title>
                  <Text className="member-role">{member.role}</Text>
                  <Paragraph className="member-description">{member.description}</Paragraph>
                </div>
              </Card>
            </Col>
          ))}
        </Row>
      </div>

      {/* 我们的愿景 */}
      <div className="vision-section">
        <Row gutter={[48, 48]} align="middle">
          <Col xs={24} lg={12}>
            <div className="vision-image">
              <img 
                src="https://images.unsplash.com/photo-1551434678-e076c223a692?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80" 
                alt={t('about.vision')} 
                className="vision-img"
              />
            </div>
          </Col>
          <Col xs={24} lg={12}>
            <div className="vision-content">
              <Title level={2}>{t('about.visionSection.title')}</Title>
              <Space direction="vertical" size="large" style={{ width: '100%' }}>
                <div className="vision-item">
                  <RocketOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>{t('about.visionSection.goals.platform.title')}</Title>
                    <Paragraph>{t('about.visionSection.goals.platform.description')}</Paragraph>
                  </div>
                </div>
                <div className="vision-item">
                  <GlobalOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>{t('about.visionSection.goals.workStyle.title')}</Title>
                    <Paragraph>{t('about.visionSection.goals.workStyle.description')}</Paragraph>
                  </div>
                </div>
                <div className="vision-item">
                  <TrophyOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>{t('about.visionSection.goals.socialValue.title')}</Title>
                    <Paragraph>{t('about.visionSection.goals.socialValue.description')}</Paragraph>
                  </div>
                </div>
              </Space>
            </div>
          </Col>
        </Row>
      </div>

      {/* 页脚 */}
      <Footer />
      
      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
      />
    </div>
  );
};

export default About;
