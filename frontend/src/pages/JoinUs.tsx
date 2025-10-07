import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
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
  Progress
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
import { fetchCurrentUser, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead } from '../api';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import Footer from '../components/Footer';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
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
  const { t } = useLanguage();
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);
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
      console.log('所有通知标记为已读成功');
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      alert('标记所有通知为已读失败，请重试');
    }
  };

  const positions = [
    {
      title: "前端开发工程师",
      department: "技术部",
      type: "全职",
      location: "北京/远程",
      experience: "3-5年",
      salary: "15-25K",
      tags: ["React", "TypeScript", "Vue", "前端"],
      description: "负责平台前端开发，参与产品设计和用户体验优化",
      requirements: [
        "熟练掌握 React、Vue 等前端框架",
        "熟悉 TypeScript、ES6+ 语法",
        "有移动端开发经验优先",
        "具备良好的代码规范和团队协作能力"
      ]
    },
    {
      title: "后端开发工程师",
      department: "技术部",
      type: "全职",
      location: "北京/远程",
      experience: "3-5年",
      salary: "18-30K",
      tags: ["Python", "FastAPI", "PostgreSQL", "Redis"],
      description: "负责平台后端开发，API设计和数据库优化",
      requirements: [
        "熟练掌握 Python 及相关框架",
        "熟悉 FastAPI、Django 等 Web 框架",
        "有数据库设计和优化经验",
        "了解微服务架构和云服务"
      ]
    },
    {
      title: "产品经理",
      department: "产品部",
      type: "全职",
      location: "北京",
      experience: "2-4年",
      salary: "12-20K",
      tags: ["产品设计", "用户研究", "数据分析", "产品"],
      description: "负责产品规划和设计，用户需求分析和产品迭代",
      requirements: [
        "有互联网产品经验",
        "熟悉产品设计流程",
        "具备数据分析能力",
        "有平台类产品经验优先"
      ]
    },
    {
      title: "UI/UX 设计师",
      department: "设计部",
      type: "全职",
      location: "北京/远程",
      experience: "2-4年",
      salary: "10-18K",
      tags: ["UI设计", "UX设计", "Figma", "设计"],
      description: "负责产品界面设计和用户体验优化",
      requirements: [
        "熟练掌握设计工具",
        "有移动端设计经验",
        "了解设计规范和用户心理",
        "有平台类产品设计经验优先"
      ]
    },
    {
      title: "运营专员",
      department: "运营部",
      type: "全职",
      location: "北京",
      experience: "1-3年",
      salary: "8-15K",
      tags: ["用户运营", "内容运营", "数据分析", "运营"],
      description: "负责用户运营和内容运营，提升用户活跃度",
      requirements: [
        "有互联网运营经验",
        "熟悉社交媒体运营",
        "具备数据分析能力",
        "有社区运营经验优先"
      ]
    },
    {
      title: "客服专员",
      department: "客服部",
      type: "全职",
      location: "北京/远程",
      experience: "1-2年",
      salary: "6-10K",
      tags: ["客户服务", "沟通能力", "问题解决", "客服"],
      description: "负责用户咨询和问题处理，维护用户关系",
      requirements: [
        "具备良好的沟通能力",
        "有客服工作经验",
        "熟悉在线客服工具",
        "有耐心和责任心"
      ]
    }
  ];

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
            Link2Ur
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
            {t('joinUs.title')}
          </Title>
          <Paragraph className="hero-subtitle">
            {t('joinUs.subtitle')}
          </Paragraph>
          <Paragraph className="hero-description">
            {t('joinUs.description')}
          </Paragraph>
        </div>
      </div>

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
            <Col xs={24} sm={12} lg={6} key={index}>
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

      {/* 职位列表 */}
      <div className="positions-section">
        <div className="section-header">
          <Title level={2}>{t('joinUs.openPositions')}</Title>
          <Paragraph className="section-subtitle">
            {t('joinUs.openPositionsSubtitle')}
          </Paragraph>
        </div>
        <Row gutter={[24, 24]}>
          {positions.map((position, index) => (
            <Col xs={24} lg={12} key={index}>
              <Card className="position-card" hoverable>
                <div className="position-header">
                  <Title level={4} className="position-title">{position.title}</Title>
                  <div className="position-meta">
                    <Tag color="blue">{position.department}</Tag>
                    <Tag color="green">{position.type}</Tag>
                    <Tag color="orange">{position.location}</Tag>
                  </div>
                </div>
                <div className="position-info">
                  <div className="info-item">
                    <Text strong>经验要求：</Text>
                    <Text>{position.experience}</Text>
                  </div>
                  <div className="info-item">
                    <Text strong>薪资范围：</Text>
                    <Text>{position.salary}</Text>
                  </div>
                </div>
                <Paragraph className="position-description">{position.description}</Paragraph>
                <div className="position-tags">
                  {position.tags.map((tag, tagIndex) => (
                    <Tag key={tagIndex} color="purple">{tag}</Tag>
                  ))}
                </div>
                <div className="position-requirements">
                  <Title level={5}>任职要求：</Title>
                  <ul>
                    {position.requirements.map((req, reqIndex) => (
                      <li key={reqIndex}>{req}</li>
                    ))}
                  </ul>
                </div>
                <Button type="primary" size="large" className="apply-button">
                  {t('joinUs.buttons.applyNow')}
                </Button>
              </Card>
            </Col>
          ))}
        </Row>
      </div>

      {/* 简历投递 */}
      <div className="apply-section">
        <Card className="apply-card">
          <div className="apply-content">
            <Title level={2}>{t('joinUs.submitResume')}</Title>
            <Paragraph>
              {t('joinUs.submitResumeDescription')}
            </Paragraph>
            <Form
              form={form}
              layout="vertical"
              onFinish={handleSubmit}
              className="apply-form"
            >
              <Row gutter={[24, 0]}>
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
              <Row gutter={[24, 0]}>
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
                      {positions.map((pos, index) => (
                        <Option key={index} value={pos.title}>{pos.title}</Option>
                      ))}
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
                <TextArea
                  rows={4}
                  placeholder={t('joinUs.formPlaceholders.enterIntroduction')}
                />
              </Form.Item>
              <Form.Item>
                <Button
                  type="primary"
                  htmlType="submit"
                  size="large"
                  loading={loading}
                  icon={<SendOutlined />}
                  className="submit-button"
                >
                  {loading ? t('joinUs.buttons.submitting') : t('joinUs.buttons.submitResume')}
                </Button>
              </Form.Item>
            </Form>
          </div>
        </Card>
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

export default JoinUs;
