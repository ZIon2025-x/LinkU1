import React, { useState, useEffect } from 'react';
import { Input, Select, Spin, message } from 'antd';
import { loadStripe, StripeElementsOptions } from '@stripe/stripe-js';
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements
} from '@stripe/react-stripe-js';
import api from '../../api';

const { Option } = Select;

// 初始化 Stripe
const stripePromise = loadStripe(
  (process.env as any).REACT_APP_STRIPE_PUBLISHABLE_KEY || 
  (process.env as any).STRIPE_PUBLISHABLE_KEY || 
  ''
);

interface InlinePaymentFormProps {
  taskId: number;
  clientSecret?: string | null;  // 直接传入的 client_secret（用于批准申请时的支付）
  paymentIntentId?: string | null;  // Payment Intent ID（用于5分钟超时检查）
  amount?: number;  // 支付金额（便士，用于批准申请时显示）
  amountDisplay?: string;  // 支付金额显示（用于批准申请时显示）
  currency?: string;  // 货币（用于批准申请时显示）
  onSuccess: () => void;
  onCancel?: () => void;
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

// Stripe 支付表单组件
const PaymentForm: React.FC<{
  clientSecret: string;
  amount: number;
  currency: string;
  onSuccess: () => void;
  onError: (error: string) => void;
  onCancel?: () => void;
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
      const { error: confirmError, paymentIntent } = await stripe.confirmPayment({
        elements,
        confirmParams: {},
        redirect: 'if_required',
      });

      if (confirmError) {
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

      if (paymentIntent && paymentIntent.status === 'succeeded') {
        message.success('支付成功！');
        onSuccess();
      } else if (paymentIntent && paymentIntent.status === 'requires_action') {
        setError('支付需要额外验证，请完成验证');
        onError('支付需要额外验证，请完成验证');
      } else {
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
      <div style={{ marginBottom: '20px' }}>
        <PaymentElement 
          id="payment-element"
          options={{
            layout: 'tabs'
          }}
        />
      </div>
      
      {error && (
        <div style={{ color: '#ff4d4f', marginBottom: '16px', fontSize: '14px' }}>
          {error}
        </div>
      )}

      <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            disabled={processing}
            style={{
              padding: '8px 16px',
              background: '#fff',
              color: '#666',
              border: '1px solid #d9d9d9',
              borderRadius: '4px',
              cursor: processing ? 'not-allowed' : 'pointer',
            }}
          >
            取消
          </button>
        )}
        <button
          type="submit"
          disabled={!stripe || processing}
          style={{
            padding: '8px 16px',
            background: processing ? '#d9d9d9' : '#1890ff',
            color: '#fff',
            border: 'none',
            borderRadius: '4px',
            cursor: processing ? 'not-allowed' : 'pointer',
            fontWeight: 500,
          }}
        >
          {processing ? '处理中...' : `支付 £${(amount / 100).toFixed(2)}`}
        </button>
      </div>
    </form>
  );
};

