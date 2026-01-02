import React, { useState, useEffect } from 'react';
import { Card, Table, Tag, Button, message, Spin, Select, Pagination } from 'antd';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import dayjs from 'dayjs';

const { Option } = Select;

interface PaymentRecord {
  id: number;
  task_id: number;
  payment_intent_id: string | null;
  payment_method: string;
  total_amount: number;
  total_amount_display: string;
  points_used: number | null;
  points_used_display: string | null;
  coupon_discount: number | null;
  coupon_discount_display: string | null;
  stripe_amount: number | null;
  stripe_amount_display: string | null;
  final_amount: number;
  final_amount_display: string;
  currency: string;
  status: string;
  application_fee: number | null;
  application_fee_display: string | null;
  escrow_amount: number | null;
  created_at: string;
  updated_at: string;
  task: {
    id: number;
    title: string;
  } | null;
}

const PaymentHistory: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const { navigate: localizedNavigate } = useLocalizedNavigation();
  
  const [loading, setLoading] = useState(false);
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [skip, setSkip] = useState(0);
  const [limit, setLimit] = useState(20);
  const [statusFilter, setStatusFilter] = useState<string | undefined>(undefined);
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);

  useEffect(() => {
    // 检查用户登录状态
    const checkUser = async () => {
      try {
        const userData = await api.get('/api/users/me');
        setUser(userData.data);
        loadPaymentHistory();
      } catch (error) {
        setShowLoginModal(true);
      }
    };
    
    checkUser();
  }, []);

  useEffect(() => {
    if (user) {
      loadPaymentHistory();
    }
  }, [skip, limit, statusFilter]);

  const loadPaymentHistory = async () => {
    if (!user) return;

    setLoading(true);
    try {
      const params: any = {
        skip,
        limit,
      };
      if (statusFilter) {
        params.status = statusFilter;
      }

      const response = await api.get('/api/coupon-points/payment-history', { params });
      setPayments(response.data.payments || []);
      setTotal(response.data.total || 0);
    } catch (error: any) {
      const errorMessage = error.response?.data?.detail || error.message || '加载支付历史失败';
      message.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const getStatusTag = (status: string) => {
    const statusMap: Record<string, { color: string; text: string }> = {
      succeeded: { color: 'success', text: '支付成功' },
      pending: { color: 'processing', text: '待支付' },
      failed: { color: 'error', text: '支付失败' },
      canceled: { color: 'default', text: '已取消' },
    };
    const statusInfo = statusMap[status] || { color: 'default', text: status };
    return <Tag color={statusInfo.color}>{statusInfo.text}</Tag>;
  };

  const getPaymentMethodText = (method: string) => {
    const methodMap: Record<string, string> = {
      stripe: 'Stripe 支付',
      points: '积分支付',
      mixed: '混合支付',
    };
    return methodMap[method] || method;
  };

  const columns = [
    {
      title: '任务',
      dataIndex: 'task',
      key: 'task',
      render: (task: PaymentRecord['task']) => (
        task ? (
          <Button
            type="link"
            onClick={() => localizedNavigate(`/tasks/${task.id}`)}
            style={{ padding: 0 }}
          >
            {task.title}
          </Button>
        ) : (
          <span style={{ color: '#999' }}>任务已删除</span>
        )
      ),
    },
    {
      title: '支付方式',
      dataIndex: 'payment_method',
      key: 'payment_method',
      render: (method: string) => getPaymentMethodText(method),
    },
    {
      title: '总金额',
      dataIndex: 'total_amount_display',
      key: 'total_amount',
      render: (amount: string, record: PaymentRecord) => (
        <span>£{amount}</span>
      ),
    },
    {
      title: '积分抵扣',
      dataIndex: 'points_used_display',
      key: 'points_used',
      render: (amount: string | null) => (
        amount ? <span style={{ color: '#52c41a' }}>£{amount}</span> : <span>-</span>
      ),
    },
    {
      title: '优惠券',
      dataIndex: 'coupon_discount_display',
      key: 'coupon_discount',
      render: (amount: string | null) => (
        amount ? <span style={{ color: '#52c41a' }}>£{amount}</span> : <span>-</span>
      ),
    },
    {
      title: '实际支付',
      dataIndex: 'final_amount_display',
      key: 'final_amount',
      render: (amount: string) => (
        <span style={{ fontWeight: 'bold' }}>£{amount}</span>
      ),
    },
    {
      title: '状态',
      dataIndex: 'status',
      key: 'status',
      render: (status: string) => getStatusTag(status),
    },
    {
      title: '支付时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time: string) => (
        <span>{dayjs(time).format('YYYY-MM-DD HH:mm:ss')}</span>
      ),
    },
  ];

  if (!user) {
    return (
      <>
        <div style={{ padding: '40px', textAlign: 'center' }}>
          <h2>请先登录</h2>
          <Button type="primary" onClick={() => setShowLoginModal(true)}>
            登录
          </Button>
        </div>
        <LoginModal
          isOpen={showLoginModal}
          onClose={() => setShowLoginModal(false)}
          onSuccess={() => {
            setShowLoginModal(false);
            window.location.reload();
          }}
        />
      </>
    );
  }

  return (
    <div style={{ maxWidth: '1200px', margin: '40px auto', padding: '0 20px' }}>
      <Card
        title="支付历史记录"
        extra={
          <Select
            value={statusFilter}
            onChange={(value) => {
              setStatusFilter(value);
              setSkip(0);
            }}
            style={{ width: 150 }}
            allowClear
            placeholder="筛选状态"
          >
            <Option value="succeeded">支付成功</Option>
            <Option value="pending">待支付</Option>
            <Option value="failed">支付失败</Option>
            <Option value="canceled">已取消</Option>
          </Select>
        }
      >
        <Spin spinning={loading}>
          <Table
            columns={columns}
            dataSource={payments}
            rowKey="id"
            pagination={false}
            scroll={{ x: 'max-content' }}
          />
          <div style={{ marginTop: '16px', textAlign: 'right' }}>
            <Pagination
              current={Math.floor(skip / limit) + 1}
              pageSize={limit}
              total={total}
              onChange={(page, pageSize) => {
                setSkip((page - 1) * pageSize);
                setLimit(pageSize);
              }}
              showSizeChanger
              showTotal={(total) => `共 ${total} 条记录`}
            />
          </div>
        </Spin>
      </Card>
    </div>
  );
};

export default PaymentHistory;

