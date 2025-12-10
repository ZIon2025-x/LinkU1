/**
 * 服务详情弹窗组件
 * 显示任务达人服务的详细信息，支持申请服务
 */

import React, { useState, useEffect } from 'react';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { getTaskExpertServiceDetail, applyForService, fetchCurrentUser, getServiceTimeSlotsPublic, applyToActivity } from '../api';
import LoginModal from './LoginModal';
import { MODAL_OVERLAY_STYLE } from './TaskDetailModal.styles';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LazyImage from './LazyImage';

interface ServiceDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  serviceId: number | null;
  onApplySuccess?: () => void;
}

interface ServiceDetail {
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
  has_time_slots?: boolean;
  time_slot_duration_minutes?: number;
  time_slot_start_time?: string;
  time_slot_end_time?: string;
  participants_per_slot?: number;
}

interface TimeSlot {
  id: number;
  service_id: number;
  slot_start_datetime?: string;
  slot_end_datetime?: string;
  is_available?: boolean;
  current_participants?: number;
  max_participants?: number;
  is_expired?: boolean;
  has_activity?: boolean;
  activity_id?: number;
}

const ServiceDetailModal: React.FC<ServiceDetailModalProps> = ({
  isOpen,
  onClose,
  serviceId,
  onApplySuccess,
}) => {
  const { t } = useLanguage();
  const [service, setService] = useState<ServiceDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<any>(null);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [timeSlots, setTimeSlots] = useState<TimeSlot[]>([]);
  const [loadingTimeSlots, setLoadingTimeSlots] = useState(false);
  const [selectedTimeSlotId, setSelectedTimeSlotId] = useState<number | null>(null);
  const [applying, setApplying] = useState(false);

  useEffect(() => {
    if (isOpen && serviceId) {
      loadServiceDetail();
      loadCurrentUser();
    } else {
      setService(null);
      setError('');
      setTimeSlots([]);
      setSelectedTimeSlotId(null);
    }
  }, [isOpen, serviceId]);

  const loadCurrentUser = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch {
      setUser(null);
    }
  };

  const loadServiceDetail = async () => {
    if (!serviceId) return;
    
    setLoading(true);
    setError('');
    
    try {
      const response = await getTaskExpertServiceDetail(serviceId);
      setService(response);
      
      // 如果服务有时间段，加载时间段
      if (response.has_time_slots) {
        loadTimeSlots(serviceId);
      }
    } catch (err: any) {
      setError('加载服务详情失败');
      message.error('加载服务详情失败');
    } finally {
      setLoading(false);
    }
  };

  const loadTimeSlots = async (serviceId: number) => {
    setLoadingTimeSlots(true);
    try {
      const response = await getServiceTimeSlotsPublic(serviceId);
      setTimeSlots(response.time_slots || []);
    } catch {
      setTimeSlots([]);
    } finally {
      setLoadingTimeSlots(false);
    }
  };

  const handleApply = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }

    if (!service) return;

    setApplying(true);
    try {
      if (service.has_time_slots) {
        if (!selectedTimeSlotId) {
          message.warning('请选择时间段');
          setApplying(false);
          return;
        }
        
        // 检查选中的时间段是否有活动
        const selectedSlot = timeSlots.find((slot) => slot.id === selectedTimeSlotId);
        if (selectedSlot && selectedSlot.has_activity && selectedSlot.activity_id) {
          const idempotencyKey = `${user.id}_${selectedSlot.activity_id}_${selectedTimeSlotId}_${Date.now()}`;
          await applyToActivity(selectedSlot.activity_id, {
            idempotency_key: idempotencyKey,
            time_slot_id: selectedTimeSlotId,
            is_multi_participant: true,
            max_participants: 1,
            min_participants: 1,
          });
        } else {
          // 如果没有活动，使用普通服务申请
          await applyForService(service.id, {
            application_message: '',
            time_slot_id: selectedTimeSlotId,
            negotiated_price: service.base_price,
            currency: service.currency || 'GBP',
          });
        }
        message.success('申请成功');
      } else {
        await applyForService(service.id, {
          application_message: '',
          negotiated_price: service.base_price,
          currency: service.currency || 'GBP',
        });
        message.success('申请成功');
      }
      
      if (onApplySuccess) {
        onApplySuccess();
      }
      onClose();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '申请失败');
    } finally {
      setApplying(false);
    }
  };

  if (!isOpen) return null;

  return (
    <>
      <div style={MODAL_OVERLAY_STYLE} onClick={onClose} />
      <div
        style={{
          position: 'fixed',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          background: '#fff',
          borderRadius: '12px',
          padding: '24px',
          maxWidth: '600px',
          width: '90%',
          maxHeight: '90vh',
          overflow: 'auto',
          zIndex: 1001,
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {loading ? (
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <div>加载中...</div>
          </div>
        ) : error ? (
          <div style={{ textAlign: 'center', padding: '40px' }}>
            <div>{error}</div>
            <button
              onClick={onClose}
              style={{
                marginTop: '16px',
                padding: '8px 16px',
                background: '#3b82f6',
                color: '#fff',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
              }}
            >
              关闭
            </button>
          </div>
        ) : service ? (
          <>
            <div style={{ marginBottom: '20px' }}>
              <h2 style={{ margin: '0 0 12px 0', fontSize: '24px', fontWeight: 'bold' }}>
                {service.service_name}
              </h2>
              <div style={{ color: '#666', fontSize: '14px', marginBottom: '16px' }}>
                {TimeHandlerV2.formatUtcToLocal(service.created_at, 'YYYY/MM/DD HH:mm')}
              </div>
              {service.description && (
                <div style={{ marginBottom: '16px', lineHeight: '1.6' }}>
                  {service.description}
                </div>
              )}
              {service.images && service.images.length > 0 && (
                <div style={{ marginBottom: '16px' }}>
                  {service.images.map((img, index) => (
                    <LazyImage
                      key={index}
                      src={img}
                      alt={`${service.service_name} ${index + 1}`}
                      style={{
                        width: '100%',
                        maxHeight: '300px',
                        objectFit: 'cover',
                        borderRadius: '8px',
                        marginBottom: '8px',
                      }}
                    />
                  ))}
                </div>
              )}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <div>
                  <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#3b82f6' }}>
                    {service.currency} {service.base_price.toFixed(2)}
                  </div>
                </div>
                <div style={{ color: '#666', fontSize: '14px' }}>
                  已申请: {service.application_count} | 浏览: {service.view_count}
                </div>
              </div>
              
              {service.has_time_slots && (
                <div style={{ marginBottom: '16px' }}>
                  <div style={{ marginBottom: '8px', fontWeight: 'bold' }}>选择时间段：</div>
                  {loadingTimeSlots ? (
                    <div>加载时间段中...</div>
                  ) : timeSlots.length === 0 ? (
                    <div style={{ color: '#999' }}>暂无可用时间段</div>
                  ) : (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '200px', overflow: 'auto' }}>
                      {timeSlots.map((slot) => (
                        <button
                          key={slot.id}
                          onClick={() => setSelectedTimeSlotId(slot.id)}
                          disabled={!slot.is_available || slot.is_expired}
                          style={{
                            padding: '12px',
                            border: selectedTimeSlotId === slot.id ? '2px solid #3b82f6' : '1px solid #ddd',
                            borderRadius: '6px',
                            background: selectedTimeSlotId === slot.id ? '#eff6ff' : '#fff',
                            cursor: slot.is_available && !slot.is_expired ? 'pointer' : 'not-allowed',
                            opacity: slot.is_available && !slot.is_expired ? 1 : 0.5,
                          }}
                        >
                          <div>
                            {slot.slot_start_datetime 
                              ? TimeHandlerV2.formatUtcToLocal(slot.slot_start_datetime, 'YYYY/MM/DD HH:mm')
                              : ''}
                          </div>
                          {slot.max_participants && (
                            <div style={{ fontSize: '12px', color: '#666' }}>
                              {slot.current_participants || 0}/{slot.max_participants} 人
                            </div>
                          )}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
            
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={onClose}
                style={{
                  padding: '10px 20px',
                  border: '1px solid #ddd',
                  borderRadius: '6px',
                  background: '#fff',
                  cursor: 'pointer',
                }}
              >
                取消
              </button>
              <button
                onClick={handleApply}
                disabled={applying || (service.has_time_slots && !selectedTimeSlotId)}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '6px',
                  background: applying ? '#ccc' : '#3b82f6',
                  color: '#fff',
                  cursor: applying ? 'not-allowed' : 'pointer',
                }}
              >
                {applying ? '申请中...' : '申请服务'}
              </button>
            </div>
          </>
        ) : null}
      </div>

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

export default ServiceDetailModal;
