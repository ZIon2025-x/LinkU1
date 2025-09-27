import React, { useState } from 'react';
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
import './JoinUs.css';

const { Title, Paragraph, Text } = Typography;
const { TextArea } = Input;
const { Option } = Select;

const JoinUs: React.FC = () => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

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
      title: "快速成长",
      description: "参与从0到1的产品建设，快速提升个人能力"
    },
    {
      icon: <TeamOutlined className="benefit-icon" />,
      title: "优秀团队",
      description: "与行业顶尖人才共事，学习最前沿的技术和理念"
    },
    {
      icon: <HeartOutlined className="benefit-icon" />,
      title: "弹性工作",
      description: "灵活的工作时间和远程办公选项，平衡工作与生活"
    },
    {
      icon: <TrophyOutlined className="benefit-icon" />,
      title: "股权激励",
      description: "早期员工享有股权激励，分享公司成长红利"
    }
  ];

  const processSteps = [
    {
      title: "投递简历",
      description: "通过我们的招聘页面投递简历",
      icon: <FileTextOutlined />
    },
    {
      title: "简历筛选",
      description: "HR会在3个工作日内回复",
      icon: <UserOutlined />
    },
    {
      title: "面试安排",
      description: "通过电话或视频进行初步面试",
      icon: <PhoneOutlined />
    },
    {
      title: "技术面试",
      description: "技术团队进行专业能力评估",
      icon: <CheckCircleOutlined />
    },
    {
      title: "最终面试",
      description: "与团队负责人进行最终面试",
      icon: <ClockCircleOutlined />
    },
    {
      title: "入职通知",
      description: "面试通过后3个工作日内发放offer",
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
      {/* 英雄区域 */}
      <div className="hero-section">
        <div className="hero-content">
          <Title level={1} className="hero-title">
            加入我们
          </Title>
          <Paragraph className="hero-subtitle">
            与我们一起创造未来
          </Paragraph>
          <Paragraph className="hero-description">
            我们正在寻找有激情、有才华的伙伴加入我们的团队。
            如果你想要在一个快速发展的公司中发挥自己的价值，
            如果你想要参与改变世界的产品建设，那么这里就是你的舞台！
          </Paragraph>
        </div>
      </div>

      {/* 为什么选择我们 */}
      <div className="benefits-section">
        <div className="section-header">
          <Title level={2}>为什么选择我们</Title>
          <Paragraph className="section-subtitle">
            我们为每一位员工提供最好的发展平台和福利待遇
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
          <Title level={2}>招聘流程</Title>
          <Paragraph className="section-subtitle">
            简单透明的招聘流程，让您轻松加入我们
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
          <Title level={2}>开放职位</Title>
          <Paragraph className="section-subtitle">
            我们正在寻找这些职位的优秀人才
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
                  立即申请
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
            <Title level={2}>投递简历</Title>
            <Paragraph>
              没有找到合适的职位？没关系！我们欢迎有才华的你主动投递简历。
              请填写以下信息，我们会根据您的背景为您推荐合适的职位。
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
                    label="姓名"
                    rules={[{ required: true, message: '请输入您的姓名' }]}
                  >
                    <Input prefix={<UserOutlined />} placeholder="请输入您的姓名" />
                  </Form.Item>
                </Col>
                <Col xs={24} sm={12}>
                  <Form.Item
                    name="phone"
                    label="手机号"
                    rules={[{ required: true, message: '请输入您的手机号' }]}
                  >
                    <Input prefix={<PhoneOutlined />} placeholder="请输入您的手机号" />
                  </Form.Item>
                </Col>
              </Row>
              <Row gutter={[24, 0]}>
                <Col xs={24} sm={12}>
                  <Form.Item
                    name="email"
                    label="邮箱"
                    rules={[
                      { required: true, message: '请输入您的邮箱' },
                      { type: 'email', message: '请输入有效的邮箱地址' }
                    ]}
                  >
                    <Input prefix={<MailOutlined />} placeholder="请输入您的邮箱" />
                  </Form.Item>
                </Col>
                <Col xs={24} sm={12}>
                  <Form.Item
                    name="position"
                    label="意向职位"
                    rules={[{ required: true, message: '请选择意向职位' }]}
                  >
                    <Select placeholder="请选择意向职位">
                      {positions.map((pos, index) => (
                        <Option key={index} value={pos.title}>{pos.title}</Option>
                      ))}
                    </Select>
                  </Form.Item>
                </Col>
              </Row>
              <Form.Item
                name="experience"
                label="工作经验"
                rules={[{ required: true, message: '请选择工作经验' }]}
              >
                <Select placeholder="请选择您的工作经验">
                  <Option value="应届毕业生">应届毕业生</Option>
                  <Option value="1年以下">1年以下</Option>
                  <Option value="1-3年">1-3年</Option>
                  <Option value="3-5年">3-5年</Option>
                  <Option value="5年以上">5年以上</Option>
                </Select>
              </Form.Item>
              <Form.Item
                name="resume"
                label="简历文件"
                rules={[{ required: true, message: '请上传您的简历' }]}
              >
                <Upload
                  beforeUpload={() => false}
                  maxCount={1}
                  accept=".pdf,.doc,.docx"
                >
                  <Button icon={<UploadOutlined />}>上传简历</Button>
                </Upload>
              </Form.Item>
              <Form.Item
                name="introduction"
                label="自我介绍"
                rules={[{ required: true, message: '请输入自我介绍' }]}
              >
                <TextArea
                  rows={4}
                  placeholder="请简单介绍一下您的背景、技能和为什么想要加入我们..."
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
                  {loading ? '投递中...' : '投递简历'}
                </Button>
              </Form.Item>
            </Form>
          </div>
        </Card>
      </div>

      {/* 联系我们 */}
      <div className="contact-section">
        <div className="contact-content">
          <Title level={2}>联系我们</Title>
          <Paragraph>
            如果您有任何问题，欢迎随时联系我们
          </Paragraph>
          <Space size="large">
            <div className="contact-item">
              <MailOutlined className="contact-icon" />
              <div>
                <Text strong>招聘邮箱</Text>
                <br />
                <Text>hr@linku.com</Text>
              </div>
            </div>
            <div className="contact-item">
              <PhoneOutlined className="contact-icon" />
              <div>
                <Text strong>招聘热线</Text>
                <br />
                <Text>400-888-8888</Text>
              </div>
            </div>
          </Space>
        </div>
      </div>
    </div>
  );
};

export default JoinUs;
