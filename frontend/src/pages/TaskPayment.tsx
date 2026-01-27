import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { Card, Button, Spin, message, Input, Select, Image } from 'antd';
import api from '../api';
import StripePaymentForm from '../components/payment/StripePaymentForm';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LoginModal from '../components/LoginModal';
import LazyImage from '../components/LazyImage';
import { obfuscateLocation } from '../utils/formatUtils';
import { logger } from '../utils/logger';
import { ensureAbsoluteImageUrl } from '../utils/imageUtils';

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

interface TaskInfo {
  id: number;
  title: string;
  images: string[];
  task_type: string;
  base_reward: number;
  agreed_reward: number | null;
  currency: string;
  location: string;
}

const TaskPayment: React.FC = () => {
  const { taskId } = useParams<{ taskId: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { t, language } = useLanguage();
  const { navigate: localizedNavigate } = useLocalizedNavigation();
  
  const [loading, setLoading] = useState(false);
  const [paymentData, setPaymentData] = useState<PaymentData | null>(null);
  const [paymentMethod] = useState<'stripe'>('stripe'); // 只支持 Stripe 支付
  const [couponCode, setCouponCode] = useState<string>('');
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [pointsBalance, setPointsBalance] = useState<number>(0);
  const [taskInfo, setTaskInfo] = useState<TaskInfo | null>(null);
  const [loadingTask, setLoadingTask] = useState(true);
  const [returnUrl, setReturnUrl] = useState<string | null>(null);
  const [returnType, setReturnType] = useState<string | null>(null);

  // 加载任务信息
  useEffect(() => {
    const loadTaskInfo = async () => {
      if (!taskId) return;
      
      try {
        setLoadingTask(true);
        const response = await api.get(`/api/tasks/${taskId}`);
        const task = response.data;
        
        // 解析任务图片
        let images: string[] = [];
        if (task.images) {
          try {
            if (typeof task.images === 'string') {
              images = JSON.parse(task.images);
            } else if (Array.isArray(task.images)) {
              images = task.images;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
        
        setTaskInfo({
          id: task.id,
          title: task.title,
          images: images,
          task_type: task.task_type,
          base_reward: task.base_reward,
          agreed_reward: task.agreed_reward,
          currency: task.currency || 'GBP',
          location: task.location || '',
        });
      } catch (error) {
        console.error('Failed to load task info:', error);
      } finally {
        setLoadingTask(false);
      }
    };
    
    loadTaskInfo();
  }, [taskId]);

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

  // 检查 URL 参数中是否有支付信息和返回 URL
  useEffect(() => {
    const clientSecret = searchParams.get('client_secret');
    const paymentIntentId = searchParams.get('payment_intent_id');
    const amount = searchParams.get('amount');
    const amountDisplay = searchParams.get('amount_display');
    const returnUrlParam = searchParams.get('return_url');
    const returnTypeParam = searchParams.get('return_type');

    // 保存返回 URL 和类型
    if (returnUrlParam) {
      setReturnUrl(returnUrlParam);
    }
    if (returnTypeParam) {
      setReturnType(returnTypeParam);
    }

    if (clientSecret && paymentIntentId && taskId) {
      // 从批准申请跳转过来，直接使用已有的支付信息
      setPaymentData({
        payment_id: null,
        fee_type: 'task_amount',
        total_amount: amount ? parseInt(amount) : 0,
        total_amount_display: amountDisplay || '0.00',
        points_used: null,
        points_used_display: null,
        coupon_discount: null,
        coupon_discount_display: null,
        stripe_amount: amount ? parseInt(amount) : null,
        stripe_amount_display: amountDisplay || null,
        currency: 'GBP',
        final_amount: amount ? parseInt(amount) : 0,
        final_amount_display: amountDisplay || '0.00',
        checkout_url: null,
        client_secret: clientSecret,
        payment_intent_id: paymentIntentId,
        note: language === 'zh' ? '请完成支付以确认批准申请' : 'Please complete payment to confirm the application approval'
      });
    }
  }, [searchParams, taskId, language]);

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
        message.success(language === 'zh' ? '支付成功！' : 'Payment successful!');
        
        // 如果有返回 URL，通知原页面并关闭支付页面
        if (returnUrl && window.opener) {
          window.opener.postMessage({
            type: 'payment_success',
            taskId: taskId,
            message: language === 'zh' ? '申请已批准！' : 'Application approved!'
          }, '*');
          setTimeout(() => {
            window.close();
          }, 1500);
        } else {
          setTimeout(() => {
            localizedNavigate(`/tasks/${taskId}`);
          }, 1500);
        }
      }
    } catch (error: any) {
      const errorMessage = error.response?.data?.detail || error.message || '创建支付失败';
      message.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handlePaymentSuccess = () => {
    logger.log('✅ 前端支付成功回调触发, taskId:', taskId, 'paymentIntentId:', paymentData?.payment_intent_id);
    message.success(language === 'zh' ? '支付成功！' : 'Payment successful!');
    
    // 如果有返回 URL，通知原页面并关闭支付页面
    if (returnUrl && window.opener) {
      logger.log('📤 通知原页面支付成功, returnUrl:', returnUrl);
      // 通知原页面支付成功
      window.opener.postMessage({
        type: 'payment_success',
        taskId: taskId,
        paymentIntentId: paymentData?.payment_intent_id,
        message: language === 'zh' ? '申请已批准！' : 'Application approved!'
      }, '*');
      
      // 延迟关闭窗口，让用户看到成功消息
      setTimeout(() => {
        logger.log('🔒 关闭支付窗口');
        window.close();
      }, 1500);
    } else {
      logger.log('🔄 开始轮询支付状态');
      // 没有返回 URL，开始轮询支付状态，确保 webhook 已处理
      startPaymentStatusPolling();
    }
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
        // 轮询超时，但支付可能已成功（webhook 延迟）
        if (returnUrl && window.opener) {
          // 通知原页面（即使轮询超时，支付可能已成功）
          window.opener.postMessage({
            type: 'payment_success',
            taskId: taskId,
            message: language === 'zh' ? '申请已批准！' : 'Application approved!'
          }, '*');
          setTimeout(() => {
            window.close();
          }, 1500);
        } else {
          setTimeout(() => {
            localizedNavigate(`/tasks/${taskId}`);
          }, 1500);
        }
        return;
      }

      try {
        logger.log(`🔄 轮询支付状态 (${pollCount + 1}/${maxPolls}), taskId: ${taskId}, paymentIntentId: ${paymentData?.payment_intent_id}`);
        const response = await api.get(`/api/coupon-points/tasks/${taskId}/payment-status`);
        const { is_paid, payment_details } = response.data;
        
        logger.log('📊 支付状态响应:', { is_paid, status: payment_details?.status, paymentIntentId: payment_details?.payment_intent_id });

        if (is_paid && payment_details?.status === 'succeeded') {
          // 支付成功，停止轮询
          message.success(language === 'zh' ? '支付已确认！' : 'Payment confirmed!');
          
          // 设置 localStorage 标记，用于跨标签页通信
          if (taskId) {
            localStorage.setItem(`payment_success_${taskId}`, 'true');
            // 触发 storage 事件（同源页面可以监听）
            window.dispatchEvent(new StorageEvent('storage', {
              key: `payment_success_${taskId}`,
              newValue: 'true',
              storageArea: localStorage
            }));
          }
          
          // 如果有返回 URL，通知原页面并关闭支付页面
          if (returnUrl && window.opener) {
            window.opener.postMessage({
              type: 'payment_success',
              taskId: taskId,
              message: language === 'zh' ? '申请已批准！' : 'Application approved!'
            }, '*');
            setTimeout(() => {
              window.close();
            }, 1000);
          } else {
            // 没有返回 URL，跳转到任务详情
            setTimeout(() => {
              localizedNavigate(`/tasks/${taskId}`);
            }, 1000);
          }
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
          // 轮询超时
          if (returnUrl && window.opener) {
            window.opener.postMessage({
              type: 'payment_success',
              taskId: taskId,
              message: language === 'zh' ? '申请已批准！' : 'Application approved!'
            }, '*');
            setTimeout(() => {
              window.close();
            }, 1500);
          } else {
            setTimeout(() => {
              localizedNavigate(`/tasks/${taskId}`);
            }, 1500);
          }
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

  // 计算任务金额显示
  const taskReward = taskInfo?.agreed_reward || taskInfo?.base_reward || 0;
  const taskRewardDisplay = taskReward.toFixed(2);

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
      padding: '40px 20px'
    }}>
      <div style={{ 
        maxWidth: '900px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '16px',
        boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
        overflow: 'hidden'
      }}>
        {/* 任务信息头部 */}
        {loadingTask ? (
          <div style={{ padding: '60px', textAlign: 'center' }}>
            <Spin size="large" />
            <div style={{ marginTop: '16px', color: '#666' }}>加载任务信息中...</div>
          </div>
        ) : taskInfo ? (
          <div style={{ 
            background: 'linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)',
            padding: '32px',
            borderBottom: '1px solid #e8e8e8'
          }}>
            <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
              {/* 任务图片 */}
              {taskInfo.images && taskInfo.images.length > 0 && (
                <div style={{ 
                  flex: '0 0 auto',
                  width: '200px',
                  height: '150px',
                  borderRadius: '12px',
                  overflow: 'hidden',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
                }}>
                  <LazyImage
                    src={ensureAbsoluteImageUrl(taskInfo.images[0])}
                    alt={taskInfo.title}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover'
                    }}
                  />
                </div>
              )}
              
              {/* 任务信息 */}
              <div style={{ flex: '1', minWidth: '300px' }}>
                <div style={{ 
                  fontSize: '24px', 
                  fontWeight: 'bold', 
                  color: '#1a1a1a',
                  marginBottom: '12px',
                  lineHeight: 1.3
                }}>
                  {taskInfo.title}
                </div>
                <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginBottom: '12px' }}>
                  <div style={{ 
                    padding: '6px 12px',
                    background: '#e8f4f8',
                    borderRadius: '6px',
                    fontSize: '14px',
                    color: '#1890ff',
                    fontWeight: 500
                  }}>
                    {taskInfo.task_type}
                  </div>
                  {taskInfo.location && (
                    <div style={{ 
                      padding: '6px 12px',
                      background: '#f0f0f0',
                      borderRadius: '6px',
                      fontSize: '14px',
                      color: '#666'
                    }}>
                      📍 {obfuscateLocation(taskInfo.location)}
                    </div>
                  )}
                </div>
                <div style={{ 
                  fontSize: '20px', 
                  fontWeight: 'bold', 
                  color: '#52c41a',
                  marginTop: '8px'
                }}>
                  £{taskRewardDisplay} {taskInfo.currency}
                </div>
              </div>
            </div>
          </div>
        ) : null}

        {/* 支付内容区域 */}
        <div style={{ padding: '40px' }}>
          {!paymentData ? (
            <div>
              <h2 style={{ 
                fontSize: '24px', 
                fontWeight: 'bold', 
                marginBottom: '32px',
                color: '#1a1a1a'
              }}>
                {language === 'zh' ? '选择支付方式' : 'Select Payment Method'}
              </h2>

              {/* 优惠券输入 */}
              <div style={{ marginBottom: '32px' }}>
                <label style={{ display: 'block', marginBottom: '12px', fontWeight: '600', fontSize: '16px' }}>
                  {language === 'zh' ? '优惠券代码（可选）' : 'Coupon Code (Optional)'}
                </label>
                <Input
                  value={couponCode}
                  onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                  placeholder={language === 'zh' ? '输入优惠券代码' : 'Enter coupon code'}
                  size="large"
                />
              </div>

              <Button
                type="primary"
                onClick={handleCreatePayment}
                loading={loading}
                block
                size="large"
                style={{
                  height: '50px',
                  fontSize: '18px',
                  fontWeight: 'bold'
                }}
              >
                {loading ? (language === 'zh' ? '创建支付中...' : 'Creating payment...') : (language === 'zh' ? '创建支付' : 'Create Payment')}
              </Button>
            </div>
          ) : (
            <div>
              <h2 style={{ 
                fontSize: '24px', 
                fontWeight: 'bold', 
                marginBottom: '24px',
                color: '#1a1a1a'
              }}>
                {language === 'zh' ? '支付详情' : 'Payment Details'}
              </h2>

              {/* 显示支付信息 */}
              <div style={{ 
                marginBottom: '32px',
                padding: '24px',
                background: '#f8f9fa',
                borderRadius: '12px',
                border: '1px solid #e8e8e8'
              }}>
                <div style={{ marginBottom: '16px', fontSize: '16px' }}>
                  <strong>{language === 'zh' ? '总金额:' : 'Total Amount:'}</strong> 
                  <span style={{ marginLeft: '8px', fontSize: '18px', fontWeight: 'bold' }}>
                    £{paymentData.total_amount_display}
                  </span>
                </div>
                {paymentData.coupon_discount_display && (
                  <div style={{ marginBottom: '12px', color: '#52c41a', fontSize: '16px' }}>
                    <strong>{language === 'zh' ? '优惠券折扣:' : 'Coupon Discount:'}</strong> 
                    <span style={{ marginLeft: '8px' }}>£{paymentData.coupon_discount_display}</span>
                  </div>
                )}
                <div style={{ 
                  marginTop: '16px',
                  padding: '16px',
                  background: '#fff',
                  borderRadius: '8px',
                  border: '2px solid #1890ff'
                }}>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '4px' }}>
                    {language === 'zh' ? '最终支付金额' : 'Final Payment Amount'}
                  </div>
                  <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#1890ff' }}>
                    £{paymentData.final_amount_display}
                  </div>
                </div>
                {paymentData.note && (
                  <div style={{ 
                    marginTop: '16px', 
                    padding: '12px', 
                    background: '#fff3cd', 
                    borderRadius: '8px',
                    border: '1px solid #ffc107',
                    fontSize: '14px',
                    color: '#856404'
                  }}>
                    {paymentData.note}
                  </div>
                )}
              </div>

              {/* 如果纯积分支付，已成功 */}
              {paymentData.final_amount === 0 ? (
                <div style={{ textAlign: 'center', padding: '40px' }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px' }}>✅</div>
                  <div style={{ fontSize: '24px', color: '#52c41a', marginBottom: '24px', fontWeight: 'bold' }}>
                    {language === 'zh' ? '支付成功！' : 'Payment Successful!'}
                  </div>
                  <Button 
                    type="primary" 
                    size="large"
                    onClick={() => localizedNavigate(`/tasks/${taskId}`)}
                    style={{
                      height: '50px',
                      fontSize: '18px',
                      fontWeight: 'bold',
                      padding: '0 40px'
                    }}
                  >
                    {language === 'zh' ? '返回任务详情' : 'Back to Task Details'}
                  </Button>
                </div>
              ) : paymentData.client_secret ? (
                // 显示 Stripe Elements 支付表单
                <div>
                  <h3 style={{ 
                    fontSize: '20px', 
                    fontWeight: 'bold', 
                    marginBottom: '20px',
                    color: '#1a1a1a'
                  }}>
                    {language === 'zh' ? '完成支付' : 'Complete Payment'}
                  </h3>
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
                </div>
              ) : (
                <div style={{ textAlign: 'center', padding: '40px' }}>
                  <Spin size="large" />
                  <div style={{ marginTop: '16px', color: '#666' }}>
                    {language === 'zh' ? '正在准备支付...' : 'Preparing payment...'}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default TaskPayment;
