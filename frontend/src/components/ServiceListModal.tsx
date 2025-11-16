/**
 * 服务列表弹窗组件
 * 显示任务达人的所有可用服务，用户可以选择服务并查看详情
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { getTaskExpertServices, applyForService, fetchCurrentUser } from '../api';
import ServiceDetailModal from './ServiceDetailModal';
import LoginModal from './LoginModal';
import { MODAL_OVERLAY_STYLE } from './TaskDetailModal.styles';

interface ServiceListModalProps {
  isOpen: boolean;
  onClose: () => void;
  expertId: string;
  expertName?: string;
}

interface Service {
  id: number;
  expert_id: string;
  service_name: string;
  description: string;
  images?: string[];
  base_price: number;
  currency: string;
  status: string;
  view_count: number;
  application_count: number;
  created_at: string;
}

const ServiceListModal: React.FC<ServiceListModalProps> = ({
  isOpen,
  onClose,
  expertId,
  expertName,
}) => {
  const { t } = useLanguage();
  const [services, setServices] = useState<Service[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedServiceId, setSelectedServiceId] = useState<number | null>(null);
  const [showServiceDetailModal, setShowServiceDetailModal] = useState(false);
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [selectedServiceForApply, setSelectedServiceForApply] = useState<Service | null>(null);
  const [applyMessage, setApplyMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  const [applying, setApplying] = useState(false);
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);

  // 加载服务列表
  useEffect(() => {
    if (isOpen && expertId) {
      loadServices();
      loadCurrentUser();
    } else {
      // 关闭时重置状态
      setServices([]);
      setError('');
      setSelectedServiceId(null);
      setShowServiceDetailModal(false);
      setShowApplyModal(false);
      setSelectedServiceForApply(null);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
    }
  }, [isOpen, expertId]);

  const loadCurrentUser = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (err) {
      setUser(null);
    }
  };

  const loadServices = async () => {
    setLoading(true);
    setError('');
    try {
      const response = await getTaskExpertServices(expertId, 'active');
      const servicesList = response?.services || [];
      setServices(servicesList);
      
      if (servicesList.length === 0) {
        setError('该任务达人暂无可用服务');
      }
    } catch (err: any) {
      setError('加载服务列表失败');
      message.error('加载服务列表失败');
      console.error('Failed to load services:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleServiceClick = (serviceId: number) => {
    setSelectedServiceId(serviceId);
    setShowServiceDetailModal(true);
  };

  const handleServiceDetailClose = () => {
    setShowServiceDetailModal(false);
    setSelectedServiceId(null);
  };

  const handleApplyClick = (e: React.MouseEvent, service: Service) => {
    e.stopPropagation(); // 阻止事件冒泡，避免触发服务卡片点击
    
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 检查是否是自己的服务
    if (service.expert_id === user.id) {
      message.warning('不能申请自己的服务');
      return;
    }
    
    setSelectedServiceForApply(service);
    setShowApplyModal(true);
  };

  const handleSubmitApplication = async () => {
    if (!selectedServiceForApply || !user) return;
    
    setApplying(true);
    try {
      await applyForService(selectedServiceForApply.id, {
        application_message: applyMessage || undefined,
        negotiated_price: isNegotiateChecked && negotiatedPrice ? negotiatedPrice : undefined,
        currency: selectedServiceForApply.currency || 'GBP',
      });
      
      message.success('申请已提交，等待任务达人处理');
      setShowApplyModal(false);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      setSelectedServiceForApply(null);
      
      // 重新加载服务列表以更新申请数量
      await loadServices();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交申请失败');
    } finally {
      setApplying(false);
    }
  };

  if (!isOpen) return null;

  return (
    <>
      <div style={MODAL_OVERLAY_STYLE} onClick={onClose}>
        <div
          style={{
            backgroundColor: '#fff',
            borderRadius: '16px',
            padding: '24px',
            maxWidth: '800px',
            width: '90%',
            maxHeight: '90vh',
            overflowY: 'auto',
            position: 'relative',
          }}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            onClick={onClose}
            style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
              width: '32px',
              height: '32px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '50%',
              transition: 'background 0.2s',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#f0f0f0';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'none';
            }}
          >
            ×
          </button>

          <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '24px', fontWeight: 600 }}>
            {expertName ? `${expertName} 的服务菜单` : '服务菜单'}
          </h2>

          {loading ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: '#666' }}>加载中...</div>
            </div>
          ) : error ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: '#e53e3e' }}>{error}</div>
            </div>
          ) : services.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '40px' }}>
              <div style={{ fontSize: '18px', color: '#666' }}>暂无可用服务</div>
            </div>
          ) : (
            <div style={{ display: 'grid', gap: '16px' }}>
              {services.map((service) => (
                <div
                  key={service.id}
                  onClick={() => handleServiceClick(service.id)}
                  style={{
                    border: '2px solid #e2e8f0',
                    borderRadius: '12px',
                    padding: '20px',
                    cursor: 'pointer',
                    transition: 'all 0.3s ease',
                    background: '#fff',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.borderColor = '#667eea';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(102, 126, 234, 0.15)';
                    e.currentTarget.style.transform = 'translateY(-2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.borderColor = '#e2e8f0';
                    e.currentTarget.style.boxShadow = 'none';
                    e.currentTarget.style.transform = 'translateY(0)';
                  }}
                >
                  <div style={{ display: 'flex', gap: '16px', alignItems: 'flex-start' }}>
                    {/* 服务图片 */}
                    {service.images && service.images.length > 0 && (
                      <img
                        src={service.images[0]}
                        alt={service.service_name}
                        style={{
                          width: '120px',
                          height: '120px',
                          objectFit: 'cover',
                          borderRadius: '8px',
                          flexShrink: 0,
                        }}
                      />
                    )}
                    
                    <div style={{ flex: 1 }}>
                      {/* 服务名称 */}
                      <h3 style={{
                        fontSize: '18px',
                        fontWeight: 600,
                        color: '#1a202c',
                        marginBottom: '8px',
                      }}>
                        {service.service_name}
                      </h3>
                      
                      {/* 服务描述 */}
                      <p style={{
                        fontSize: '14px',
                        color: '#4a5568',
                        marginBottom: '12px',
                        lineHeight: '1.5',
                        display: '-webkit-box',
                        WebkitLineClamp: 2,
                        WebkitBoxOrient: 'vertical',
                        overflow: 'hidden',
                      }}>
                        {service.description}
                      </p>
                      
                      {/* 价格和统计 */}
                      <div style={{ display: 'flex', gap: '16px', alignItems: 'center', flexWrap: 'wrap', marginBottom: '12px' }}>
                        <div style={{
                          fontSize: '20px',
                          fontWeight: 700,
                          color: '#667eea',
                        }}>
                          {service.currency} {Number(service.base_price).toFixed(2)}
                        </div>
                        
                        <div style={{
                          fontSize: '12px',
                          color: '#718096',
                          display: 'flex',
                          gap: '12px',
                        }}>
                          <span>👁️ {service.view_count} 次浏览</span>
                          <span>📝 {service.application_count} 次申请</span>
                        </div>
                      </div>

                      {/* 申请按钮 */}
                      {service.status === 'active' && (
                        <button
                          onClick={(e) => handleApplyClick(e, service)}
                          style={{
                            padding: '10px 20px',
                            background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '8px',
                            fontSize: '14px',
                            fontWeight: 600,
                            cursor: 'pointer',
                            transition: 'all 0.2s',
                            width: '100%',
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.transform = 'translateY(-2px)';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.4)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.transform = 'translateY(0)';
                            e.currentTarget.style.boxShadow = 'none';
                          }}
                        >
                          申请服务
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* 服务详情弹窗 */}
      <ServiceDetailModal
        isOpen={showServiceDetailModal}
        onClose={handleServiceDetailClose}
        serviceId={selectedServiceId}
        onApplySuccess={() => {
          handleServiceDetailClose();
          loadServices(); // 重新加载服务列表以更新申请数量
        }}
      />

      {/* 申请服务弹窗 */}
      {showApplyModal && selectedServiceForApply && (
        <div style={MODAL_OVERLAY_STYLE} onClick={() => setShowApplyModal(false)}>
          <div
            style={{
              backgroundColor: '#fff',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: '500px',
              width: '100%',
              position: 'relative',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setShowApplyModal(false)}
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                background: 'none',
                border: 'none',
                fontSize: '24px',
                cursor: 'pointer',
                color: '#666',
                width: '32px',
                height: '32px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '50%',
                transition: 'background 0.2s',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#f0f0f0';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'none';
              }}
            >
              ×
            </button>

            <h2 style={{ marginBottom: '24px', color: '#1a202c', fontSize: '20px', fontWeight: 600 }}>
              申请服务：{selectedServiceForApply.service_name}
            </h2>

            {/* 申请留言 */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                申请留言（可选）
              </label>
              <textarea
                value={applyMessage}
                onChange={(e) => setApplyMessage(e.target.value)}
                placeholder="请输入您的申请留言..."
                maxLength={1000}
                style={{
                  width: '100%',
                  minHeight: '100px',
                  padding: '12px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '14px',
                  resize: 'vertical',
                  fontFamily: 'inherit',
                  outline: 'none',
                  transition: 'border-color 0.2s',
                  boxSizing: 'border-box',
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = '#e2e8f0';
                }}
              />
              <div style={{ fontSize: 12, color: '#666', textAlign: 'right', marginTop: 4 }}>
                {applyMessage.length}/1000
              </div>
            </div>

            {/* 议价选项 */}
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                <input
                  type="checkbox"
                  checked={isNegotiateChecked}
                  onChange={(e) => {
                    setIsNegotiateChecked(e.target.checked);
                    if (!e.target.checked) {
                      setNegotiatedPrice(undefined);
                    }
                  }}
                />
                <span style={{ color: '#2d3748' }}>我想议价</span>
              </label>
              
              {isNegotiateChecked && (
                <div style={{ marginTop: '12px', marginLeft: '24px' }}>
                  <label style={{ display: 'block', marginBottom: '8px', color: '#2d3748', fontWeight: 500 }}>
                    期望价格（{selectedServiceForApply.currency}）
                  </label>
                  <input
                    type="number"
                    value={negotiatedPrice || ''}
                    onChange={(e) => {
                      const value = parseFloat(e.target.value);
                      setNegotiatedPrice(isNaN(value) ? undefined : value);
                    }}
                    placeholder={`最低 ${selectedServiceForApply.currency} ${(selectedServiceForApply.base_price * 0.5).toFixed(2)}`}
                    min={selectedServiceForApply.base_price * 0.5}
                    step="0.01"
                    style={{
                      width: '100%',
                      padding: '12px',
                      border: '1px solid #e2e8f0',
                      borderRadius: '8px',
                      fontSize: '14px',
                      fontFamily: 'inherit',
                      outline: 'none',
                      transition: 'border-color 0.2s',
                      boxSizing: 'border-box',
                    }}
                    onFocus={(e) => {
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }}
                    onBlur={(e) => {
                      e.currentTarget.style.borderColor = '#e2e8f0';
                    }}
                  />
                  <div style={{ marginTop: '4px', fontSize: '12px', color: '#718096' }}>
                    最低价格为基础价格的50%（{selectedServiceForApply.currency} {(selectedServiceForApply.base_price * 0.5).toFixed(2)}）
                  </div>
                </div>
              )}
            </div>

            {/* 提交按钮 */}
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={handleSubmitApplication}
                disabled={applying || (isNegotiateChecked && (!negotiatedPrice || negotiatedPrice < selectedServiceForApply.base_price * 0.5))}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: applying
                    ? '#cbd5e0'
                    : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: 600,
                  cursor: applying ? 'not-allowed' : 'pointer',
                  transition: 'all 0.2s',
                }}
              >
                {applying ? '提交中...' : '提交申请'}
              </button>
              <button
                onClick={() => setShowApplyModal(false)}
                style={{
                  padding: '12px 24px',
                  background: '#f7fafc',
                  color: '#2d3748',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#edf2f7';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f7fafc';
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          loadCurrentUser();
        }}
      />
    </>
  );
};

export default ServiceListModal;

