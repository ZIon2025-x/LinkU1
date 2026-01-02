import React, { useState, useEffect } from 'react';
import { Modal, Spin, message, Input, Select, Card } from 'antd';
import { loadStripe, StripeElementsOptions } from '@stripe/stripe-js';
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements
} from '@stripe/react-stripe-js';
import api from '../../api';
import { useLocalizedNavigation } from '../../hooks/useLocalizedNavigation';

const { Option } = Select;

// 初始化 Stripe
const stripePromise = loadStripe(
  (process.env as any).REACT_APP_STRIPE_PUBLISHABLE_KEY || 
  (process.env as any).STRIPE_PUBLISHABLE_KEY || 
  ''
);

interface PaymentModalProps {
  visible: boolean;
  taskId: number;
  taskTitle?: string;
  onSuccess: () => void;
  onCancel: () => void;
}

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

// 支付表单组件
const PaymentForm: React.FC<{
  clientSecret: string;
  amount: number;
  currency: string;
  onSuccess: () => void;
  onError: (error: string) => void;
  onCancel: () => void;
}> = ({
  clientSecret,
  amount,
  currency,
  onSuccess,
  onError,
  onCancel
}) => {
  const stripe = useStripe();
  const elements = useElements();
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();

    if (!stripe || !elements) {
      return;
    }

    setProcessing(true);
    setError(null);

    try {
      // 使用 PaymentElement 确认支付（支持多种支付方式，包括 Apple Pay）
      // 参考 Stripe sample code 的实现方式
      const { error: confirmError, paymentIntent } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          // 对于嵌入式支付，不需要 return_url
          // 如果需要重定向（如某些支付方式），Stripe 会自动处理
        },
        redirect: 'if_required', // 只在需要时重定向（如 3D Secure）
      });

      // 错误处理（参考 Stripe sample code）
      if (confirmError) {
        // 处理卡片错误或验证错误
        if (confirmError.type === 'card_error' || confirmError.type === 'validation_error') {
          setError(confirmError.message || '支付失败');
          onError(confirmError.message || '支付失败');
        } else {
          setError('支付过程中发生意外错误');
          onError('支付过程中发生意外错误');
        }
        setProcessing(false);
        return;
      }

      // 支付成功
      if (paymentIntent && paymentIntent.status === 'succeeded') {
        message.success('支付成功！');
        onSuccess();
      } else if (paymentIntent && paymentIntent.status === 'requires_action') {
        // 需要额外操作（如 3D Secure），Stripe 会自动处理
        // 这种情况通常不会到达这里，因为 confirmPayment 会等待用户完成操作
        setError('支付需要额外验证，请完成验证');
        onError('支付需要额外验证，请完成验证');
      } else {
        // 其他状态（如 processing）
        setError(`支付状态: ${paymentIntent?.status || '未知'}`);
        onError(`支付状态: ${paymentIntent?.status || '未知'}`);
      }
    } catch (err: any) {
      const errorMessage = err.message || '支付处理出错';
      setError(errorMessage);
      onError(errorMessage);
    } finally {
      setProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} style={{ width: '100%' }}>
      <div style={{ marginBottom: '20px', minHeight: '200px' }}>
        <PaymentElement 
          options={{
            layout: 'tabs', // 使用标签页布局，支持多种支付方式
            // PaymentElement 会自动根据 Payment Intent 的 payment_method_types 
            // 检测并显示可用的支付方式（包括 Apple Pay、Google Pay 等）
            // 在支持的设备和浏览器上会自动显示钱包选项
          }}
        />
      </div>
      
      {error && (
        <div style={{ color: '#ff4d4f', marginBottom: '16px', fontSize: '14px', padding: '8px', background: '#fff2f0', borderRadius: '4px' }}>
          {error}
        </div>
      )}

      <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
        <button
          type="button"
          onClick={onCancel}
          disabled={processing}
          style={{
            padding: '8px 16px',
            border: '1px solid #d9d9d9',
            borderRadius: '4px',
            background: '#fff',
            cursor: processing ? 'not-allowed' : 'pointer',
            opacity: processing ? 0.6 : 1
          }}
        >
          取消
        </button>
        <button
          type="submit"
          disabled={!stripe || processing}
          style={{
            padding: '8px 24px',
            border: 'none',
            borderRadius: '4px',
            background: processing ? '#d9d9d9' : '#1890ff',
            color: '#fff',
            cursor: (!stripe || processing) ? 'not-allowed' : 'pointer',
            opacity: (!stripe || processing) ? 0.6 : 1,
            fontWeight: 500
          }}
        >
          {processing ? '处理中...' : `支付 £${(amount / 100).toFixed(2)}`}
        </button>
      </div>
    </form>
  );
};

