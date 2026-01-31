import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getAvailableCoupons, getMyCoupons, redeemCouponWithPoints, claimCoupon, getPointsAccount } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

interface Coupon {
  id: number;
  name: string;
  description: string;
  code: string;
  discount_type: 'fixed' | 'percentage';
  discount_value: number;
  min_amount?: number;
  max_discount?: number;
  valid_from: string;
  valid_until: string;
  usage_conditions?: {
    points_required?: number;
    locations?: string[];
    task_types?: string[];
  };
  status: string;
}

interface UserCoupon {
  id: number;
  coupon: Coupon;
  status: string;
  obtained_at: string;
  valid_until: string;
}

const Coupons: React.FC = () => {
  const navigate = useNavigate();
  const { language } = useLanguage();
  const [activeTab, setActiveTab] = useState<'available' | 'my'>('available');
  const [availableCoupons, setAvailableCoupons] = useState<Coupon[]>([]);
  const [myCoupons, setMyCoupons] = useState<UserCoupon[]>([]);
  const [pointsBalance, setPointsBalance] = useState(0);
  const [loading, setLoading] = useState(true);
  const [redeemingCouponId, setRedeemingCouponId] = useState<number | null>(null);
  const [showConfirmDialog, setShowConfirmDialog] = useState(false);
  const [selectedCoupon, setSelectedCoupon] = useState<Coupon | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  useEffect(() => {
    loadData();
  }, [activeTab]);

  const loadData = async () => {
    try {
      setLoading(true);
      const [couponsData, myCouponsData, pointsData] = await Promise.all([
        getAvailableCoupons(),
        getMyCoupons(),
        getPointsAccount()
      ]);
      setAvailableCoupons(couponsData.data || []);
      setMyCoupons(myCouponsData.data || []);
      setPointsBalance(pointsData.balance || 0);
    } catch (error: any) {
      console.error('Error loading coupons:', error);
      setErrorMessage(error.response?.data?.detail || (language === 'zh' ? '加载失败' : 'Failed to load'));
    } finally {
      setLoading(false);
    }
  };

  const handleRedeemWithPoints = (coupon: Coupon) => {
    const pointsRequired = coupon.usage_conditions?.points_required || 0;
    if (pointsRequired <= 0) {
      setErrorMessage(language === 'zh' ? '该优惠券不支持积分兑换' : 'This coupon cannot be redeemed with points');
      return;
    }
    if (pointsBalance < pointsRequired) {
      setErrorMessage(
        language === 'zh' 
          ? `积分不足，需要 ${pointsRequired} 积分，当前余额 ${pointsBalance} 积分`
          : `Insufficient points. Required: ${pointsRequired}, Current: ${pointsBalance}`
      );
      return;
    }
    setSelectedCoupon(coupon);
    setShowConfirmDialog(true);
  };

  const confirmRedeem = async () => {
    if (!selectedCoupon) return;
    
    try {
      setRedeemingCouponId(selectedCoupon.id);
      setErrorMessage(null);
      const result = await redeemCouponWithPoints({
        coupon_id: selectedCoupon.id
      });
      setSuccessMessage(result.message || (language === 'zh' ? '兑换成功！' : 'Redeemed successfully!'));
      setShowConfirmDialog(false);
      setSelectedCoupon(null);
      // 刷新数据
      await loadData();
    } catch (error: any) {
      setErrorMessage(error.response?.data?.detail || (language === 'zh' ? '兑换失败' : 'Redemption failed'));
    } finally {
      setRedeemingCouponId(null);
    }
  };

  const handleClaimCoupon = async (couponId: number) => {
    try {
      await claimCoupon({ coupon_id: couponId });
      setSuccessMessage(language === 'zh' ? '领取成功！' : 'Claimed successfully!');
      await loadData();
    } catch (error: any) {
      setErrorMessage(error.response?.data?.detail || (language === 'zh' ? '领取失败' : 'Claim failed'));
    }
  };

  const formatDiscount = (coupon: Coupon) => {
    if (coupon.discount_type === 'fixed') {
      return `£${(coupon.discount_value / 100).toFixed(2)}`;
    } else {
      return `${coupon.discount_value}%`;
    }
  };

  const canRedeemWithPoints = (coupon: Coupon) => {
    return (coupon.usage_conditions?.points_required || 0) > 0;
  };

  const getCouponStatusBadge = (status: string) => {
    const statusMap: Record<string, { text: string; color: string; bgColor: string }> = {
      unused: {
        text: language === 'zh' ? '未使用' : 'Unused',
        color: '#10b981',
        bgColor: '#d1fae5'
      },
      used: {
        text: language === 'zh' ? '已使用' : 'Used',
        color: '#64748b',
        bgColor: '#e2e8f0'
      },
      expired: {
        text: language === 'zh' ? '已过期' : 'Expired',
        color: '#ef4444',
        bgColor: '#fee2e2'
      }
    };
    const statusInfo = statusMap[status] ?? statusMap.unused ?? { text: String(status), color: '#666', bgColor: '#e2e8f0' };
    return (
      <span style={{
        padding: '4px 12px',
        borderRadius: '12px',
        fontSize: '12px',
        fontWeight: '600',
        color: statusInfo.color,
        backgroundColor: statusInfo.bgColor
      }}>
        {statusInfo.text}
      </span>
    );
  };

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '18px',
        color: '#666'
      }}>
        {language === 'zh' ? '加载中...' : 'Loading...'}
      </div>
    );
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%)',
      padding: isMobile ? '16px' : '32px 24px',
      paddingTop: isMobile ? '20px' : '40px'
    }}>
      <div style={{
        maxWidth: '1000px',
        margin: '0 auto',
        background: '#fff',
        borderRadius: '24px',
        boxShadow: '0 20px 60px rgba(0,0,0,0.12), 0 8px 24px rgba(0,0,0,0.08)',
        overflow: 'hidden'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          color: '#fff',
          padding: isMobile ? '28px 20px' : '40px 40px 36px',
          textAlign: 'center',
          position: 'relative',
          overflow: 'hidden'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: isMobile ? '16px' : '24px',
              top: isMobile ? '20px' : '24px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: '0',
              borderRadius: '14px',
              cursor: 'pointer',
              fontSize: '22px',
              width: '44px',
              height: '44px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              transition: 'all 0.3s ease',
              backdropFilter: 'blur(12px)',
              zIndex: 10
            }}
          >
            ←
          </button>
          <h1 style={{
            fontSize: isMobile ? '28px' : '36px',
            fontWeight: '800',
            margin: '0 0 32px 0',
            letterSpacing: '-0.5px'
          }}>
            🎫 {language === 'zh' ? '优惠券' : 'Coupons'}
          </h1>

          {/* 标签页切换 */}
          <div style={{
            display: 'flex',
            gap: '12px',
            justifyContent: 'center',
            position: 'relative',
            zIndex: 5
          }}>
            <button
              onClick={() => setActiveTab('available')}
              style={{
                background: activeTab === 'available' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.12)',
                border: activeTab === 'available' ? '2px solid rgba(255,255,255,0.5)' : '2px solid transparent',
                color: '#fff',
                padding: '12px 28px',
                borderRadius: '16px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'available' ? '700' : '500',
                transition: 'all 0.3s ease',
                backdropFilter: 'blur(12px)'
              }}
            >
              {language === 'zh' ? '可用优惠券' : 'Available'}
            </button>
            <button
              onClick={() => setActiveTab('my')}
              style={{
                background: activeTab === 'my' ? 'rgba(255,255,255,0.3)' : 'rgba(255,255,255,0.12)',
                border: activeTab === 'my' ? '2px solid rgba(255,255,255,0.5)' : '2px solid transparent',
                color: '#fff',
                padding: '12px 28px',
                borderRadius: '16px',
                cursor: 'pointer',
                fontSize: '15px',
                fontWeight: activeTab === 'my' ? '700' : '500',
                transition: 'all 0.3s ease',
                backdropFilter: 'blur(12px)'
              }}
            >
              {language === 'zh' ? '我的优惠券' : 'My Coupons'}
            </button>
          </div>
        </div>

        {/* 内容区域 */}
        <div style={{ padding: isMobile ? '24px 20px' : '36px 40px' }}>
          {/* 错误和成功消息 */}
          {errorMessage && (
            <div style={{
              padding: '12px 16px',
              background: '#fee2e2',
              color: '#dc2626',
              borderRadius: '12px',
              marginBottom: '20px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <span>{errorMessage}</span>
              <button
                onClick={() => setErrorMessage(null)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#dc2626',
                  cursor: 'pointer',
                  fontSize: '18px',
                  padding: '0',
                  marginLeft: '12px'
                }}
              >
                ×
              </button>
            </div>
          )}

          {successMessage && (
            <div style={{
              padding: '12px 16px',
              background: '#d1fae5',
              color: '#059669',
              borderRadius: '12px',
              marginBottom: '20px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center'
            }}>
              <span>{successMessage}</span>
              <button
                onClick={() => setSuccessMessage(null)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#059669',
                  cursor: 'pointer',
                  fontSize: '18px',
                  padding: '0',
                  marginLeft: '12px'
                }}
              >
                ×
              </button>
            </div>
          )}

          {/* 可用优惠券列表 */}
          {activeTab === 'available' && (
            <div>
              {availableCoupons.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '60px 20px',
                  color: '#94a3b8'
                }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px', opacity: 0.5 }}>🎫</div>
                  <div style={{ fontWeight: '500', color: '#64748b' }}>
                    {language === 'zh' ? '暂无可用优惠券' : 'No available coupons'}
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  {availableCoupons.map((coupon) => (
                    <div
                      key={coupon.id}
                      style={{
                        background: '#fff',
                        border: '2px solid #e2e8f0',
                        borderRadius: '16px',
                        padding: '20px',
                        display: 'flex',
                        flexDirection: isMobile ? 'column' : 'row',
                        gap: '16px',
                        transition: 'all 0.3s ease'
                      }}
                    >
                      <div style={{ flex: 1 }}>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '12px',
                          marginBottom: '12px'
                        }}>
                          <h3 style={{
                            margin: 0,
                            fontSize: '20px',
                            fontWeight: '700',
                            color: '#1a202c'
                          }}>
                            {coupon.name}
                          </h3>
                          <span style={{
                            padding: '4px 12px',
                            background: 'linear-gradient(135deg, #667eea, #764ba2)',
                            color: '#fff',
                            borderRadius: '12px',
                            fontSize: '14px',
                            fontWeight: '700'
                          }}>
                            {formatDiscount(coupon)}
                          </span>
                        </div>
                        <p style={{
                          margin: '0 0 12px 0',
                          color: '#64748b',
                          fontSize: '14px',
                          lineHeight: '1.6'
                        }}>
                          {coupon.description}
                        </p>
                        <div style={{
                          fontSize: '12px',
                          color: '#94a3b8',
                          marginBottom: '12px'
                        }}>
                          {language === 'zh' ? '有效期：' : 'Valid: '}
                          {new Date(coupon.valid_from).toLocaleDateString()} - {new Date(coupon.valid_until).toLocaleDateString()}
                        </div>
                        {coupon.min_amount && (
                          <div style={{
                            fontSize: '12px',
                            color: '#94a3b8'
                          }}>
                            {language === 'zh' ? `最低消费：£${(coupon.min_amount / 100).toFixed(2)}` : `Min. spend: £${(coupon.min_amount / 100).toFixed(2)}`}
                          </div>
                        )}
                      </div>
                      <div style={{
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '8px',
                        alignItems: isMobile ? 'stretch' : 'flex-end',
                        justifyContent: 'center'
                      }}>
                        {canRedeemWithPoints(coupon) && (
                          <button
                            onClick={() => handleRedeemWithPoints(coupon)}
                            disabled={redeemingCouponId === coupon.id || pointsBalance < (coupon.usage_conditions?.points_required || 0)}
                            style={{
                              padding: '10px 20px',
                              background: redeemingCouponId === coupon.id || pointsBalance < (coupon.usage_conditions?.points_required || 0)
                                ? '#e2e8f0'
                                : 'linear-gradient(135deg, #f59e0b, #d97706)',
                              color: redeemingCouponId === coupon.id || pointsBalance < (coupon.usage_conditions?.points_required || 0)
                                ? '#94a3b8'
                                : '#fff',
                              border: 'none',
                              borderRadius: '12px',
                              cursor: redeemingCouponId === coupon.id || pointsBalance < (coupon.usage_conditions?.points_required || 0)
                                ? 'not-allowed'
                                : 'pointer',
                              fontSize: '14px',
                              fontWeight: '600',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px',
                              transition: 'all 0.3s ease'
                            }}
                          >
                            {redeemingCouponId === coupon.id ? (
                              <>
                                <span>⏳</span>
                                {language === 'zh' ? '兑换中...' : 'Redeeming...'}
                              </>
                            ) : (
                              <>
                                <span>⭐</span>
                                {language === 'zh' ? `积分兑换 (${coupon.usage_conditions?.points_required || 0})` : `Redeem (${coupon.usage_conditions?.points_required || 0} pts)`}
                              </>
                            )}
                          </button>
                        )}
                        <button
                          onClick={() => handleClaimCoupon(coupon.id)}
                          style={{
                            padding: '10px 20px',
                            background: 'linear-gradient(135deg, #667eea, #764ba2)',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '12px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: '600',
                            transition: 'all 0.3s ease'
                          }}
                        >
                          {language === 'zh' ? '免费领取' : 'Claim Free'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* 我的优惠券列表 */}
          {activeTab === 'my' && (
            <div>
              {myCoupons.length === 0 ? (
                <div style={{
                  textAlign: 'center',
                  padding: '60px 20px',
                  color: '#94a3b8'
                }}>
                  <div style={{ fontSize: '48px', marginBottom: '16px', opacity: 0.5 }}>🎫</div>
                  <div style={{ fontWeight: '500', color: '#64748b' }}>
                    {language === 'zh' ? '您还没有优惠券' : 'You have no coupons'}
                  </div>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                  {myCoupons.map((userCoupon) => (
                    <div
                      key={userCoupon.id}
                      style={{
                        background: '#fff',
                        border: '2px solid #e2e8f0',
                        borderRadius: '16px',
                        padding: '20px',
                        display: 'flex',
                        flexDirection: isMobile ? 'column' : 'row',
                        gap: '16px',
                        justifyContent: 'space-between',
                        alignItems: 'center'
                      }}
                    >
                      <div style={{ flex: 1 }}>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '12px',
                          marginBottom: '12px'
                        }}>
                          <h3 style={{
                            margin: 0,
                            fontSize: '20px',
                            fontWeight: '700',
                            color: '#1a202c'
                          }}>
                            {userCoupon.coupon.name}
                          </h3>
                          {getCouponStatusBadge(userCoupon.status)}
                        </div>
                        <p style={{
                          margin: '0 0 8px 0',
                          color: '#64748b',
                          fontSize: '14px'
                        }}>
                          {userCoupon.coupon.description}
                        </p>
                        <div style={{
                          fontSize: '12px',
                          color: '#94a3b8',
                          fontFamily: 'monospace',
                          background: '#f8fafc',
                          padding: '6px 12px',
                          borderRadius: '8px',
                          display: 'inline-block'
                        }}>
                          {userCoupon.coupon.code}
                        </div>
                      </div>
                      <div style={{
                        textAlign: 'right',
                        fontSize: '24px',
                        fontWeight: '800',
                        color: '#667eea'
                      }}>
                        {formatDiscount(userCoupon.coupon)}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* 确认兑换对话框 */}
      {showConfirmDialog && selectedCoupon && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '20px'
        }}
        onClick={() => setShowConfirmDialog(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '20px',
              padding: '32px',
              maxWidth: '400px',
              width: '100%',
              boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{
              margin: '0 0 16px 0',
              fontSize: '20px',
              fontWeight: '700',
              color: '#1a202c'
            }}>
              {language === 'zh' ? '确认兑换' : 'Confirm Redemption'}
            </h3>
            <p style={{
              margin: '0 0 24px 0',
              color: '#64748b',
              fontSize: '14px',
              lineHeight: '1.6'
            }}>
              {language === 'zh' 
                ? `确定要用 ${selectedCoupon.usage_conditions?.points_required || 0} 积分兑换 "${selectedCoupon.name}" 吗？`
                : `Are you sure you want to redeem "${selectedCoupon.name}" for ${selectedCoupon.usage_conditions?.points_required || 0} points?`}
            </p>
            <div style={{
              display: 'flex',
              gap: '12px',
              justifyContent: 'flex-end'
            }}>
              <button
                onClick={() => {
                  setShowConfirmDialog(false);
                  setSelectedCoupon(null);
                }}
                style={{
                  padding: '10px 20px',
                  background: '#f1f5f9',
                  color: '#64748b',
                  border: 'none',
                  borderRadius: '12px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: '600'
                }}
              >
                {language === 'zh' ? '取消' : 'Cancel'}
              </button>
              <button
                onClick={confirmRedeem}
                disabled={redeemingCouponId !== null}
                style={{
                  padding: '10px 20px',
                  background: redeemingCouponId !== null ? '#e2e8f0' : 'linear-gradient(135deg, #f59e0b, #d97706)',
                  color: redeemingCouponId !== null ? '#94a3b8' : '#fff',
                  border: 'none',
                  borderRadius: '12px',
                  cursor: redeemingCouponId !== null ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: '600'
                }}
              >
                {redeemingCouponId !== null
                  ? (language === 'zh' ? '兑换中...' : 'Redeeming...')
                  : (language === 'zh' ? '确认兑换' : 'Confirm')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Coupons;
