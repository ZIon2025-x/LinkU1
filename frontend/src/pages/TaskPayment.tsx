import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Card, Button, Spin, message, Input, Select } from 'antd';
import api from '../api';
import StripePaymentForm from '../components/payment/StripePaymentForm';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';

const { Option } = Select;

interface PaymentData {
  payment_id: number | null;
  fee_type: string;
  total_amount: number;
  total_amount_display: string;
  points_used: number | null;
  points_used_display: string | null;
  coupon_discount: number | null;
  coupon_discount_display: string | null;
  stripe_amount: number | null;
  stripe_amount_display: string | null;
  currency: string;
  final_amount: number;
  final_amount_display: string;
  checkout_url: string | null;
  client_secret: string | null;
  payment_intent_id: string | null;
  note: string;
}

const TaskPayment: React.FC = () => {
  const { taskId } = useParams<{ taskId: string }>();
  const navigate = useNavigate();
  const { t } = useLanguage();
  const { navigate: localizedNavigate } = useLocalizedNavigation();
  
  const [loading, setLoading] = useState(false);
  const [paymentData, setPaymentData] = useState<PaymentData | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<'stripe' | 'points' | 'mixed'>('stripe');
  const [pointsAmount, setPointsAmount] = useState<number>(0);
  const [couponCode, setCouponCode] = useState<string>('');
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [pointsBalance, setPointsBalance] = useState<number>(0);

  useEffect(() => {
    // 检查用户登录状态
    const checkUser = async () => {
      try {
        const userData = await api.get('/api/users/me');
        setUser(userData.data);
        
        // 获取积分余额
        try {
          const pointsResponse = await api.get('/api/coupon-points/points/balance');
          setPointsBalance(pointsResponse.data.balance || 0);
        } catch (err) {
          // 忽略积分余额获取错误
        }
      } catch (error) {
        setShowLoginModal(true);
      }
    };
    
    checkUser();
  }, []);

  const handleCreatePayment = async () => {
    if (!taskId) {
      message.error('任务ID无效');
      return;
    }

    if (!user) {
      setShowLoginModal(true);
      return;
    }

    setLoading(true);
    try {
      const requestData: any = {
        payment_method: paymentMethod,
      };

      if (paymentMethod === 'points' || paymentMethod === 'mixed') {
        requestData.points_amount = pointsAmount * 100; // 转换为便士
      }

      if (couponCode) {
        requestData.coupon_code = couponCode.toUpperCase();
      }

      const response = await api.post(
        `/api/coupon-points/tasks/${taskId}/payment`,
        requestData
      );

      setPaymentData(response.data);

      // 如果纯积分支付，直接成功
      if (response.data.final_amount === 0) {
        message.success('支付成功！');
        setTimeout(() => {
          localizedNavigate(`/tasks/${taskId}`);
        }, 1500);
      }
    } catch (error: any) {
      const errorMessage = error.response?.data?.detail || error.message || '创建支付失败';
      message.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handlePaymentSuccess = () => {
    message.success('支付成功！');
    // 开始轮询支付状态，确保 webhook 已处理
    startPaymentStatusPolling();
  };

  // 支付状态轮询（作为 webhook 的备选方案）
  const startPaymentStatusPolling = async () => {
    if (!taskId || !paymentData?.payment_intent_id) {
      return;
    }

    let pollCount = 0;
    const maxPolls = 10; // 最多轮询 10 次
    const pollInterval = 2000; // 每 2 秒轮询一次

    const poll = async () => {
      if (pollCount >= maxPolls) {
        // 轮询超时，但支付可能已成功（webhook 延迟），直接跳转
        setTimeout(() => {
          localizedNavigate(`/tasks/${taskId}`);
        }, 1500);
        return;
      }

      try {
        const response = await api.get(`/api/coupon-points/tasks/${taskId}/payment-status`);
        const { is_paid, payment_details } = response.data;

        if (is_paid && payment_details?.status === 'succeeded') {
          // 支付成功，停止轮询并跳转
          message.success('支付已确认！');
          setTimeout(() => {
            localizedNavigate(`/tasks/${taskId}`);
          }, 1000);
          return;
        }

        // 继续轮询
        pollCount++;
        setTimeout(poll, pollInterval);
      } catch (error) {
        // 轮询出错，但可能支付已成功，继续轮询
        pollCount++;
        if (pollCount < maxPolls) {
          setTimeout(poll, pollInterval);
        } else {
          // 轮询超时，直接跳转（让用户自己检查）
    setTimeout(() => {
      localizedNavigate(`/tasks/${taskId}`);
    }, 1500);
        }
      }
    };

    // 延迟 2 秒后开始第一次轮询（给 webhook 一些时间）
    setTimeout(poll, pollInterval);
  };

  const handlePaymentError = (error: string) => {
    message.error(`支付失败: ${error}`);
  };

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
    <div style={{ maxWidth: '600px', margin: '40px auto', padding: '0 20px' }}>
      <Card title="支付平台服务费">
        {!paymentData ? (
          <div>
            {/* 支付方式选择 */}
            <div style={{ marginBottom: '24px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>
                支付方式
              </label>
              <Select
                value={paymentMethod}
                onChange={(value) => setPaymentMethod(value)}
                style={{ width: '100%' }}
              >
                <Option value="stripe">Stripe（信用卡/借记卡）</Option>
                <Option value="points">积分支付</Option>
                <Option value="mixed">混合支付（积分 + Stripe）</Option>
              </Select>
            </div>

            {/* 积分输入（如果使用积分或混合支付） */}
            {(paymentMethod === 'points' || paymentMethod === 'mixed') && (
              <div style={{ marginBottom: '24px' }}>
                <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>
                  使用积分（当前余额: £{(pointsBalance / 100).toFixed(2)}）
                </label>
                <Input
                  type="number"
                  value={pointsAmount}
                  onChange={(e) => setPointsAmount(parseFloat(e.target.value) || 0)}
                  placeholder="输入积分数量"
                  addonAfter="GBP"
                  min={0}
                  max={pointsBalance / 100}
                />
              </div>
            )}

            {/* 优惠券输入 */}
            <div style={{ marginBottom: '24px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>
                优惠券代码（可选）
              </label>
              <Input
                value={couponCode}
                onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                placeholder="输入优惠券代码"
              />
            </div>

            <Button
              type="primary"
              onClick={handleCreatePayment}
              loading={loading}
              block
              size="large"
            >
              {loading ? '创建支付中...' : '创建支付'}
            </Button>
          </div>
        ) : (
          <div>
            {/* 显示支付信息 */}
            <div style={{ marginBottom: '24px' }}>
              <div style={{ marginBottom: '12px' }}>
                <strong>总金额:</strong> £{paymentData.total_amount_display}
              </div>
              {paymentData.points_used_display && (
                <div style={{ marginBottom: '12px', color: '#52c41a' }}>
                  <strong>积分抵扣:</strong> £{paymentData.points_used_display}
                </div>
              )}
              {paymentData.coupon_discount_display && (
                <div style={{ marginBottom: '12px', color: '#52c41a' }}>
                  <strong>优惠券折扣:</strong> £{paymentData.coupon_discount_display}
                </div>
              )}
              <div style={{ marginBottom: '12px', fontSize: '18px', fontWeight: 'bold' }}>
                <strong>最终支付:</strong> £{paymentData.final_amount_display}
              </div>
              <div style={{ marginTop: '16px', padding: '12px', background: '#f0f0f0', borderRadius: '4px' }}>
                {paymentData.note}
              </div>
            </div>

            {/* 如果纯积分支付，已成功 */}
            {paymentData.final_amount === 0 ? (
              <div style={{ textAlign: 'center', padding: '20px' }}>
                <div style={{ fontSize: '18px', color: '#52c41a', marginBottom: '16px' }}>
                  ✓ 支付成功！
                </div>
                <Button type="primary" onClick={() => localizedNavigate(`/tasks/${taskId}`)}>
                  返回任务详情
                </Button>
              </div>
            ) : paymentData.client_secret ? (
              // 显示 Stripe Elements 支付表单
              <StripePaymentForm
                clientSecret={paymentData.client_secret}
                amount={paymentData.final_amount}
                currency={paymentData.currency}
                onSuccess={handlePaymentSuccess}
                onError={handlePaymentError}
                onCancel={() => {
                  setPaymentData(null);
                }}
              />
            ) : (
              <div style={{ textAlign: 'center', padding: '20px' }}>
                <Spin />
                <div style={{ marginTop: '16px' }}>正在准备支付...</div>
              </div>
            )}
          </div>
        )}
      </Card>
    </div>
  );
};

export default TaskPayment;