// 主组件
const InlinePaymentForm: React.FC<InlinePaymentFormProps> = ({
  taskId,
  clientSecret: propClientSecret,
  paymentIntentId,
  amount: propAmount,
  amountDisplay: propAmountDisplay,
  currency: propCurrency = 'GBP',
  onSuccess,
  onCancel
}) => {
  const [paymentData, setPaymentData] = useState<PaymentData | null>(null);
  // 只支持 Stripe 支付，积分不能作为支付手段
  const [couponCode, setCouponCode] = useState<string>('');
  const [pointsBalance, setPointsBalance] = useState<number>(0);
  const [loading, setLoading] = useState(false);
  const [stripeLoaded, setStripeLoaded] = useState(false);

  // 如果已经有 clientSecret，直接显示支付表单
  useEffect(() => {
    if (propClientSecret) {
      stripePromise.then(() => {
        setStripeLoaded(true);
      }).catch((err) => {
        console.error('Failed to load Stripe:', err);
        message.error('无法加载支付服务');
      });
    }
  }, [propClientSecret]);

  // 加载积分余额
  useEffect(() => {
    const loadPointsBalance = async () => {
      try {
        const response = await api.get('/api/coupon-points/points/balance');
        setPointsBalance(response.data.balance || 0);
      } catch (err) {
        // 忽略错误
      }
    };
    loadPointsBalance();
  }, []);

  const handleCreatePayment = async () => {
    setLoading(true);
    try {
      const requestData: any = {
        payment_method: 'stripe', // 只支持 Stripe 支付
      };

      if (couponCode) {
        requestData.coupon_code = couponCode.toUpperCase();
      }

      const response = await api.post(
        `/api/coupon-points/tasks/${taskId}/payment`,
        requestData
      );

      setPaymentData(response.data);

      // 如果使用优惠券全额抵扣，直接成功
      if (response.data.final_amount === 0) {
        message.success('支付成功！');
        onSuccess();
      } else {
        // 加载 Stripe
        stripePromise.then(() => {
          setStripeLoaded(true);
        }).catch((err) => {
          console.error('Failed to load Stripe:', err);
          message.error('无法加载支付服务');
        });
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

  // 如果已经有 clientSecret，直接显示支付表单
  if (propClientSecret) {
    return (
      <div style={{ padding: '20px', background: '#f5f5f5', borderRadius: '8px', marginTop: '20px' }}>
        <h3 style={{ marginBottom: '16px', fontSize: '16px', fontWeight: 600 }}>
          完成支付
        </h3>
        {propAmountDisplay && (
          <div style={{ marginBottom: '16px', padding: '12px', background: '#fff', borderRadius: '4px' }}>
            <div style={{ fontSize: '18px', fontWeight: 'bold' }}>
              支付金额: £{propAmountDisplay}
            </div>
            {propAmount && (
              <div style={{ fontSize: '14px', color: '#666', marginTop: '4px' }}>
                任务接受人将收到 £{((propAmount - (propAmount * 0.1)) / 100).toFixed(2)}（已扣除平台服务费）
              </div>
            )}
          </div>
        )}
        {stripeLoaded ? (
          <Elements 
            stripe={stripePromise} 
            options={{
              clientSecret: propClientSecret,
              appearance: {
                theme: 'stripe',
                variables: {
                  colorPrimary: '#1890ff',
                  colorBackground: '#ffffff',
                  colorText: 'rgba(0, 0, 0, 0.85)',
                  colorDanger: '#ff4d4f',
                  colorSuccess: '#52c41a',
                  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
                  fontSizeBase: '16px',
                  spacingUnit: '4px',
                  borderRadius: '4px',
                },
                inputs: 'spaced',
                labels: 'auto',
              } as any,
              loader: 'auto',
            } as StripeElementsOptions}
          >
            <PaymentForm
              clientSecret={propClientSecret}
              amount={0} // 金额会在 PaymentElement 中显示
              currency="GBP"
              onSuccess={handlePaymentSuccess}
              onError={handlePaymentError}
              onCancel={onCancel}
            />
          </Elements>
        ) : (
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <Spin size="large" />
            <div style={{ marginTop: '16px' }}>正在加载支付表单...</div>
          </div>
        )}
      </div>
    );
  }

  // 如果没有 paymentData，显示支付方式选择
  if (!paymentData) {
    return (
      <div style={{ padding: '20px', background: '#f5f5f5', borderRadius: '8px', marginTop: '20px' }}>
        <h3 style={{ marginBottom: '16px', fontSize: '16px', fontWeight: 600 }}>
          任务支付
        </h3>

        {/* 优惠券输入 */}
        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontWeight: 500 }}>
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
    );
  }

  // 如果使用优惠券全额抵扣，已成功
  if (paymentData.final_amount === 0) {
    return (
      <div style={{ padding: '20px', background: '#f0f9ff', borderRadius: '8px', marginTop: '20px', textAlign: 'center' }}>
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
    );
  }

  // 显示支付信息和 Stripe 支付表单
  return (
    <div style={{ padding: '20px', background: '#f5f5f5', borderRadius: '8px', marginTop: '20px' }}>
      <h3 style={{ marginBottom: '16px', fontSize: '16px', fontWeight: 600 }}>
        完成支付
      </h3>

      {/* 显示支付信息 */}
      <div style={{ marginBottom: '20px', padding: '12px', background: '#fff', borderRadius: '4px' }}>
        <div style={{ marginBottom: '8px' }}>
          <strong>总金额:</strong> £{paymentData.total_amount_display}
        </div>
        {paymentData.coupon_discount_display && (
          <div style={{ marginBottom: '8px', color: '#52c41a' }}>
            <strong>优惠券折扣:</strong> £{paymentData.coupon_discount_display}
          </div>
        )}
        <div style={{ marginBottom: '8px', fontSize: '18px', fontWeight: 'bold' }}>
          <strong>最终支付:</strong> £{paymentData.final_amount_display}
        </div>
        {paymentData.note && (
          <div style={{ marginTop: '12px', padding: '8px', background: '#f0f0f0', borderRadius: '4px', fontSize: '14px' }}>
            {paymentData.note}
          </div>
        )}
      </div>

      {/* Stripe 支付表单 */}
      {paymentData.client_secret && stripeLoaded ? (
        <Elements 
          stripe={stripePromise} 
          options={{
            clientSecret: paymentData.client_secret,
            appearance: {
              theme: 'stripe',
              variables: {
                colorPrimary: '#1890ff',
                colorBackground: '#ffffff',
                colorText: 'rgba(0, 0, 0, 0.85)',
                colorDanger: '#ff4d4f',
                colorSuccess: '#52c41a',
                fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif',
                fontSizeBase: '16px',
                spacingUnit: '4px',
                borderRadius: '4px',
              },
              inputs: 'spaced',
              labels: 'auto',
            } as any,
            loader: 'auto',
          } as StripeElementsOptions}
        >
          <PaymentForm
            clientSecret={paymentData.client_secret}
            amount={paymentData.final_amount}
            currency={paymentData.currency}
            onSuccess={handlePaymentSuccess}
            onError={handlePaymentError}
            onCancel={onCancel}
          />
        </Elements>
      ) : (
        <div style={{ textAlign: 'center', padding: '20px' }}>
          <Spin />
          <div style={{ marginTop: '16px' }}>正在准备支付...</div>
        </div>
      )}
    </div>
  );
};

export default InlinePaymentForm;

