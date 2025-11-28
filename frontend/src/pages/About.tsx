import React, { useState, useEffect } from 'react';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { Card, Row, Col, Typography, Space, Avatar, Divider, Button } from 'antd';
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
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
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
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
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
          }
        }
      } catch (error: any) {
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
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      alert(t('notificationPanel.markAllReadFailed'));
    }
  };

  const teamMembers = [
    {
      name: t('about.teamMembers.founder.name'),
      role: t('about.teamMembers.founder.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhangzixiong&gender=male&skinColor=ffdbb4",
      description: t('about.teamMembers.founder.description')
    },
    {
      name: t('about.teamMembers.cto.name'),
      role: t('about.teamMembers.cto.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=li&skinColor=ffdbb4",
      description: t('about.teamMembers.cto.description')
    },
    {
      name: t('about.teamMembers.coo.name'),
      role: t('about.teamMembers.coo.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=liushiying&skinColor=ffdbb4",
      description: t('about.teamMembers.coo.description')
    },
    {
      name: t('about.teamMembers.pm.name'),
      role: t('about.teamMembers.pm.role'),
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=girlfriend&skinColor=ffdbb4",
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
    { number: "100+", label: t('about.registeredUsers') },
    { number: "50+", label: t('about.completedTasks') },
    { number: "97%", label: t('about.userSatisfaction') },
    { number: t('about.available'), label: t('about.onlineService') }
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
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
              unreadCount={messageUnreadCount}
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
      
      {/* 英雄区域 - 重新设计 */}
      <section className="hero-section" style={{
        backgroundImage: 'url(/static/background.jpg)',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
        minHeight: '100vh',
        padding: '80px 0',
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        {/* 背景遮罩层 */}
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          background: 'rgba(0, 0, 0, 0.4)',
          pointerEvents: 'none'
        }} />
        
        <div style={{maxWidth: 1200, width: '100%', padding: '0 24px', position: 'relative', zIndex: 2}}>
          <h1 className="hero-title" style={{
            fontSize: '48px',
            fontWeight: '800',
            marginBottom: '24px',
            color: '#fff',
            textShadow: '0 4px 8px rgba(0,0,0,0.3)',
            lineHeight: '1.2'
          }}>
            {t('about.title')}
            <br />
            <span style={{color: '#FFD700'}}>{t('about.subtitle')}</span>
          </h1>
          
          <p className="hero-subtitle" style={{
            fontSize: '20px',
            color: 'rgba(255,255,255,0.9)',
            marginBottom: '40px',
            maxWidth: '600px',
            margin: '0 auto 40px',
            lineHeight: '1.6'
          }}>
            {t('about.missionText')}
          </p>
        </div>
      </section>

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
              <Title level={2}>{t('about.ourStory')}</Title>
              <Paragraph>
                {t('about.ourStoryText1')}
              </Paragraph>
              <Paragraph>
                {t('about.ourStoryText2')}
              </Paragraph>
              <Paragraph>
                {t('about.ourStoryText3')}
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
        <Row gutter={[16, 16]} className="values-row">
          {values.map((value, index) => (
            <Col xs={12} sm={12} lg={6} key={index}>
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
        <Row gutter={[16, 16]} justify="center" className="team-row">
          {teamMembers.map((member, index) => (
            <Col xs={12} sm={12} lg={6} key={index}>
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
        
        {/* 加入我们按钮 */}
        <div style={{ textAlign: 'center', marginTop: '48px' }}>
          <Button
            type="primary"
            size="large"
            onClick={() => navigate('/join-us')}
            style={{
              height: '48px',
              padding: '0 32px',
              fontSize: '16px',
              fontWeight: '600',
              background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
              border: 'none',
              borderRadius: '24px',
              boxShadow: '0 4px 12px rgba(59, 130, 246, 0.4)',
              transition: 'all 0.3s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 6px 16px rgba(59, 130, 246, 0.5)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.4)';
            }}
          >
            🤝 {t('hamburgerMenu.joinUs')}
          </Button>
        </div>
      </div>

      {/* 我们的愿景 */}
      <div className="vision-section">
        <div className="vision-container">
          <Row gutter={[48, 48]} align="middle">
            <Col xs={0} lg={12} className="vision-image-col">
              <div className="vision-image">
                <img 
                  src="/static/logo.png" 
                  alt={t('about.vision')} 
                  className="vision-img"
                />
              </div>
            </Col>
            <Col xs={24} lg={12}>
              <div className="vision-content">
                <Title level={2} className="vision-title">{t('about.visionSection.title')}</Title>
                <div className="vision-items-container">
                  <div className="vision-item">
                    <RocketOutlined className="vision-icon" />
                    <div className="vision-text">
                      <Title level={4} className="vision-item-title">{t('about.visionSection.goals.platform.title')}</Title>
                      <Paragraph className="vision-item-desc">{t('about.visionSection.goals.platform.description')}</Paragraph>
                    </div>
                  </div>
                  <div className="vision-item">
                    <GlobalOutlined className="vision-icon" />
                    <div className="vision-text">
                      <Title level={4} className="vision-item-title">{t('about.visionSection.goals.workStyle.title')}</Title>
                      <Paragraph className="vision-item-desc">{t('about.visionSection.goals.workStyle.description')}</Paragraph>
                    </div>
                  </div>
                  <div className="vision-item">
                    <TrophyOutlined className="vision-icon" />
                    <div className="vision-text">
                      <Title level={4} className="vision-item-title">{t('about.visionSection.goals.socialValue.title')}</Title>
                      <Paragraph className="vision-item-desc">{t('about.visionSection.goals.socialValue.description')}</Paragraph>
                    </div>
                  </div>
                </div>
              </div>
            </Col>
          </Row>
        </div>
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