// 主支付弹窗组件
const PaymentModal: React.FC<PaymentModalProps> = ({
  visible,
  taskId,
  taskTitle,
  onSuccess,
  onCancel
}) => {
  const { navigate: localizedNavigate } = useLocalizedNavigation();
  const [loading, setLoading] = useState(false);
  const [paymentData, setPaymentData] = useState<PaymentData | null>(null);
  const [paymentMethod, setPaymentMethod] = useState<'stripe' | 'points' | 'mixed'>('stripe');
  const [pointsAmount, setPointsAmount] = useState<number>(0);
  const [couponCode, setCouponCode] = useState<string>('');
  const [pointsBalance, setPointsBalance] = useState<number>(0);
  const [stripeLoaded, setStripeLoaded] = useState(false);

  // 加载积分余额
  useEffect(() => {
    if (visible) {
      const loadPointsBalance = async () => {
        try {
          const response = await api.get('/api/coupon-points/points/balance');
          setPointsBalance(response.data.balance || 0);
        } catch (err) {
          // 忽略错误
        }
      };
      loadPointsBalance();
    }
  }, [visible]);

  // 加载 Stripe
  useEffect(() => {
    if (visible && paymentData?.client_secret) {
      stripePromise.then(() => {
        setStripeLoaded(true);
      }).catch((err) => {
        console.error('Failed to load Stripe:', err);
        message.error('无法加载支付服务');
      });
    }
  }, [visible, paymentData]);

  const handleCreatePayment = async () => {
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
        onSuccess();
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
    onSuccess();
  };

  const handlePaymentError = (error: string) => {
    message.error(`支付失败: ${error}`);
  };

  const handleCancel = () => {
    setPaymentData(null);
    setPaymentMethod('stripe');
    setPointsAmount(0);
    setCouponCode('');
    onCancel();
  };

  return (
    <Modal
      title={
        <div style={{ fontSize: '18px', fontWeight: 'bold' }}>
          {paymentData ? '完成支付' : '任务支付'}
        </div>
      }
      open={visible}
      onCancel={handleCancel}
      footer={null}
      width={600}
      destroyOnClose
    >
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
              <Option value="stripe">Stripe（信用卡/借记卡/Apple Pay）</Option>
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

          <button
            onClick={handleCreatePayment}
            disabled={loading}
            style={{
              width: '100%',
              padding: '12px',
              background: loading ? '#d9d9d9' : '#1890ff',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              fontSize: '16px',
              fontWeight: 500,
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.6 : 1
            }}
          >
            {loading ? '创建支付中...' : '创建支付'}
          </button>
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
              <button
                onClick={onSuccess}
                style={{
                  padding: '8px 24px',
                  background: '#1890ff',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '14px'
                }}
              >
                确定
              </button>
            </div>
          ) : paymentData.client_secret ? (
            // 显示 Stripe Elements 支付表单（支持 Apple Pay 等）
            stripeLoaded ? (
              <Elements 
                stripe={stripePromise} 
                options={(() => {
                  const elementsOptions: StripeElementsOptions = {
                    clientSecret: paymentData.client_secret,
                    appearance: {
                      theme: 'stripe',
                      // 自定义外观以匹配网站设计
                      variables: {
                        colorPrimary: '#1890ff', // 主色调（与网站主题一致）
                        colorBackground: '#ffffff', // 背景色
                        colorText: 'rgba(0, 0, 0, 0.85)', // 文本颜色
                        colorDanger: '#ff4d4f', // 错误颜色
                        colorSuccess: '#52c41a', // 成功颜色
                        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif', // 字体（与网站一致）
                        fontSizeBase: '16px', // 基础字体大小（确保移动端输入框至少 16px）
                        spacingUnit: '4px', // 基础间距单位
                        borderRadius: '4px', // 圆角（与网站一致）
                      },
                      // @ts-ignore - inputs 和 labels 是有效的 appearance 属性，但类型定义可能不完整
                      inputs: 'spaced', // 输入框之间有间距
                      // @ts-ignore
                      labels: 'auto', // 标签自动调整位置
                    },
                    loader: 'auto', // 启用骨架屏加载器，优化加载体验（与 Stripe sample code 一致）
                  };
                  return elementsOptions;
                })()}
              >
                <PaymentForm
                  clientSecret={paymentData.client_secret}
                  amount={paymentData.final_amount}
                  currency={paymentData.currency}
                  onSuccess={handlePaymentSuccess}
                  onError={handlePaymentError}
                  onCancel={handleCancel}
                />
              </Elements>
            ) : (
              <div style={{ textAlign: 'center', padding: '40px' }}>
                <Spin size="large" />
                <div style={{ marginTop: '16px' }}>正在加载支付表单...</div>
              </div>
            )
          ) : (
            <div style={{ textAlign: 'center', padding: '20px' }}>
              <Spin />
              <div style={{ marginTop: '16px' }}>正在准备支付...</div>
            </div>
          )}
        </div>
      )}
    </Modal>
  );
};

export default PaymentModal;

