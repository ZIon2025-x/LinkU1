import React from 'react';
import { Card, Row, Col, Typography, Space, Avatar, Divider } from 'antd';
import { 
  TeamOutlined, 
  RocketOutlined, 
  HeartOutlined, 
  GlobalOutlined,
  TrophyOutlined,
  BulbOutlined,
  SafetyOutlined,
  ThunderboltOutlined
} from '@ant-design/icons';
import './About.css';

const { Title, Paragraph, Text } = Typography;

const About: React.FC = () => {
  const teamMembers = [
    {
      name: "张小明",
      role: "创始人 & CEO",
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhang",
      description: "10年互联网产品经验，专注于用户体验设计"
    },
    {
      name: "李小红",
      role: "技术总监",
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=li",
      description: "资深全栈工程师，热爱技术创新"
    },
    {
      name: "王小强",
      role: "运营总监",
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=wang",
      description: "社区运营专家，致力于构建活跃的用户生态"
    },
    {
      name: "赵小美",
      role: "产品经理",
      avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=zhao",
      description: "用户体验设计师，关注产品细节和用户需求"
    }
  ];

  const values = [
    {
      icon: <HeartOutlined className="value-icon" />,
      title: "用户至上",
      description: "我们始终将用户需求放在首位，致力于提供最优质的服务体验"
    },
    {
      icon: <BulbOutlined className="value-icon" />,
      title: "创新驱动",
      description: "持续创新是我们的核心动力，用技术改变生活"
    },
    {
      icon: <SafetyOutlined className="value-icon" />,
      title: "安全可靠",
      description: "严格的安全标准和可靠的技术架构，保护每一位用户"
    },
    {
      icon: <TeamOutlined className="value-icon" />,
      title: "团队协作",
      description: "相信团队的力量，共同创造更大的价值"
    }
  ];

  const stats = [
    { number: "50,000+", label: "注册用户" },
    { number: "100,000+", label: "完成任务" },
    { number: "98%", label: "用户满意度" },
    { number: "24/7", label: "在线服务" }
  ];

  return (
    <div className="about-page">
      {/* 英雄区域 */}
      <div className="hero-section">
        <div className="hero-content">
          <Title level={1} className="hero-title">
            关于 LinkU
          </Title>
          <Paragraph className="hero-subtitle">
            连接全球人才，创造无限可能
          </Paragraph>
          <Paragraph className="hero-description">
            LinkU 是一个创新的任务平台，致力于连接有技能的人才和有需求的用户，
            通过技术的力量让工作变得更加高效、灵活和有意义。
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
                也看到了数字时代带来的无限可能。于是，LinkU 应运而生。
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
                alt="我们的团队" 
                className="story-img"
              />
            </div>
          </Col>
        </Row>
      </div>

      {/* 我们的价值观 */}
      <div className="values-section">
        <div className="section-header">
          <Title level={2}>我们的价值观</Title>
          <Paragraph className="section-subtitle">
            这些核心价值观指导着我们的每一个决策和行动
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
          <Title level={2}>我们的团队</Title>
          <Paragraph className="section-subtitle">
            一群充满激情和创造力的专业人士
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
                alt="我们的愿景" 
                className="vision-img"
              />
            </div>
          </Col>
          <Col xs={24} lg={12}>
            <div className="vision-content">
              <Title level={2}>我们的愿景</Title>
              <Space direction="vertical" size="large" style={{ width: '100%' }}>
                <div className="vision-item">
                  <RocketOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>成为全球领先的任务平台</Title>
                    <Paragraph>连接全球数亿用户，创造数千万个就业机会</Paragraph>
                  </div>
                </div>
                <div className="vision-item">
                  <GlobalOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>推动工作方式的变革</Title>
                    <Paragraph>让远程工作、灵活就业成为主流工作模式</Paragraph>
                  </div>
                </div>
                <div className="vision-item">
                  <TrophyOutlined className="vision-icon" />
                  <div>
                    <Title level={4}>创造社会价值</Title>
                    <Paragraph>通过技术赋能，让每个人都能发挥自己的价值</Paragraph>
                  </div>
                </div>
              </Space>
            </div>
          </Col>
        </Row>
      </div>

      {/* 联系我们 */}
      <div className="contact-section">
        <Card className="contact-card">
          <div className="contact-content">
            <Title level={2}>联系我们</Title>
            <Paragraph>
              如果您有任何问题或建议，我们很乐意听到您的声音。
              让我们一起创造更美好的未来！
            </Paragraph>
            <Space size="large">
              <div className="contact-item">
                <ThunderboltOutlined className="contact-icon" />
                <div>
                  <Text strong>邮箱</Text>
                  <br />
                  <Text>contact@linku.com</Text>
                </div>
              </div>
              <div className="contact-item">
                <TeamOutlined className="contact-icon" />
                <div>
                  <Text strong>客服热线</Text>
                  <br />
                  <Text>400-888-8888</Text>
                </div>
              </div>
            </Space>
          </div>
        </Card>
      </div>
    </div>
  );
};

export default About;
