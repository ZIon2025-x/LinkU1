import React, { useState, useEffect } from 'react';
import { loadStripe, StripeElementsOptions } from '@stripe/stripe-js';
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements
} from '@stripe/react-stripe-js';
import { Button, message, Spin } from 'antd';
import api from '../../api';

// 初始化 Stripe
// 注意：如果使用标准 React，需要 REACT_APP_ 前缀
// 但当前项目使用 STRIPE_PUBLISHABLE_KEY
const stripePromise = loadStripe(
  (process.env as any).REACT_APP_STRIPE_PUBLISHABLE_KEY || 
  (process.env as any).STRIPE_PUBLISHABLE_KEY || 
  ''
);

interface StripePaymentFormProps {
  clientSecret: string;
  amount: number;
  currency: string;
  onSuccess: () => void;
  onError: (error: string) => void;
  onCancel?: () => void;
}

// 支付表单组件
const PaymentForm: React.FC<StripePaymentFormProps> = ({
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
      // 使用 PaymentElement 确认支付（支持多种支付方式）
      // 参考 Stripe Payment Intents API sample code 的实现方式
      // 注意：我们使用嵌入式支付模式（redirect: 'if_required'），而不是重定向模式（return_url）
      // 这是因为我们的支付界面是弹窗形式，用户不需要离开当前页面
      // 对于需要重定向的支付方式（如某些银行支付），Stripe 会自动处理
      const { error: confirmError, paymentIntent } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          // 对于嵌入式支付，不需要 return_url
          // 如果需要重定向（如某些支付方式），Stripe 会自动处理
        },
        redirect: 'if_required', // 只在需要时重定向（如 3D Secure）
      });

      // 错误处理（参考 Stripe sample code 的错误处理逻辑）
      // This point will only be reached if there is an immediate error when
      // confirming the payment. Otherwise, the payment will be processed or
      // the user will be redirected for additional authentication (3D Secure, etc.)
      if (confirmError) {
        // 处理卡片错误或验证错误（与官方 sample code 一致）
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

      // 支付成功（嵌入式模式需要检查 paymentIntent 状态）
      // 在重定向模式下，用户会被重定向到 return_url，不会到达这里
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
      <div style={{ marginBottom: '20px' }}>
        <PaymentElement 
          id="payment-element"
          options={{
            // 官方 sample code 使用 'accordion' 布局
            // 我们使用 'tabs' 布局，更适合弹窗设计
            // 两者都是有效的布局选项，只是 UI 风格不同
            layout: 'tabs' // 使用标签页布局，支持多种支付方式
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
          <Button onClick={onCancel} disabled={processing}>
            取消
          </Button>
        )}
        <Button
          type="primary"
          htmlType="submit"
          disabled={!stripe || processing}
          loading={processing}
        >
          {processing ? '处理中...' : `支付 £${(amount / 100).toFixed(2)}`}
        </Button>
      </div>
    </form>
  );
};

// 主组件：包装 Stripe Elements
const StripePaymentForm: React.FC<StripePaymentFormProps> = (props) => {
  const [stripeLoaded, setStripeLoaded] = useState(false);

  useEffect(() => {
    stripePromise.then(() => {
      setStripeLoaded(true);
    }).catch((err) => {
      console.error('Failed to load Stripe:', err);
      props.onError('无法加载支付服务');
    });
  }, [props]);

  if (!stripeLoaded) {
    return (
      <div style={{ textAlign: 'center', padding: '40px' }}>
        <Spin size="large" />
        <div style={{ marginTop: '16px' }}>正在加载支付表单...</div>
      </div>
    );
  }

  // Elements 配置（参考 Stripe Payment Intents API sample code）
  const options: StripeElementsOptions = {
    clientSecret: props.clientSecret,
    appearance: {
      theme: 'stripe', // 与官方 sample code 一致
      // 自定义外观以匹配网站设计（官方 sample code 只使用 theme: 'stripe'）
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
      // inputs 和 labels 是有效的 appearance 属性，但类型定义可能不完整
      inputs: 'spaced', // 输入框之间有间距
      labels: 'auto', // 标签自动调整位置
    } as any,
    // Enable the skeleton loader UI for optimal loading（与官方 sample code 一致）
    loader: 'auto',
  };

  return (
    <Elements stripe={stripePromise} options={options}>
      <PaymentForm {...props} />
    </Elements>
  );
};

export default StripePaymentForm;

