/**
 * 任务达人管理后台
 * 路径: /task-experts/me/dashboard
 * 功能: 服务管理、申请管理
 */

import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import {
  fetchCurrentUser,
  getTaskExpert,
  updateTaskExpertProfile,
  getMyTaskExpertServices,
  createTaskExpertService,
  updateTaskExpertService,
  deleteTaskExpertService,
  getMyTaskExpertApplications,
  approveServiceApplication,
  rejectServiceApplication,
  counterOfferServiceApplication,
  submitProfileUpdateRequest,
  getMyProfileUpdateRequest,
} from '../api';
import LoginModal from '../components/LoginModal';
import ServiceDetailModal from '../components/ServiceDetailModal';
import api from '../api';

interface Service {
  id: number;
  service_name: string;
  description: string;
  images?: string[];
  base_price: number;
  currency: string;
  status: string;
  display_order: number;
  view_count: number;
  application_count: number;
  created_at: string;
}

interface Application {
  id: number;
  service_id: number;
  service_name: string;
  applicant_id: string;
  applicant_name: string;
  status: string;
  application_message?: string;
  negotiated_price?: number;
  expert_counter_price?: number;
  final_price?: number;
  currency?: string;
  task_id?: number;
  created_at: string;
  updated_at: string;
}

const TaskExpertDashboard: React.FC = () => {
  const { t } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const [user, setUser] = useState<any>(null);
  const [expert, setExpert] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'services' | 'applications'>('services');
  
  // 服务管理相关
  const [services, setServices] = useState<Service[]>([]);
  const [loadingServices, setLoadingServices] = useState(false);
  const [showServiceModal, setShowServiceModal] = useState(false);
  const [editingService, setEditingService] = useState<Service | null>(null);
  
  // 申请管理相关
  const [applications, setApplications] = useState<Application[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [selectedApplication, setSelectedApplication] = useState<Application | null>(null);
  const [showCounterOfferModal, setShowCounterOfferModal] = useState(false);
  const [counterPrice, setCounterPrice] = useState<number | undefined>();
  const [counterMessage, setCounterMessage] = useState('');
  
  // 登录弹窗
  const [showLoginModal, setShowLoginModal] = useState(false);
  
  // 信息修改相关
  const [showProfileEditModal, setShowProfileEditModal] = useState(false);
  const [profileForm, setProfileForm] = useState({ expert_name: '', bio: '', avatar: '' });
  const [pendingRequest, setPendingRequest] = useState<any>(null);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string>('');

  useEffect(() => {
    loadData();
    loadPendingRequest();
  }, []);
  
  const loadPendingRequest = async () => {
    try {
      const request = await getMyProfileUpdateRequest();
      setPendingRequest(request);
    } catch (err: any) {
      // 如果没有待审核请求，忽略错误
      if (err.response?.status !== 404) {
        console.error('加载待审核请求失败:', err);
      }
    }
  };

  useEffect(() => {
    if (activeTab === 'services') {
      loadServices();
    } else if (activeTab === 'applications') {
      loadApplications();
    }
  }, [activeTab]);

  const loadData = async () => {
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
      
      // 加载任务达人信息
      const expertData = await getTaskExpert(userData.id);
      setExpert(expertData);
    } catch (err: any) {
      if (err.response?.status === 401) {
        setShowLoginModal(true);
      } else if (err.response?.status === 404) {
        message.error('您还不是任务达人');
        navigate('/task-experts/intro');
      } else {
        message.error('加载数据失败');
      }
    } finally {
      setLoading(false);
    }
  };

  const loadServices = async () => {
    setLoadingServices(true);
    try {
      const data = await getMyTaskExpertServices();
      // API返回的数据结构可能是 { items: [...] } 或直接是数组
      setServices(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载服务列表失败');
    } finally {
      setLoadingServices(false);
    }
  };

  const loadApplications = async () => {
    setLoadingApplications(true);
    try {
      const data = await getMyTaskExpertApplications();
      // API返回的数据结构可能是 { items: [...] } 或直接是数组
      setApplications(Array.isArray(data) ? data : (data.items || []));
    } catch (err: any) {
      message.error('加载申请列表失败');
    } finally {
      setLoadingApplications(false);
    }
  };

  const handleCreateService = () => {
    setEditingService(null);
    setShowServiceModal(true);
  };

  const handleEditService = (service: Service) => {
    setEditingService(service);
    setShowServiceModal(true);
  };

  const handleDeleteService = async (serviceId: number) => {
    if (!window.confirm('确定要删除这个服务吗？')) {
      return;
    }
    
    try {
      await deleteTaskExpertService(serviceId);
      message.success('服务已删除');
      loadServices();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '删除服务失败');
    }
  };

  const handleApproveApplication = async (applicationId: number) => {
    try {
      const result = await approveServiceApplication(applicationId);
      message.success('申请已同意，任务已创建');
      if (result.task_id) {
        // 可以跳转到任务聊天页面
        navigate(`/tasks/${result.task_id}`);
      }
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '同意申请失败');
    }
  };

  const handleRejectApplication = async (applicationId: number, reason?: string) => {
    // ⚠️ 性能优化：乐观更新 UI，不等待重新加载
    const originalApplications = [...applications];
    setApplications(prev => prev.map(app => 
      app.id === applicationId ? { ...app, status: 'rejected' } : app
    ));
    
    try {
      await rejectServiceApplication(applicationId, reason);
      message.success('申请已拒绝');
      // ⚠️ 后台刷新，不阻塞 UI
      loadApplications().catch(err => {
        console.error('刷新申请列表失败:', err);
        // 如果刷新失败，恢复原状态
        setApplications(originalApplications);
      });
    } catch (err: any) {
      // 如果失败，恢复原状态
      setApplications(originalApplications);
      message.error(err.response?.data?.detail || '拒绝申请失败');
    }
  };

  const handleCounterOffer = (application: Application) => {
    setSelectedApplication(application);
    setCounterPrice(application.negotiated_price ? application.negotiated_price * 1.2 : undefined);
    setCounterMessage('');
    setShowCounterOfferModal(true);
  };

  const handleSubmitCounterOffer = async () => {
    if (!selectedApplication || !counterPrice) {
      message.warning('请输入议价价格');
      return;
    }
    
    try {
      await counterOfferServiceApplication(selectedApplication.id, {
        counter_price: counterPrice,
        message: counterMessage || undefined,
      });
      message.success('议价已提交');
      setShowCounterOfferModal(false);
      loadApplications();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交议价失败');
    }
  };

  const getStatusText = (status: string) => {
    const statusMap: { [key: string]: string } = {
      pending: '待处理',
      negotiating: '议价中',
      price_agreed: '价格已达成',
      approved: '已同意',
      rejected: '已拒绝',
      cancelled: '已取消',
    };
    return statusMap[status] || status;
  };

  const getStatusColor = (status: string) => {
    const colorMap: { [key: string]: string } = {
      pending: '#f59e0b',
      negotiating: '#3b82f6',
      price_agreed: '#10b981',
      approved: '#10b981',
      rejected: '#ef4444',
      cancelled: '#6b7280',
    };
    return colorMap[status] || '#6b7280';
  };
  
  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        message.error('头像文件大小不能超过5MB');
        return;
      }
      if (!file.type.startsWith('image/')) {
        message.error('请选择图片文件');
        return;
      }
      setAvatarFile(file);
      const reader = new FileReader();
      reader.onloadend = () => {
        setAvatarPreview(reader.result as string);
      };
      reader.readAsDataURL(file);
    }
  };
  
  const handleUploadAvatar = async (): Promise<string | null> => {
    if (!avatarFile) {
      return profileForm.avatar || null;
    }
    
    try {
      const formData = new FormData();
      formData.append('file', avatarFile);
      const res = await api.post('/api/upload/image', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      return res.data.url;
    } catch (err: any) {
      message.error('上传头像失败');
      return null;
    }
  };
  
  const handleSubmitProfileUpdate = async () => {
    if (!profileForm.expert_name && !profileForm.bio && !avatarFile && !profileForm.avatar) {
      message.warning('请至少修改一个字段');
      return;
    }
    
    if (pendingRequest) {
      message.warning('您已有一个待审核的修改请求，请等待审核完成后再提交新的请求');
      return;
    }
    
    try {
      let avatarUrl: string | null = profileForm.avatar || null;
      if (avatarFile) {
        avatarUrl = await handleUploadAvatar();
        if (!avatarUrl) {
          return;
        }
      }
      
      await submitProfileUpdateRequest({
        expert_name: profileForm.expert_name || undefined,
        bio: profileForm.bio || undefined,
        avatar: avatarUrl || undefined,
      });
      
      message.success('修改请求已提交，等待管理员审核');
      setShowProfileEditModal(false);
      loadPendingRequest();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '提交修改请求失败');
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '60px', fontSize: '18px' }}>
        加载中...
      </div>
    );
  }

  if (!expert) {
    return (
      <div style={{ textAlign: 'center', padding: '60px' }}>
        <div style={{ fontSize: '18px', marginBottom: '20px' }}>您还不是任务达人</div>
        <button
          onClick={() => navigate('/task-experts/intro')}
          style={{
            padding: '12px 24px',
            background: '#3b82f6',
            color: '#fff',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
          }}
        >
          申请成为任务达人
        </button>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: '#f7fafc', padding: '20px' }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto' }}>
        {/* 头部 */}
        <div style={{ background: '#fff', borderRadius: '12px', padding: '24px', marginBottom: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h1 style={{ margin: 0, fontSize: '24px', fontWeight: 600, color: '#1a202c' }}>
                任务达人管理后台
              </h1>
              <div style={{ marginTop: '12px', color: '#718096' }}>
                欢迎回来，{expert.expert_name || user?.name || '任务达人'}
              </div>
              {pendingRequest && (
                <div style={{ marginTop: '12px', padding: '8px 12px', background: '#fef3c7', borderRadius: '6px', color: '#92400e', fontSize: '14px' }}>
                  您有一个待审核的信息修改请求，请等待管理员审核
                </div>
              )}
            </div>
            <button
              onClick={() => {
                setProfileForm({
                  expert_name: expert.expert_name || '',
                  bio: expert.bio || '',
                  avatar: expert.avatar || '',
                });
                setAvatarPreview(expert.avatar || '');
                setShowProfileEditModal(true);
              }}
              style={{
                padding: '10px 20px',
                background: '#3b82f6',
                color: '#fff',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: 500,
              }}
            >
              编辑资料
            </button>
          </div>
        </div>

        {/* 标签页 */}
        <div style={{ display: 'flex', gap: '12px', marginBottom: '24px' }}>
          <button
            onClick={() => setActiveTab('services')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'services' ? '#3b82f6' : '#fff',
              color: activeTab === 'services' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            服务管理
          </button>
          <button
            onClick={() => setActiveTab('applications')}
            style={{
              padding: '12px 24px',
              background: activeTab === 'applications' ? '#3b82f6' : '#fff',
              color: activeTab === 'applications' ? '#fff' : '#333',
              border: '1px solid #e2e8f0',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: 600,
            }}
          >
            申请管理
          </button>
        </div>

        {/* 服务管理 */}
        {activeTab === 'services' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h2 style={{ margin: 0, fontSize: '20px', fontWeight: 600 }}>我的服务</h2>
              <button
                onClick={handleCreateService}
                style={{
                  padding: '10px 20px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontWeight: 600,
                }}
              >
                + 创建服务
              </button>
            </div>

            {loadingServices ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : services.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无服务，点击"创建服务"按钮添加
              </div>
            ) : (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '20px' }}>
                {services.map((service) => (
                  <div
                    key={service.id}
                    style={{
                      border: '1px solid #e2e8f0',
                      borderRadius: '12px',
                      padding: '20px',
                      background: '#fff',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                      <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600, color: '#1a202c' }}>
                        {service.service_name}
                      </h3>
                      <span
                        style={{
                          padding: '4px 8px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 600,
                          background: service.status === 'active' ? '#d1fae5' : '#fee2e2',
                          color: service.status === 'active' ? '#065f46' : '#991b1b',
                        }}
                      >
                        {service.status === 'active' ? '上架' : '下架'}
                      </span>
                    </div>
                    
                    <div style={{ fontSize: '14px', color: '#4a5568', marginBottom: '12px', lineHeight: '1.5' }}>
                      {service.description?.substring(0, 100)}
                      {service.description && service.description.length > 100 ? '...' : ''}
                    </div>
                    
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                      <div style={{ fontSize: '20px', fontWeight: 700, color: '#3b82f6' }}>
                        {service.currency} {service.base_price.toFixed(2)}
                      </div>
                      <div style={{ fontSize: '12px', color: '#718096' }}>
                        {service.application_count} 申请
                      </div>
                    </div>
                    
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button
                        onClick={() => handleEditService(service)}
                        style={{
                          flex: 1,
                          padding: '8px',
                          background: '#f3f4f6',
                          color: '#333',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        编辑
                      </button>
                      <button
                        onClick={() => handleDeleteService(service.id)}
                        style={{
                          flex: 1,
                          padding: '8px',
                          background: '#fee2e2',
                          color: '#991b1b',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          fontSize: '14px',
                        }}
                      >
                        删除
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}

        {/* 申请管理 */}
        {activeTab === 'applications' && (
          <div style={{ background: '#fff', borderRadius: '12px', padding: '24px' }}>
            <h2 style={{ margin: '0 0 24px 0', fontSize: '20px', fontWeight: 600 }}>收到的申请</h2>

            {loadingApplications ? (
              <div style={{ textAlign: 'center', padding: '40px' }}>加载中...</div>
            ) : applications.length === 0 ? (
              <div style={{ textAlign: 'center', padding: '60px', color: '#718096' }}>
                暂无申请
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {applications.map((app) => (
                  <div
                    key={app.id}
                    style={{
                      border: '1px solid #e2e8f0',
                      borderRadius: '12px',
                      padding: '20px',
                      background: '#fff',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: '12px' }}>
                      <div>
                        <div style={{ fontSize: '18px', fontWeight: 600, color: '#1a202c', marginBottom: '4px' }}>
                          {app.service_name}
                        </div>
                        <div style={{ fontSize: '14px', color: '#718096' }}>
                          申请用户: {app.applicant_name || app.applicant_id}
                        </div>
                      </div>
                      <span
                        style={{
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 600,
                          background: getStatusColor(app.status) + '20',
                          color: getStatusColor(app.status),
                        }}
                      >
                        {getStatusText(app.status)}
                      </span>
                    </div>

                    {app.application_message && (
                      <div style={{ fontSize: '14px', color: '#4a5568', marginBottom: '12px', padding: '12px', background: '#f7fafc', borderRadius: '8px' }}>
                        {app.application_message}
                      </div>
                    )}

                    <div style={{ display: 'flex', gap: '8px', marginBottom: '12px', fontSize: '14px', color: '#718096' }}>
                      {app.negotiated_price && (
                        <span>用户议价: {app.currency || 'GBP'} {app.negotiated_price.toFixed(2)}</span>
                      )}
                      {app.expert_counter_price && (
                        <span>我的议价: {app.currency || 'GBP'} {app.expert_counter_price.toFixed(2)}</span>
                      )}
                      {app.final_price && (
                        <span>最终价格: {app.currency || 'GBP'} {app.final_price.toFixed(2)}</span>
                      )}
                    </div>

                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {app.status === 'pending' && (
                        <>
                          <button
                            onClick={() => handleApproveApplication(app.id)}
                            style={{
                              padding: '8px 16px',
                              background: '#10b981',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            同意申请
                          </button>
                          <button
                            onClick={() => handleCounterOffer(app)}
                            style={{
                              padding: '8px 16px',
                              background: '#3b82f6',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            再次议价
                          </button>
                          <button
                            onClick={() => {
                              const reason = window.prompt('请输入拒绝原因（可选）');
                              handleRejectApplication(app.id, reason || undefined);
                            }}
                            style={{
                              padding: '8px 16px',
                              background: '#ef4444',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              fontSize: '14px',
                              fontWeight: 600,
                            }}
                          >
                            拒绝申请
                          </button>
                        </>
                      )}
                      {app.status === 'price_agreed' && (
                        <button
                          onClick={() => handleApproveApplication(app.id)}
                          style={{
                            padding: '8px 16px',
                            background: '#10b981',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          创建任务
                        </button>
                      )}
                      {app.status === 'approved' && app.task_id && (
                        <button
                          onClick={() => navigate(`/tasks/${app.task_id}`)}
                          style={{
                            padding: '8px 16px',
                            background: '#3b82f6',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: 600,
                          }}
                        >
                          查看任务
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {/* 服务编辑弹窗 */}
      {showServiceModal && (
        <ServiceEditModal
          service={editingService}
          onClose={() => {
            setShowServiceModal(false);
            setEditingService(null);
          }}
          onSuccess={() => {
            setShowServiceModal(false);
            setEditingService(null);
            loadServices();
          }}
        />
      )}

      {/* 议价弹窗 */}
      {showCounterOfferModal && selectedApplication && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowCounterOfferModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '500px',
              width: '100%',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 20px 0', fontSize: '18px', fontWeight: 600 }}>
              再次议价
            </h3>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                议价价格 ({selectedApplication.currency || 'GBP'})
              </label>
              <input
                type="number"
                value={counterPrice || ''}
                onChange={(e) => setCounterPrice(parseFloat(e.target.value) || undefined)}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
              />
            </div>
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                说明（可选）
              </label>
              <textarea
                value={counterMessage}
                onChange={(e) => setCounterMessage(e.target.value)}
                style={{
                  width: '100%',
                  minHeight: '80px',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  resize: 'vertical',
                }}
              />
            </div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <button
                onClick={handleSubmitCounterOffer}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                提交
              </button>
              <button
                onClick={() => setShowCounterOfferModal(false)}
                style={{
                  flex: 1,
                  padding: '10px',
                  background: '#f3f4f6',
                  color: '#333',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
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
          loadData();
        }}
      />
      
      {/* 编辑资料弹窗 */}
      {showProfileEditModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowProfileEditModal(false)}
        >
          <div
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              width: '90%',
              maxWidth: '500px',
              maxHeight: '90vh',
              overflow: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>编辑资料</h2>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                名字
              </label>
              <input
                type="text"
                value={profileForm.expert_name}
                onChange={(e) => setProfileForm({ ...profileForm, expert_name: e.target.value })}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
                placeholder="请输入您的名字"
              />
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                简介
              </label>
              <textarea
                value={profileForm.bio}
                onChange={(e) => setProfileForm({ ...profileForm, bio: e.target.value })}
                style={{
                  width: '100%',
                  padding: '10px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                  minHeight: '100px',
                  resize: 'vertical',
                }}
                placeholder="请输入您的简介"
              />
            </div>
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
                头像
              </label>
              {avatarPreview && (
                <div style={{ marginBottom: '12px' }}>
                  <img
                    src={avatarPreview}
                    alt="头像预览"
                    style={{
                      width: '100px',
                      height: '100px',
                      objectFit: 'cover',
                      borderRadius: '50%',
                      border: '1px solid #e2e8f0',
                    }}
                  />
                </div>
              )}
              <input
                type="file"
                accept="image/*"
                onChange={handleAvatarChange}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #e2e8f0',
                  borderRadius: '6px',
                  fontSize: '14px',
                }}
              />
              <div style={{ marginTop: '8px', fontSize: '12px', color: '#718096' }}>
                支持 JPG、PNG 格式，文件大小不超过 5MB
              </div>
            </div>
            <div style={{ marginTop: '20px', padding: '12px', background: '#fef3c7', borderRadius: '6px', fontSize: '14px', color: '#92400e' }}>
              注意：修改信息需要管理员审核，审核通过后才会生效
            </div>
            <div style={{ display: 'flex', gap: '12px', marginTop: '24px' }}>
              <button
                onClick={() => setShowProfileEditModal(false)}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: '#f3f4f6',
                  color: '#333',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                取消
              </button>
              <button
                onClick={handleSubmitProfileUpdate}
                style={{
                  flex: 1,
                  padding: '12px',
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: 600,
                }}
              >
                提交审核
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

// 服务编辑弹窗组件
interface ServiceEditModalProps {
  service: Service | null;
  onClose: () => void;
  onSuccess: () => void;
}

const ServiceEditModal: React.FC<ServiceEditModalProps> = ({ service, onClose, onSuccess }) => {
  const [formData, setFormData] = useState({
    service_name: '',
    description: '',
    base_price: 0,
    currency: 'GBP',
    status: 'active',
    images: [] as string[],
  });
  const [saving, setSaving] = useState(false);
  const [uploadingImages, setUploadingImages] = useState<boolean[]>([]);

  useEffect(() => {
    if (service) {
      setFormData({
        service_name: service.service_name,
        description: service.description || '',
        base_price: service.base_price,
        currency: service.currency,
        status: service.status,
        images: service.images || [],
      });
    }
  }, [service]);

  const handleSubmit = async () => {
    if (!formData.service_name || !formData.description || formData.base_price <= 0) {
      message.warning('请填写完整信息');
      return;
    }

    setSaving(true);
    try {
      if (service) {
        await updateTaskExpertService(service.id, formData);
        message.success('服务已更新');
      } else {
        await createTaskExpertService(formData);
        message.success('服务已创建');
      }
      onSuccess();
    } catch (err: any) {
      message.error(err.response?.data?.detail || '保存失败');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: '#fff',
          borderRadius: '12px',
          padding: '24px',
          maxWidth: '600px',
          width: '100%',
          maxHeight: '90vh',
          overflowY: 'auto',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <h3 style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>
            {service ? '编辑服务' : '创建服务'}
          </h3>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
            }}
          >
            ×
          </button>
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务名称 *
          </label>
          <input
            type="text"
            value={formData.service_name}
            onChange={(e) => setFormData({ ...formData, service_name: e.target.value })}
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          />
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务描述 *
          </label>
          <textarea
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            style={{
              width: '100%',
              minHeight: '120px',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
              resize: 'vertical',
            }}
          />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '16px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
              基础价格 *
            </label>
            <input
              type="number"
              value={formData.base_price}
              onChange={(e) => setFormData({ ...formData, base_price: parseFloat(e.target.value) || 0 })}
              min="0"
              step="0.01"
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #e2e8f0',
                borderRadius: '6px',
                fontSize: '14px',
              }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
              货币
            </label>
            <select
              value={formData.currency}
              onChange={(e) => setFormData({ ...formData, currency: e.target.value })}
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #e2e8f0',
                borderRadius: '6px',
                fontSize: '14px',
              }}
            >
              <option value="GBP">GBP</option>
              <option value="USD">USD</option>
              <option value="EUR">EUR</option>
            </select>
          </div>
        </div>

        <div style={{ marginBottom: '16px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            服务图片（最多5张）
          </label>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px', marginBottom: '12px' }}>
            {formData.images.map((imageUrl, index) => (
              <div key={index} style={{ position: 'relative', width: '100px', height: '100px' }}>
                <img
                  src={imageUrl}
                  alt={`服务图片 ${index + 1}`}
                  style={{
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                    borderRadius: '8px',
                    border: '1px solid #e2e8f0',
                  }}
                />
                <button
                  onClick={() => {
                    const newImages = formData.images.filter((_, i) => i !== index);
                    setFormData({ ...formData, images: newImages });
                  }}
                  style={{
                    position: 'absolute',
                    top: '-8px',
                    right: '-8px',
                    background: '#ef4444',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '50%',
                    width: '24px',
                    height: '24px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  ×
                </button>
              </div>
            ))}
            {formData.images.length < 5 && (
              <label
                style={{
                  width: '100px',
                  height: '100px',
                  border: '2px dashed #cbd5e0',
                  borderRadius: '8px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  background: '#f7fafc',
                  transition: 'all 0.2s',
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.background = '#eff6ff';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.borderColor = '#cbd5e0';
                  e.currentTarget.style.background = '#f7fafc';
                }}
              >
                <input
                  type="file"
                  accept="image/*"
                  style={{ display: 'none' }}
                  onChange={async (e) => {
                    const file = e.target.files?.[0];
                    if (!file) return;
                    
                    // 检查文件大小（限制5MB）
                    if (file.size > 5 * 1024 * 1024) {
                      message.warning('图片文件过大，请选择小于5MB的图片');
                      e.target.value = '';
                      return;
                    }
                    
                    // 检查文件类型
                    if (!file.type.startsWith('image/')) {
                      message.warning('请选择图片文件');
                      e.target.value = '';
                      return;
                    }
                    
                    const imageIndex = formData.images.length;
                    setUploadingImages(prev => [...prev, true]);
                    
                    try {
                      const formDataUpload = new FormData();
                      formDataUpload.append('image', file);
                      
                      const response = await api.post('/api/upload/public-image', formDataUpload, {
                        headers: {
                          'Content-Type': 'multipart/form-data',
                        },
                      });
                      
                      if (response.data.success && response.data.url) {
                        setFormData({
                          ...formData,
                          images: [...formData.images, response.data.url],
                        });
                        message.success('图片上传成功');
                      } else {
                        message.error('图片上传失败，请重试');
                      }
                    } catch (error: any) {
                      console.error('图片上传失败:', error);
                      message.error(error.response?.data?.detail || '图片上传失败，请重试');
                    } finally {
                      setUploadingImages(prev => prev.filter((_, i) => i !== imageIndex));
                      e.target.value = '';
                    }
                  }}
                />
                <div style={{ textAlign: 'center', color: '#64748b' }}>
                  <div style={{ fontSize: '24px', marginBottom: '4px' }}>📷</div>
                  <div style={{ fontSize: '12px' }}>添加图片</div>
                </div>
              </label>
            )}
          </div>
          {formData.images.length > 0 && (
            <div style={{ fontSize: '12px', color: '#718096' }}>
              已上传 {formData.images.length} 张图片
            </div>
          )}
        </div>

        <div style={{ marginBottom: '20px' }}>
          <label style={{ display: 'block', marginBottom: '8px', fontSize: '14px', fontWeight: 500 }}>
            状态
          </label>
          <select
            value={formData.status}
            onChange={(e) => setFormData({ ...formData, status: e.target.value })}
            style={{
              width: '100%',
              padding: '10px',
              border: '1px solid #e2e8f0',
              borderRadius: '6px',
              fontSize: '14px',
            }}
          >
            <option value="active">上架</option>
            <option value="inactive">下架</option>
          </select>
        </div>

        <div style={{ display: 'flex', gap: '12px' }}>
          <button
            onClick={handleSubmit}
            disabled={saving}
            style={{
              flex: 1,
              padding: '12px',
              background: saving ? '#cbd5e0' : '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '6px',
              cursor: saving ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: 600,
            }}
          >
            {saving ? '保存中...' : '保存'}
          </button>
          <button
            onClick={onClose}
            style={{
              flex: 1,
              padding: '12px',
              background: '#f3f4f6',
              color: '#333',
              border: 'none',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: 600,
            }}
          >
            取消
          </button>
        </div>
      </div>
    </div>
  );
};

export default TaskExpertDashboard;

