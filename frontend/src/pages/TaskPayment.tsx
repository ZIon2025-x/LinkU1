import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { Button, Spin, message, Select } from 'antd';
import api, { getMyCoupons } from '../api';
import StripePaymentForm from '../components/payment/StripePaymentForm';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { usePaymentCountdown } from '../hooks/usePaymentCountdown';
import LoginModal from '../components/LoginModal';
import LazyImage from '../components/LazyImage';
import { obfuscateLocation } from '../utils/formatUtils';
import { logger } from '../utils/logger';
import { ensureAbsoluteImageUrl } from '../utils/imageUtils';
import SEOHead from '../components/SEOHead';

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
  status?: string;
  payment_expires_at?: string | null;
}

interface UserCouponItem {
  id: number;
  coupon: { id: number; name: string; code: string; type?: string; discount_value: number; min_amount?: number };
  status: string;
}

const TaskPayment: React.FC = () => {
  const { taskId } = useParams<{ taskId: string }>();
  useNavigate();
  const [searchParams] = useSearchParams();
  const { language } = useLanguage();
  const { navigate: localizedNavigate } = useLocalizedNavigation();
  
  const [loading, setLoading] = useState(false);
  const [paymentData, setPaymentData] = useState<PaymentData | null>(null);
  const [myCoupons, setMyCoupons] = useState<UserCouponItem[]>([]);
  const [selectedUserCouponId, setSelectedUserCouponId] = useState<number | null>(null);
  const [loadingCoupons, setLoadingCoupons] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [, setPointsBalance] = useState<number>(0); void setPointsBalance;
  const [taskInfo, setTaskInfo] = useState<TaskInfo | null>(null);
  const [loadingTask, setLoadingTask] = useState(true);
  const [returnUrl, setReturnUrl] = useState<string | null>(null);
  const [, setReturnType] = useState<string | null>(null); void setReturnType;
  const [isStripeRedirectReturn, setIsStripeRedirectReturn] = useState(false);
  const [stripeRedirectHandled, setStripeRedirectHandled] = useState(false);

  const showCountdown = taskInfo?.status === 'pending_payment' && taskInfo?.payment_expires_at;
  const { formatted, isExpired } = usePaymentCountdown(showCountdown ? taskInfo!.payment_expires_at! : null);

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
          status: task.status,
          payment_expires_at: task.payment_expires_at ?? null,
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

  // 加载用户可用优惠券（未使用的）
  useEffect(() => {
    const loadCoupons = async () => {
      if (!user) return;
      try {
        setLoadingCoupons(true);
        const res = await getMyCoupons({ status: 'unused', limit: 50 });
        setMyCoupons(res.data || []);
      } catch (e) {
        // 优惠券加载失败不影响支付
      } finally {
        setLoadingCoupons(false);
      }
    };
    loadCoupons();
  }, [user]);

  // 自动创建支付（页面加载后自动发起，无需用户点击）
  const [autoPaymentInitiated, setAutoPaymentInitiated] = useState(false);
  useEffect(() => {
    // 只在以下条件满足时自动创建支付：
    // 1. 用户已登录
    // 2. 任务信息已加载
    // 3. 没有来自 URL 参数的支付信息
    // 4. 不是 Stripe 重定向返回
    // 5. 还没有自动发起过
    const hasUrlPaymentInfo = searchParams.get('client_secret') || searchParams.get('payment_intent_id');
    if (user && !loadingTask && taskInfo && !hasUrlPaymentInfo && !isStripeRedirectReturn && !autoPaymentInitiated && !paymentData) {
      setAutoPaymentInitiated(true);
      handleCreatePaymentAuto();
    }
  }, [user, loadingTask, taskInfo, isStripeRedirectReturn, autoPaymentInitiated, paymentData]);

  // 自动创建支付（不带优惠券）
  const handleCreatePaymentAuto = async () => {
    if (!taskId || !user) return;
    
    setLoading(true);
    try {
      const response = await api.post(
        `/api/coupon-points/tasks/${taskId}/payment`,
        { payment_method: 'stripe' }
      );
      setPaymentData(response.data);
      
      // 如果使用优惠券全额抵扣，直接成功
      if (response.data.final_amount === 0) {
        message.success(language === 'zh' ? '支付成功！' : 'Payment successful!');
        if (returnUrl && window.opener) {
          window.opener.postMessage({ type: 'payment_success', taskId: taskId }, '*');
          setTimeout(() => window.close(), 1500);
        } else {
          setTimeout(() => localizedNavigate(`/tasks/${taskId}`), 1500);
        }
      }
    } catch (error: any) {
      const errorMessage = error.response?.data?.detail || error.message || '创建支付失败';
      message.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 应用优惠券并重新创建支付
  const handleApplyCoupon = async (userCouponId: number | null) => {
    setSelectedUserCouponId(userCouponId);
    
    if (!taskId || !user) return;
    
    setLoading(true);
    try {
      const requestData: any = { payment_method: 'stripe' };
      if (userCouponId) {
        requestData.user_coupon_id = userCouponId;
      }
      
      const response = await api.post(
        `/api/coupon-points/tasks/${taskId}/payment`,
        requestData
      );
      setPaymentData(response.data);
      
      if (userCouponId) {
        message.success(language === 'zh' ? '优惠券已应用' : 'Coupon applied');
      }
      
      // 如果使用优惠券全额抵扣，直接成功
      if (response.data.final_amount === 0) {
        message.success(language === 'zh' ? '优惠券全额抵扣，支付成功！' : 'Fully paid with coupon!');
        if (returnUrl && window.opener) {
          window.opener.postMessage({ type: 'payment_success', taskId: taskId }, '*');
          setTimeout(() => window.close(), 1500);
        } else {
          setTimeout(() => localizedNavigate(`/tasks/${taskId}`), 1500);
        }
      }
    } catch (error: any) {
      const errorMessage = error.response?.data?.detail || error.message || '应用优惠券失败';
      message.error(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  // 检查 URL 参数中是否有支付信息和返回 URL
  useEffect(() => {
    const clientSecret = searchParams.get('client_secret');
    const paymentIntentId = searchParams.get('payment_intent_id');
    const amount = searchParams.get('amount');
    const amountDisplay = searchParams.get('amount_display');
    const returnUrlParam = searchParams.get('return_url');
    const returnTypeParam = searchParams.get('return_type');

    // Stripe 重定向返回时的参数（3D Secure、支付宝等会触发重定向）
    const stripeRedirectStatus = searchParams.get('redirect_status');
    const stripePaymentIntent = searchParams.get('payment_intent');
    const stripePaymentIntentSecret = searchParams.get('payment_intent_client_secret');

    // 保存返回 URL 和类型
    if (returnUrlParam) {
      setReturnUrl(returnUrlParam);
    }
    if (returnTypeParam) {
      setReturnType(returnTypeParam);
    }

    // 优先处理 Stripe 重定向返回：用户完成 3DS/支付宝后重定向回本页
    if (stripeRedirectStatus && (stripePaymentIntent || stripePaymentIntentSecret) && taskId) {
      logger.log('📥 检测到 Stripe 重定向返回:', { redirect_status: stripeRedirectStatus, payment_intent: stripePaymentIntent });
      // 清除 URL 中的 Stripe 参数，避免刷新时重复处理
      const newUrl = new URL(window.location.href);
      ['redirect_status', 'payment_intent', 'payment_intent_client_secret'].forEach((p) => newUrl.searchParams.delete(p));
      window.history.replaceState({}, '', newUrl.pathname + (newUrl.search || ''));
      if (stripeRedirectStatus === 'failed') {
        message.error(language === 'zh' ? '支付失败，请重试' : 'Payment failed, please try again');
        return;
      }
      setIsStripeRedirectReturn(true);
      setReturnUrl(returnUrlParam || null);
      setPaymentData({
        payment_id: null,
        fee_type: 'task_amount',
        total_amount: 0,
        total_amount_display: '0.00',
        points_used: null,
        points_used_display: null,
        coupon_discount: null,
        coupon_discount_display: null,
        stripe_amount: null,
        stripe_amount_display: null,
        currency: 'GBP',
        final_amount: 0,
        final_amount_display: '0.00',
        checkout_url: null,
        client_secret: null,
        payment_intent_id: stripePaymentIntent || null,
        note: '',
      });
      return;
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

  // Stripe 重定向返回后：立即显示「支付完成，正在确认」并启动轮询，不展示优惠券表单
  useEffect(() => {
    const paymentIntentId = paymentData?.payment_intent_id;
    if (!isStripeRedirectReturn || stripeRedirectHandled || !taskId || !paymentIntentId) return;
    setStripeRedirectHandled(true);
    message.success(language === 'zh' ? '支付已完成，正在确认...' : 'Payment completed, confirming...');
    // 直接传入 paymentIntentId 避免闭包问题
    startPaymentStatusPolling(paymentIntentId);
  }, [isStripeRedirectReturn, stripeRedirectHandled, taskId, paymentData?.payment_intent_id, language]);

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
      startPaymentStatusPolling(paymentData?.payment_intent_id);
    }
  };

  // 支付状态轮询（作为 webhook 的备选方案）
  const startPaymentStatusPolling = async (paymentIntentIdParam?: string | null) => {
    const paymentIntentId = paymentIntentIdParam || paymentData?.payment_intent_id;
    if (!taskId || !paymentIntentId) {
      logger.log('⚠️ 无法启动轮询: taskId 或 paymentIntentId 缺失', { taskId, paymentIntentId });
      return;
    }

    logger.log('🚀 启动支付状态轮询', { taskId, paymentIntentId });

    let pollCount = 0;
    const maxPolls = 15; // 最多轮询 15 次
    const pollInterval = 2000; // 每 2 秒轮询一次

    const poll = async () => {
      if (pollCount >= maxPolls) {
        // 轮询超时，但支付可能已成功（webhook 延迟）
        logger.log('⏰ 轮询超时，尝试通知原页面');
        // 设置 localStorage 标记，确保消息页面能收到通知
        localStorage.setItem(`payment_success_${taskId}`, 'true');
        
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
          message.info(language === 'zh' ? '正在跳转到任务详情...' : 'Redirecting to task details...');
          setTimeout(() => {
            localizedNavigate(`/tasks/${taskId}`);
          }, 1500);
        }
        return;
      }

      try {
        logger.log(`🔄 轮询支付状态 (${pollCount + 1}/${maxPolls}), taskId: ${taskId}, paymentIntentId: ${paymentIntentId}`);
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
      <SEOHead noindex={true} />
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
          {showCountdown && (
            <div style={{
              marginBottom: '24px',
              padding: '16px 20px',
              borderRadius: '12px',
              background: isExpired ? 'linear-gradient(135deg, #fee2e2 0%, #fecaca 100%)' : 'linear-gradient(135deg, #fef3c7 0%, #fde68a 100%)',
              border: `1px solid ${isExpired ? '#f87171' : '#fbbf24'}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              flexWrap: 'wrap',
              gap: '12px',
            }}>
              <span style={{ fontSize: '16px', fontWeight: '600', color: isExpired ? '#b91c1c' : '#92400e' }}>
                {isExpired
                  ? (language === 'zh' ? '支付已过期，任务将自动取消' : 'Payment expired, task will be cancelled')
                  : (language === 'zh' ? '请在30分钟内完成支付' : 'Complete payment within 30 minutes')}
              </span>
              {!isExpired && (
                <span style={{ fontFamily: 'monospace', fontSize: '20px', fontWeight: 'bold', color: '#92400e' }}>
                  {language === 'zh' ? '剩余 ' : 'Left '}{formatted}
                </span>
              )}
            </div>
          )}
          {isStripeRedirectReturn && !paymentData?.client_secret ? (
            <div style={{ textAlign: 'center', padding: '60px 40px' }}>
              <div style={{ fontSize: '64px', marginBottom: '24px' }}>⏳</div>
              <div style={{ fontSize: '20px', fontWeight: 'bold', color: '#1890ff', marginBottom: '16px' }}>
                {language === 'zh' ? '支付已完成，正在确认...' : 'Payment completed, confirming...'}
              </div>
              <div style={{ color: '#666', marginBottom: '24px' }}>
                {language === 'zh' ? '请稍候，正在验证支付结果' : 'Please wait while we verify your payment'}
              </div>
              <Spin size="large" />
            </div>
          ) : loading || !paymentData || (paymentData && !paymentData.client_secret && paymentData.final_amount !== 0) ? (
            // 正在创建支付，显示加载状态
            <div style={{ textAlign: 'center', padding: '60px 40px' }}>
              <Spin size="large" />
              <div style={{ marginTop: '24px', fontSize: '18px', color: '#666' }}>
                {language === 'zh' ? '正在准备支付...' : 'Preparing payment...'}
              </div>
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

              {/* 优惠券选择（自动应用） */}
              <div style={{ 
                marginBottom: '24px',
                padding: '16px 20px',
                background: paymentData.coupon_discount_display ? '#f0fdf4' : '#f8fff8',
                borderRadius: '12px',
                border: `1px solid ${paymentData.coupon_discount_display ? '#22c55e' : '#b7eb8f'}`
              }}>
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '12px'
                }}>
                  <div style={{ 
                    display: 'flex', 
                    alignItems: 'center',
                    gap: '8px',
                    fontWeight: '600', 
                    fontSize: '15px',
                    color: '#389e0d'
                  }}>
                    🎁 {language === 'zh' ? '优惠券' : 'Coupon'}
                    {paymentData.coupon_discount_display && (
                      <span style={{ 
                        background: '#22c55e', 
                        color: '#fff', 
                        padding: '2px 8px', 
                        borderRadius: '4px', 
                        fontSize: '12px' 
                      }}>
                        {language === 'zh' ? '已应用' : 'Applied'}
                      </span>
                    )}
                  </div>
                  {loadingCoupons ? (
                    <span style={{ color: '#666', fontSize: '14px' }}>
                      <Spin size="small" style={{ marginRight: '8px' }} />
                      {language === 'zh' ? '加载中...' : 'Loading...'}
                    </span>
                  ) : myCoupons.length > 0 ? (
                    <Select
                      placeholder={language === 'zh' ? '选择优惠券' : 'Select coupon'}
                      allowClear
                      style={{ minWidth: '200px' }}
                      size="middle"
                      disabled={loading}
                      value={selectedUserCouponId ?? undefined}
                      onChange={(v: number | undefined) => handleApplyCoupon(v ?? null)}
                      options={myCoupons.map((uc: UserCouponItem) => {
                        const c = uc.coupon;
                        const discount = (c.type === 'fixed_amount' || c.type === 'fixed') 
                          ? `£${(c.discount_value / 100).toFixed(2)}`
                          : `${(c.discount_value / 100).toFixed(0)}% off`;
                        const min = c.min_amount ? ` (min £${(c.min_amount / 100).toFixed(2)})` : '';
                        return { value: uc.id, label: `${c.name} - ${discount}${min}` };
                      })}
                    />
                  ) : (
                    <span style={{ color: '#999', fontSize: '14px' }}>
                      {language === 'zh' ? '暂无可用优惠券' : 'No coupons available'}
                    </span>
                  )}
                </div>
              </div>

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
                    <span style={{ marginLeft: '8px' }}>-£{paymentData.coupon_discount_display}</span>
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
