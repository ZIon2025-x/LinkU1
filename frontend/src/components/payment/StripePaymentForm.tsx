import React, { useState, useEffect } from 'react';
import { loadStripe, StripeElementsOptions } from '@stripe/stripe-js';
import {
  Elements,
  CardElement,
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

    const cardElement = elements.getElement(CardElement);

    if (!cardElement) {
      setError('支付表单未加载');
      setProcessing(false);
      return;
    }

    try {
      // 确认支付
      const { error: confirmError, paymentIntent } = await stripe.confirmCardPayment(
        clientSecret,
        {
          payment_method: {
            card: cardElement,
          }
        }
      );

      if (confirmError) {
        setError(confirmError.message || '支付失败');
        onError(confirmError.message || '支付失败');
      } else if (paymentIntent && paymentIntent.status === 'succeeded') {
        message.success('支付成功！');
        onSuccess();
      } else {
        setError('支付状态异常');
        onError('支付状态异常');
      }
    } catch (err: any) {
      const errorMessage = err.message || '支付处理出错';
      setError(errorMessage);
      onError(errorMessage);
    } finally {
      setProcessing(false);
    }
  };

  const cardElementOptions = {
    style: {
      base: {
        fontSize: '16px',
        color: '#424770',
        '::placeholder': {
          color: '#aab7c4',
        },
      },
      invalid: {
        color: '#9e2146',
      },
    },
  };

  return (
    <form onSubmit={handleSubmit} style={{ width: '100%' }}>
      <div style={{ marginBottom: '20px' }}>
        <CardElement options={cardElementOptions} />
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

  const options: StripeElementsOptions = {
    clientSecret: props.clientSecret,
    appearance: {
      theme: 'stripe',
    },
  };

  return (
    <Elements stripe={stripePromise} options={options}>
      <PaymentForm {...props} />
    </Elements>
  );
};

export default StripePaymentForm;

