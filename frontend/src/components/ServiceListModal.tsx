/**
 * 服务列表弹窗组件
 * 显示任务达人的所有可用服务，用户可以选择服务并查看详情
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { getTaskExpertServices } from '../api';
import ServiceDetailModal from './ServiceDetailModal';
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

  // 加载服务列表
  useEffect(() => {
    if (isOpen && expertId) {
      loadServices();
    } else {
      // 关闭时重置状态
      setServices([]);
      setError('');
      setSelectedServiceId(null);
      setShowServiceDetailModal(false);
    }
  }, [isOpen, expertId]);

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
                      <div style={{ display: 'flex', gap: '16px', alignItems: 'center', flexWrap: 'wrap' }}>
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
    </>
  );
};

export default ServiceListModal;

