import React, { useState, useEffect } from 'react';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { 
  Card, 
  Row, 
  Col, 
  Typography, 
  Button, 
  Form, 
  Input, 
  Select, 
  Upload, 
  message,
  Space,
  Divider,
  Tag,
  Timeline,
  Progress,
  Modal
} from 'antd';
import { 
  UploadOutlined, 
  SendOutlined, 
  CheckCircleOutlined,
  ClockCircleOutlined,
  UserOutlined,
  MailOutlined,
  PhoneOutlined,
  FileTextOutlined,
  TeamOutlined,
  RocketOutlined,
  HeartOutlined,
  TrophyOutlined
} from '@ant-design/icons';
import { fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicJobPositions } from '../api';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import './JoinUs.css';

const { Title, Paragraph, Text } = Typography;
const { TextArea } = Input;
const { Option } = Select;

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

const JoinUs: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [systemSettings, setSystemSettings] = useState({});
  const [positions, setPositions] = useState<any[]>([]);
  const [positionsLoading, setPositionsLoading] = useState(true);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedPosition, setSelectedPosition] = useState<string | null>(null);

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

  // 加载岗位数据
  useEffect(() => {
    const loadPositions = async () => {
      try {
        setPositionsLoading(true);
        const response = await getPublicJobPositions({ page: 1, size: 100 });
        setPositions(response.positions || []);
      } catch (error) {
        console.error('加载岗位数据失败:', error);
        // 如果API失败，显示空状态
        setPositions([]);
      } finally {
        setPositionsLoading(false);
      }
    };
    
    loadPositions();
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
      alert('标记通知为已读失败，请重试');
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
      alert('标记所有通知为已读失败，请重试');
    }
  };


  const benefits = [
    {
      icon: <RocketOutlined className="benefit-icon" />,
      title: t('joinUs.benefits.rapidGrowth'),
      description: t('joinUs.benefits.rapidGrowthDesc')
    },
    {
      icon: <TeamOutlined className="benefit-icon" />,
      title: t('joinUs.benefits.excellentTeam'),
      description: t('joinUs.benefits.excellentTeamDesc')
    },
    {
      icon: <HeartOutlined className="benefit-icon" />,
      title: t('joinUs.benefits.flexibleWork'),
      description: t('joinUs.benefits.flexibleWorkDesc')
    },
    {
      icon: <TrophyOutlined className="benefit-icon" />,
      title: t('joinUs.benefits.equityIncentive'),
      description: t('joinUs.benefits.equityIncentiveDesc')
    }
  ];

  const processSteps = [
    {
      title: t('joinUs.processSteps.submitResume'),
      description: t('joinUs.processSteps.submitResumeDesc'),
      icon: <FileTextOutlined />
    },
    {
      title: t('joinUs.processSteps.resumeScreening'),
      description: t('joinUs.processSteps.resumeScreeningDesc'),
      icon: <UserOutlined />
    },
    {
      title: t('joinUs.processSteps.interviewArrangement'),
      description: t('joinUs.processSteps.interviewArrangementDesc'),
      icon: <PhoneOutlined />
    },
    {
      title: t('joinUs.processSteps.technicalInterview'),
      description: t('joinUs.processSteps.technicalInterviewDesc'),
      icon: <CheckCircleOutlined />
    },
    {
      title: t('joinUs.processSteps.finalInterview'),
      description: t('joinUs.processSteps.finalInterviewDesc'),
      icon: <ClockCircleOutlined />
    },
    {
      title: t('joinUs.processSteps.offerNotification'),
      description: t('joinUs.processSteps.offerNotificationDesc'),
      icon: <SendOutlined />
    }
  ];

  const handleSubmit = async (values: any) => {
    setLoading(true);
    try {
      // 模拟提交
      await new Promise(resolve => setTimeout(resolve, 2000));
      message.success('简历投递成功！我们会在3个工作日内与您联系。');
      form.resetFields();
    } catch (error) {
      message.error('投递失败，请稍后重试');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="join-us-page">
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
            {t('joinUs.title')}
            <br />
            <span style={{color: '#FFD700'}}>{t('joinUs.subtitle')}</span>
          </h1>
          
          <p className="hero-subtitle" style={{
            fontSize: '20px',
            color: 'rgba(255,255,255,0.9)',
            marginBottom: '40px',
            maxWidth: '600px',
            margin: '0 auto 40px',
            lineHeight: '1.6'
          }}>
            {t('joinUs.description')}
          </p>
        </div>
      </section>

      {/* 为什么选择我们 */}
      <div className="benefits-section">
        <div className="section-header">
          <Title level={2}>{t('joinUs.whyChooseUs')}</Title>
          <Paragraph className="section-subtitle">
            {t('joinUs.whyChooseUsSubtitle')}
          </Paragraph>
        </div>
        <Row gutter={[32, 32]}>
          {benefits.map((benefit, index) => (
            <Col xs={12} sm={12} lg={6} key={index}>
              <Card className="benefit-card" hoverable>
                <div className="benefit-content">
                  {benefit.icon}
                  <Title level={4} className="benefit-title">{benefit.title}</Title>
                  <Paragraph className="benefit-description">{benefit.description}</Paragraph>
                </div>
              </Card>
            </Col>
          ))}
        </Row>
      </div>

      {/* 职位列表 */}
      <div className="positions-section">
        <div className="section-header">
          <Title level={2}>{t('joinUs.openPositions')}</Title>
          <Paragraph className="section-subtitle">
            {t('joinUs.openPositionsSubtitle')}
          </Paragraph>
        </div>
        {positionsLoading ? (
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <div style={{
              display: 'inline-block',
              width: '40px',
              height: '40px',
              border: '4px solid #f3f3f3',
              borderTop: '4px solid #007bff',
              borderRadius: '50%',
              animation: 'spin 1s linear infinite'
            }} />
            <p style={{ marginTop: '16px', color: '#666' }}>加载岗位信息中...</p>
          </div>
        ) : positions.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <p style={{ color: '#666', fontSize: '16px' }}>暂无招聘岗位</p>
          </div>
        ) : (
          <Row gutter={[24, 24]}>
            {positions.map((position, index) => {
              // 根据语言选择显示的内容
              const displayTitle = language === 'en' && position.title_en ? position.title_en : position.title;
              const displayDepartment = language === 'en' && position.department_en ? position.department_en : position.department;
              const displayType = language === 'en' && position.type_en ? position.type_en : position.type;
              const displayLocation = language === 'en' && position.location_en ? position.location_en : position.location;
              const displayExperience = language === 'en' && position.experience_en ? position.experience_en : position.experience;
              const displaySalary = language === 'en' && position.salary_en ? position.salary_en : position.salary;
              const displayDescription = language === 'en' && position.description_en ? position.description_en : position.description;
              const displayRequirements = language === 'en' && position.requirements_en && position.requirements_en.length > 0 ? position.requirements_en : position.requirements;
              const displayTags = language === 'en' && position.tags_en && position.tags_en.length > 0 ? position.tags_en : position.tags;
              
              return (
                <Col xs={24} lg={12} key={index}>
                  <Card className="position-card" hoverable>
                    <div className="position-header">
                      <Title level={4} className="position-title">{displayTitle}</Title>
                      <div className="position-meta">
                        <Tag color="blue">{displayDepartment}</Tag>
                        <Tag color="green">{displayType}</Tag>
                        <Tag color="orange">{displayLocation}</Tag>
                      </div>
                    </div>
                    <div className="position-info">
                      <div className="info-item">
                        <Text strong>{language === 'en' ? 'Experience:' : '经验要求：'}</Text>
                        <Text>{displayExperience}</Text>
                      </div>
                      <div className="info-item">
                        <Text strong>{language === 'en' ? 'Salary:' : '薪资范围：'}</Text>
                        <Text>{displaySalary}</Text>
                      </div>
                    </div>
                    <Paragraph className="position-description">{displayDescription}</Paragraph>
                    <div className="position-tags">
                      {displayTags.map((tag: string, tagIndex: number) => (
                        <Tag key={tagIndex} color="purple">{tag}</Tag>
                      ))}
                    </div>
                    <div className="position-requirements">
                      <Title level={5}>{language === 'en' ? 'Requirements:' : '任职要求：'}</Title>
                      <ul>
                        {displayRequirements.map((req: string, reqIndex: number) => (
                          <li key={reqIndex}>{req}</li>
                        ))}
                      </ul>
                    </div>
                    <Button 
                      type="primary" 
                      size="large" 
                      className="apply-button"
                      onClick={() => {
                        const displayTitle = language === 'en' && position.title_en ? position.title_en : position.title;
                        setSelectedPosition(displayTitle);
                        form.setFieldsValue({ position: displayTitle });
                        setShowApplyModal(true);
                      }}
                    >
                      {t('joinUs.buttons.applyNow')}
                    </Button>
                  </Card>
                </Col>
              );
            })}
          </Row>
        )}
      </div>

      {/* 招聘流程 */}
      <div className="process-section">
        <div className="section-header">
          <Title level={2}>{t('joinUs.recruitmentProcess')}</Title>
          <Paragraph className="section-subtitle">
            {t('joinUs.recruitmentProcessSubtitle')}
          </Paragraph>
        </div>
        <div className="process-timeline">
          <Timeline>
            {processSteps.map((step, index) => (
              <Timeline.Item
                key={index}
                dot={step.icon}
                color="#667eea"
              >
                <div className="process-step">
                  <Title level={4} className="step-title">{step.title}</Title>
                  <Paragraph className="step-description">{step.description}</Paragraph>
                </div>
              </Timeline.Item>
            ))}
          </Timeline>
        </div>
      </div>

      {/* 简历投递弹窗 */}
      <Modal
        open={showApplyModal}
        title={t('joinUs.submitResume')}
        onCancel={() => setShowApplyModal(false)}
        footer={null}
        destroyOnClose
        centered
        width={720}
      >
        <Paragraph style={{ marginTop: -8 }}>
          {t('joinUs.submitResumeDescription')}
        </Paragraph>
        <Form
          form={form}
          layout="vertical"
          onFinish={async (values) => {
            await handleSubmit(values);
            setShowApplyModal(false);
          }}
          className="apply-form"
        >
          <Row gutter={[16, 0]}>
            <Col xs={24} sm={12}>
              <Form.Item
                name="name"
                label={t('joinUs.formLabels.name')}
                rules={[{ required: true, message: t('joinUs.formPlaceholders.enterName') }]}
              >
                <Input prefix={<UserOutlined />} placeholder={t('joinUs.formPlaceholders.enterName')} />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item
                name="phone"
                label={t('joinUs.formLabels.phone')}
                rules={[]}
              >
                <Input prefix={<PhoneOutlined />} placeholder={t('joinUs.formPlaceholders.enterPhone')} />
              </Form.Item>
            </Col>
          </Row>
          <Row gutter={[16, 0]}>
            <Col xs={24} sm={12}>
              <Form.Item
                name="email"
                label={t('joinUs.formLabels.email')}
                rules={[
                  { required: true, message: t('joinUs.formPlaceholders.enterEmail') },
                  { type: 'email', message: '请输入有效的邮箱地址' }
                ]}
              >
                <Input prefix={<MailOutlined />} placeholder={t('joinUs.formPlaceholders.enterEmail')} />
              </Form.Item>
            </Col>
            <Col xs={24} sm={12}>
              <Form.Item
                name="position"
                label={t('joinUs.formLabels.position')}
                rules={[{ required: true, message: t('joinUs.formPlaceholders.selectPosition') }]}
              >
                <Select placeholder={t('joinUs.formPlaceholders.selectPosition')}>
                  {positions.map((pos, index) => {
                    const displayTitle = language === 'en' && pos.title_en ? pos.title_en : pos.title;
                    return (
                      <Option key={index} value={displayTitle}>{displayTitle}</Option>
                    );
                  })}
                </Select>
              </Form.Item>
            </Col>
          </Row>
          <Form.Item
            name="experience"
            label={t('joinUs.formLabels.experience')}
            rules={[{ required: true, message: t('joinUs.formPlaceholders.selectExperience') }]}
          >
            <Select placeholder={t('joinUs.formPlaceholders.selectExperience')}>
              <Option value="freshGraduate">{t('joinUs.experienceOptions.freshGraduate')}</Option>
              <Option value="lessThan1Year">{t('joinUs.experienceOptions.lessThan1Year')}</Option>
              <Option value="oneToThreeYears">{t('joinUs.experienceOptions.oneToThreeYears')}</Option>
              <Option value="threeToFiveYears">{t('joinUs.experienceOptions.threeToFiveYears')}</Option>
              <Option value="moreThanFiveYears">{t('joinUs.experienceOptions.moreThanFiveYears')}</Option>
            </Select>
          </Form.Item>
          <Form.Item
            name="resume"
            label={t('joinUs.formLabels.resume')}
            rules={[{ required: true, message: t('joinUs.formPlaceholders.uploadResume') }]}
          >
            <Upload
              beforeUpload={() => false}
              maxCount={1}
              accept=".pdf,.doc,.docx"
            >
              <Button icon={<UploadOutlined />}>{t('joinUs.buttons.uploadResume')}</Button>
            </Upload>
          </Form.Item>
          <Form.Item
            name="introduction"
            label={t('joinUs.formLabels.introduction')}
            rules={[{ required: true, message: t('joinUs.formPlaceholders.enterIntroduction') }]}
          >
            <TextArea rows={4} placeholder={t('joinUs.formPlaceholders.enterIntroduction')} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" size="large" loading={loading} icon={<SendOutlined />}>
              {loading ? t('joinUs.buttons.submitting') : t('joinUs.buttons.submitResume')}
            </Button>
          </Form.Item>
        </Form>
      </Modal>

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

export default JoinUs;
