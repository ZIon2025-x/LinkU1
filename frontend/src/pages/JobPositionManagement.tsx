import React, { useState, useEffect } from 'react';
import {
  Card,
  Table,
  Button,
  Modal,
  Form,
  Input,
  Select,
  Tag,
  Space,
  Popconfirm,
  message,
  Row,
  Col,
  Typography,
  Switch,
  Divider,
  Tooltip
} from 'antd';
import {
  PlusOutlined,
  EditOutlined,
  DeleteOutlined,
  EyeOutlined,
  SearchOutlined,
  ReloadOutlined
} from '@ant-design/icons';
import {
  getJobPositions,
  createJobPosition,
  updateJobPosition,
  deleteJobPosition,
  toggleJobPositionStatus
} from '../api';

const { Title } = Typography;
const { Option } = Select;
const { TextArea } = Input;

interface JobPosition {
  id: number;
  title: string;
  title_en?: string;
  department: string;
  department_en?: string;
  type: string;
  type_en?: string;
  location: string;
  location_en?: string;
  experience: string;
  experience_en?: string;
  salary: string;
  salary_en?: string;
  description: string;
  description_en?: string;
  requirements: string[];
  requirements_en?: string[];
  tags: string[];
  tags_en?: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
  created_by: string;
}

const JobPositionManagement: React.FC = () => {
  const [positions, setPositions] = useState<JobPosition[]>([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingPosition, setEditingPosition] = useState<JobPosition | null>(null);
  const [form] = Form.useForm();
  const [pagination, setPagination] = useState({
    current: 1,
    pageSize: 20,
    total: 0
  });
  const [filters, setFilters] = useState({
    is_active: undefined as boolean | undefined,
    department: undefined as string | undefined,
    type: undefined as string | undefined
  });

  // 加载岗位列表
  const loadPositions = async (page = 1, pageSize = 20) => {
    try {
      setLoading(true);
      const response = await getJobPositions({
        page,
        size: pageSize,
        ...filters
      });
      
      setPositions(response.positions || []);
      setPagination({
        current: response.page || 1,
        pageSize: response.size || 20,
        total: response.total || 0
      });
    } catch (error) {
      console.error('加载岗位列表失败:', error);
      message.error('加载岗位列表失败');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadPositions();
  }, [filters]);

  // 处理创建/编辑岗位
  const handleSubmit = async (values: any) => {
    try {
      // 处理数组字段
      const processedValues = {
        ...values,
        requirements: values.requirements ? values.requirements.split('\n').filter((req: string) => req.trim()) : [],
        requirements_en: values.requirements_en ? values.requirements_en.split('\n').filter((req: string) => req.trim()) : [],
        tags: values.tags ? values.tags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag) : [],
        tags_en: values.tags_en ? values.tags_en.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag) : []
      };

      if (editingPosition) {
        await updateJobPosition(editingPosition.id, processedValues);
        message.success('岗位更新成功');
      } else {
        await createJobPosition(processedValues);
        message.success('岗位创建成功');
      }
      
      setModalVisible(false);
      setEditingPosition(null);
      form.resetFields();
      loadPositions(pagination.current, pagination.pageSize);
    } catch (error) {
      console.error('保存岗位失败:', error);
      message.error('保存岗位失败');
    }
  };

  // 处理删除岗位
  const handleDelete = async (id: number) => {
    try {
      await deleteJobPosition(id);
      message.success('岗位删除成功');
      loadPositions(pagination.current, pagination.pageSize);
    } catch (error) {
      console.error('删除岗位失败:', error);
      message.error('删除岗位失败');
    }
  };

  // 处理切换状态
  const handleToggleStatus = async (id: number) => {
    try {
      await toggleJobPositionStatus(id);
      message.success('状态切换成功');
      loadPositions(pagination.current, pagination.pageSize);
    } catch (error) {
      console.error('切换状态失败:', error);
      message.error('切换状态失败');
    }
  };

  // 打开编辑模态框
  const openEditModal = (position: JobPosition) => {
    setEditingPosition(position);
    form.setFieldsValue({
      ...position,
      requirements: position.requirements.join('\n'),
      requirements_en: position.requirements_en?.join('\n') || '',
      tags: position.tags.join(','),
      tags_en: position.tags_en?.join(',') || ''
    });
    setModalVisible(true);
  };

  // 打开创建模态框
  const openCreateModal = () => {
    setEditingPosition(null);
    form.resetFields();
    setModalVisible(true);
  };

  // 表格列定义
  const columns = [
    {
      title: '岗位名称',
      dataIndex: 'title',
      key: 'title',
      width: 150,
      ellipsis: true
    },
    {
      title: '部门',
      dataIndex: 'department',
      key: 'department',
      width: 100,
      render: (text: string) => <Tag color="blue">{text}</Tag>
    },
    {
      title: '类型',
      dataIndex: 'type',
      key: 'type',
      width: 80,
      render: (text: string) => <Tag color="green">{text}</Tag>
    },
    {
      title: '地点',
      dataIndex: 'location',
      key: 'location',
      width: 120,
      ellipsis: true
    },
    {
      title: '经验要求',
      dataIndex: 'experience',
      key: 'experience',
      width: 100
    },
    {
      title: '薪资范围',
      dataIndex: 'salary',
      key: 'salary',
      width: 100
    },
    {
      title: '状态',
      dataIndex: 'is_active',
      key: 'is_active',
      width: 80,
      render: (isActive: boolean, record: JobPosition) => (
        <Switch
          checked={isActive}
          onChange={() => handleToggleStatus(record.id)}
          checkedChildren="启用"
          unCheckedChildren="禁用"
        />
      )
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      key: 'created_at',
      width: 120,
      render: (text: string) => new Date(text).toLocaleDateString()
    },
    {
      title: '操作',
      key: 'action',
      width: 150,
      render: (_: any, record: JobPosition) => (
        <Space size="small">
          <Tooltip title="编辑">
            <Button
              type="text"
              icon={<EditOutlined />}
              onClick={() => openEditModal(record)}
            />
          </Tooltip>
          <Popconfirm
            title="确定要删除这个岗位吗？"
            onConfirm={() => handleDelete(record.id)}
            okText="确定"
            cancelText="取消"
          >
            <Tooltip title="删除">
              <Button
                type="text"
                danger
                icon={<DeleteOutlined />}
              />
            </Tooltip>
          </Popconfirm>
        </Space>
      )
    }
  ];

  return (
    <div style={{ padding: '24px' }}>
      {/* SEO优化：H1标签，几乎不可见但SEO可检测 */}
      <h1 style={{
        position: 'absolute',
        top: '-100px',
        left: '-100px',
        width: '1px',
        height: '1px',
        padding: '0',
        margin: '0',
        overflow: 'hidden',
        clip: 'rect(0, 0, 0, 0)',
        whiteSpace: 'nowrap',
        border: '0',
        fontSize: '1px',
        color: 'transparent',
        background: 'transparent'
      }}>
        岗位管理
      </h1>
      <Card>
        <div style={{ marginBottom: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Title level={3} style={{ margin: 0 }}>岗位管理</Title>
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={openCreateModal}
          >
            添加岗位
          </Button>
        </div>

        {/* 筛选器 */}
        <Row gutter={16} style={{ marginBottom: '16px' }}>
          <Col span={6}>
            <Select
              placeholder="状态筛选"
              allowClear
              style={{ width: '100%' }}
              value={filters.is_active}
              onChange={(value) => setFilters({ ...filters, is_active: value })}
            >
              <Option value={true}>启用</Option>
              <Option value={false}>禁用</Option>
            </Select>
          </Col>
          <Col span={6}>
            <Select
              placeholder="部门筛选"
              allowClear
              style={{ width: '100%' }}
              value={filters.department}
              onChange={(value) => setFilters({ ...filters, department: value })}
            >
              <Option value="技术部">技术部</Option>
              <Option value="产品部">产品部</Option>
              <Option value="设计部">设计部</Option>
              <Option value="运营部">运营部</Option>
              <Option value="客服部">客服部</Option>
            </Select>
          </Col>
          <Col span={6}>
            <Select
              placeholder="工作类型筛选"
              allowClear
              style={{ width: '100%' }}
              value={filters.type}
              onChange={(value) => setFilters({ ...filters, type: value })}
            >
              <Option value="全职">全职</Option>
              <Option value="兼职">兼职</Option>
              <Option value="实习">实习</Option>
            </Select>
          </Col>
          <Col span={6}>
            <Button
              icon={<ReloadOutlined />}
              onClick={() => loadPositions(pagination.current, pagination.pageSize)}
            >
              刷新
            </Button>
          </Col>
        </Row>

        <Table
          columns={columns}
          dataSource={positions}
          rowKey="id"
          loading={loading}
          pagination={{
            ...pagination,
            showSizeChanger: true,
            showQuickJumper: true,
            showTotal: (total, range) => `第 ${range[0]}-${range[1]} 条/共 ${total} 条`,
            onChange: (page, pageSize) => {
              loadPositions(page, pageSize || 20);
            }
          }}
          scroll={{ x: 1200 }}
        />
      </Card>

      {/* 创建/编辑模态框 */}
      <Modal
        title={editingPosition ? '编辑岗位' : '添加岗位'}
        open={modalVisible}
        onCancel={() => {
          setModalVisible(false);
          setEditingPosition(null);
          form.resetFields();
        }}
        footer={null}
        width={800}
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleSubmit}
        >
          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="title"
                label="岗位名称"
                rules={[{ required: true, message: '请输入岗位名称' }]}
              >
                <Input placeholder="请输入岗位名称" />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="title_en"
                label="岗位名称（英文）"
              >
                <Input placeholder="请输入英文岗位名称" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="department"
                label="部门"
                rules={[{ required: true, message: '请选择部门' }]}
              >
                <Select placeholder="请选择部门">
                  <Option value="技术部">技术部</Option>
                  <Option value="产品部">产品部</Option>
                  <Option value="设计部">设计部</Option>
                  <Option value="运营部">运营部</Option>
                  <Option value="客服部">客服部</Option>
                </Select>
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="department_en"
                label="部门（英文）"
              >
                <Input placeholder="请输入英文部门名称" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={6}>
              <Form.Item
                name="type"
                label="工作类型"
                rules={[{ required: true, message: '请选择工作类型' }]}
              >
                <Select placeholder="请选择工作类型">
                  <Option value="全职">全职</Option>
                  <Option value="兼职">兼职</Option>
                  <Option value="实习">实习</Option>
                </Select>
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="type_en"
                label="工作类型（英文）"
              >
                <Input placeholder="如：Full-time" />
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="location"
                label="工作地点"
                rules={[{ required: true, message: '请输入工作地点' }]}
              >
                <Input placeholder="请输入工作地点" />
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="location_en"
                label="工作地点（英文）"
              >
                <Input placeholder="如：Beijing/Remote" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={6}>
              <Form.Item
                name="experience"
                label="经验要求"
                rules={[{ required: true, message: '请输入经验要求' }]}
              >
                <Input placeholder="如：3-5年" />
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="experience_en"
                label="经验要求（英文）"
              >
                <Input placeholder="如：3-5 years" />
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="salary"
                label="薪资范围"
                rules={[{ required: true, message: '请输入薪资范围' }]}
              >
                <Input placeholder="如：15-25K" />
              </Form.Item>
            </Col>
            <Col span={6}>
              <Form.Item
                name="salary_en"
                label="薪资范围（英文）"
              >
                <Input placeholder="如：15-25K" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="is_active"
                label="是否启用"
                valuePropName="checked"
                initialValue={true}
              >
                <Switch checkedChildren="启用" unCheckedChildren="禁用" />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="description"
                label="岗位描述"
                rules={[{ required: true, message: '请输入岗位描述' }]}
              >
                <TextArea
                  rows={3}
                  placeholder="请输入岗位描述"
                />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="description_en"
                label="岗位描述（英文）"
              >
                <TextArea
                  rows={3}
                  placeholder="请输入英文岗位描述"
                />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="requirements"
                label="任职要求"
                rules={[{ required: true, message: '请输入任职要求' }]}
                help="每行一个要求"
              >
                <TextArea
                  rows={4}
                  placeholder="请输入任职要求，每行一个要求"
                />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="requirements_en"
                label="任职要求（英文）"
                help="每行一个要求"
              >
                <TextArea
                  rows={4}
                  placeholder="请输入英文任职要求，每行一个要求"
                />
              </Form.Item>
            </Col>
          </Row>

          <Row gutter={16}>
            <Col span={12}>
              <Form.Item
                name="tags"
                label="技能标签"
                help="用逗号分隔多个标签"
              >
                <Input placeholder="如：React, TypeScript, Python" />
              </Form.Item>
            </Col>
            <Col span={12}>
              <Form.Item
                name="tags_en"
                label="技能标签（英文）"
                help="用逗号分隔多个标签"
              >
                <Input placeholder="如：React, TypeScript, Python" />
              </Form.Item>
            </Col>
          </Row>

          <Form.Item style={{ marginBottom: 0, textAlign: 'right' }}>
            <Space>
              <Button onClick={() => setModalVisible(false)}>
                取消
              </Button>
              <Button type="primary" htmlType="submit">
                {editingPosition ? '更新' : '创建'}
              </Button>
            </Space>
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default JobPositionManagement;
