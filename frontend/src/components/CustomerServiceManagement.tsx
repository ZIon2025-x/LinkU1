import React, { useState, useEffect } from 'react';
import { 
  getAdminCustomerServiceRequests,
  getAdminCustomerServiceRequestDetail,
  updateAdminCustomerServiceRequest,
  getAdminCustomerServiceChatMessages,
  sendAdminCustomerServiceChatMessage
} from '../api';
import dayjs from 'dayjs';
import { TimeHandlerV2 } from '../utils/timeUtils';

interface CustomerServiceRequest {
  id: number;
  requester_id: string;
  requester_name: string;
  type: string;
  title: string;
  description: string;
  priority: string;
  status: string;
  admin_response?: string;
  admin_id?: string;
  created_at: string;
  updated_at?: string;
}

interface ChatMessage {
  id: number;
  sender_id?: string;
  sender_type: string;
  sender_name?: string;
  content: string;
  created_at: string;
}

interface CustomerServiceManagementProps {
  onClose: () => void;
}

const CustomerServiceManagement: React.FC<CustomerServiceManagementProps> = ({ onClose }) => {
  const [activeTab, setActiveTab] = useState<'requests' | 'chat'>('requests');
  const [requests, setRequests] = useState<CustomerServiceRequest[]>([]);
  const [chatMessages, setChatMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedRequest, setSelectedRequest] = useState<CustomerServiceRequest | null>(null);
  const [showRequestDetail, setShowRequestDetail] = useState(false);
  const [showChatModal, setShowChatModal] = useState(false);
  
  // 筛选状态
  const [filters, setFilters] = useState({
    status: '',
    priority: ''
  });
  
  // 聊天状态
  const [newMessage, setNewMessage] = useState('');

  const loadRequests = async () => {
    try {
      setLoading(true);
      const response = await getAdminCustomerServiceRequests(filters);
      setRequests(response.requests || []);
    } catch (error) {
      console.error('加载客服请求失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadChatMessages = async () => {
    try {
      setLoading(true);
      const response = await getAdminCustomerServiceChatMessages();
      setChatMessages(response.messages || []);
    } catch (error) {
      console.error('加载聊天记录失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'requests') {
      loadRequests();
    } else {
      loadChatMessages();
    }
  }, [activeTab, filters]);

  const handleViewRequest = async (requestId: number) => {
    try {
      const response = await getAdminCustomerServiceRequestDetail(requestId);
      setSelectedRequest(response.request);
      setShowRequestDetail(true);
    } catch (error) {
      console.error('获取请求详情失败:', error);
    }
  };

  const handleUpdateRequest = async (requestId: number, updateData: any) => {
    try {
      await updateAdminCustomerServiceRequest(requestId, updateData);
      await loadRequests();
      alert('请求更新成功');
    } catch (error) {
      console.error('更新请求失败:', error);
      alert('更新请求失败');
    }
  };

  const handleSendMessage = async () => {
    if (!newMessage.trim()) return;
    
    try {
      await sendAdminCustomerServiceChatMessage(newMessage);
      setNewMessage('');
      await loadChatMessages();
    } catch (error) {
      console.error('发送消息失败:', error);
      alert('发送消息失败');
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return '#ffc107';
      case 'processing': return '#17a2b8';
      case 'completed': return '#28a745';
      case 'rejected': return '#dc3545';
      default: return '#6c757d';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending': return '待处理';
      case 'processing': return '处理中';
      case 'completed': return '已完成';
      case 'rejected': return '已拒绝';
      default: return status;
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'high': return '#dc3545';
      case 'medium': return '#ffc107';
      case 'low': return '#28a745';
      default: return '#6c757d';
    }
  };

  const getPriorityText = (priority: string) => {
    switch (priority) {
      case 'high': return '高';
      case 'medium': return '中';
      case 'low': return '低';
      default: return priority;
    }
  };

  const getTypeText = (type: string) => {
    switch (type) {
      case 'task_status': return '任务状态';
      case 'user_ban': return '用户封禁';
      case 'feedback': return '反馈建议';
      case 'other': return '其他';
      default: return type;
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '1200px',
        width: '95%',
        maxHeight: '90vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        {/* 头部 */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h2 style={{ margin: 0, color: '#333' }}>客服管理</h2>
          <button
            onClick={onClose}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>

        {/* 标签页 */}
        <div style={{
          display: 'flex',
          gap: '10px',
          marginBottom: '20px',
          borderBottom: '1px solid #eee'
        }}>
          <button
            onClick={() => setActiveTab('requests')}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: activeTab === 'requests' ? '#007bff' : '#f0f0f0',
              color: activeTab === 'requests' ? 'white' : 'black',
              cursor: 'pointer',
              borderRadius: '5px 5px 0 0',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            客服请求
          </button>
          <button
            onClick={() => setActiveTab('chat')}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: activeTab === 'chat' ? '#007bff' : '#f0f0f0',
              color: activeTab === 'chat' ? 'white' : 'black',
              cursor: 'pointer',
              borderRadius: '5px 5px 0 0',
              fontSize: '14px',
              fontWeight: '500'
            }}
          >
            客服交流
          </button>
        </div>

        {/* 客服请求标签页 */}
        {activeTab === 'requests' && (
          <div>
            {/* 筛选器 */}
            <div style={{
              display: 'flex',
              gap: '10px',
              marginBottom: '20px',
              padding: '15px',
              backgroundColor: '#f8f9fa',
              borderRadius: '6px'
            }}>
              <select
                value={filters.status}
                onChange={(e) => setFilters(prev => ({ ...prev, status: e.target.value }))}
                style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="">全部状态</option>
                <option value="pending">待处理</option>
                <option value="processing">处理中</option>
                <option value="completed">已完成</option>
                <option value="rejected">已拒绝</option>
              </select>
              
              <select
                value={filters.priority}
                onChange={(e) => setFilters(prev => ({ ...prev, priority: e.target.value }))}
                style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="">全部优先级</option>
                <option value="high">高</option>
                <option value="medium">中</option>
                <option value="low">低</option>
              </select>
            </div>

            {/* 请求列表 */}
            <div style={{ overflow: 'auto', maxHeight: '500px' }}>
              {loading ? (
                <div style={{ textAlign: 'center', padding: '20px' }}>加载中...</div>
              ) : requests.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
                  暂无客服请求
                </div>
              ) : (
                <div style={{ display: 'grid', gap: '15px' }}>
                  {requests.map(request => (
                    <div
                      key={request.id}
                      style={{
                        border: '1px solid #eee',
                        borderRadius: '6px',
                        padding: '15px',
                        backgroundColor: '#fff'
                      }}
                    >
                      <div style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'flex-start',
                        marginBottom: '10px'
                      }}>
                        <div>
                          <h4 style={{ margin: '0 0 5px 0', color: '#333' }}>{request.title}</h4>
                          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                            <span style={{ color: '#666', fontSize: '14px' }}>
                              来自: {request.requester_name} ({request.requester_id})
                            </span>
                            <span style={{
                              padding: '2px 8px',
                              borderRadius: '4px',
                              color: 'white',
                              backgroundColor: getStatusColor(request.status),
                              fontSize: '12px'
                            }}>
                              {getStatusText(request.status)}
                            </span>
                            <span style={{
                              padding: '2px 8px',
                              borderRadius: '4px',
                              color: 'white',
                              backgroundColor: getPriorityColor(request.priority),
                              fontSize: '12px'
                            }}>
                              {getPriorityText(request.priority)}
                            </span>
                            <span style={{ color: '#666', fontSize: '12px' }}>
                              {getTypeText(request.type)}
                            </span>
                          </div>
                        </div>
                        <div style={{ display: 'flex', gap: '5px' }}>
                          <button
                            onClick={() => handleViewRequest(request.id)}
                            style={{
                              padding: '4px 8px',
                              border: 'none',
                              background: '#17a2b8',
                              color: 'white',
                              borderRadius: '3px',
                              cursor: 'pointer',
                              fontSize: '12px'
                            }}
                          >
                            查看
                          </button>
                        </div>
                      </div>
                      
                      <div style={{
                        color: '#666',
                        fontSize: '14px',
                        marginBottom: '10px',
                        maxHeight: '60px',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis'
                      }}>
                        {request.description}
                      </div>
                      
                      <div style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        fontSize: '12px',
                        color: '#999'
                      }}>
                        <span>创建时间: {TimeHandlerV2.formatUtcToLocal(request.created_at, 'YYYY-MM-DD HH:mm')}</span>
                        {request.updated_at && (
                          <span>更新时间: {TimeHandlerV2.formatUtcToLocal(request.updated_at, 'YYYY-MM-DD HH:mm')}</span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* 客服交流标签页 */}
        {activeTab === 'chat' && (
          <div>
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '20px'
            }}>
              <h3 style={{ margin: 0 }}>与客服的交流记录</h3>
              <button
                onClick={() => setShowChatModal(true)}
                style={{
                  padding: '8px 16px',
                  border: 'none',
                  background: '#28a745',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer'
                }}
              >
                发送消息
              </button>
            </div>

            {/* 聊天记录 */}
            <div style={{
              height: '400px',
              overflow: 'auto',
              border: '1px solid #eee',
              borderRadius: '6px',
              padding: '15px',
              backgroundColor: '#f8f9fa'
            }}>
              {loading ? (
                <div style={{ textAlign: 'center', padding: '20px' }}>加载中...</div>
              ) : chatMessages.length === 0 ? (
                <div style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
                  暂无聊天记录
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {chatMessages.map(message => (
                    <div
                      key={message.id}
                      style={{
                        display: 'flex',
                        justifyContent: message.sender_type === 'admin' ? 'flex-end' : 'flex-start'
                      }}
                    >
                      <div style={{
                        maxWidth: '70%',
                        padding: '10px 15px',
                        borderRadius: '18px',
                        backgroundColor: message.sender_type === 'admin' ? '#007bff' : '#e9ecef',
                        color: message.sender_type === 'admin' ? 'white' : '#333'
                      }}>
                        <div style={{
                          fontSize: '12px',
                          opacity: 0.8,
                          marginBottom: '5px'
                        }}>
                          {message.sender_name || (message.sender_type === 'admin' ? '管理员' : '客服')}
                        </div>
                        <div>{message.content}</div>
                        <div style={{
                          fontSize: '11px',
                          opacity: 0.7,
                          marginTop: '5px',
                          textAlign: 'right'
                        }}>
                          {TimeHandlerV2.formatUtcToLocal(message.created_at, 'HH:mm')}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}
      </div>

      {/* 请求详情弹窗 */}
      {showRequestDetail && selectedRequest && (
        <RequestDetailModal
          request={selectedRequest}
          onClose={() => setShowRequestDetail(false)}
          onUpdate={handleUpdateRequest}
        />
      )}

      {/* 发送消息弹窗 */}
      {showChatModal && (
        <ChatModal
          onClose={() => setShowChatModal(false)}
          onSend={handleSendMessage}
          newMessage={newMessage}
          setNewMessage={setNewMessage}
        />
      )}
    </div>
  );
};

// 请求详情组件
const RequestDetailModal: React.FC<{
  request: CustomerServiceRequest;
  onClose: () => void;
  onUpdate: (requestId: number, updateData: any) => void;
}> = ({ request, onClose, onUpdate }) => {
  const [formData, setFormData] = useState({
    status: request.status,
    priority: request.priority,
    admin_response: request.admin_response || ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onUpdate(request.id, formData);
    onClose();
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1100
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '600px',
        width: '90%',
        maxHeight: '80vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0 }}>请求详情</h3>
          <button
            onClick={onClose}
            style={{
              padding: '6px 12px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
        
        <div style={{ marginBottom: '20px' }}>
          <h4 style={{ margin: '0 0 10px 0' }}>{request.title}</h4>
          <div style={{ color: '#666', marginBottom: '15px' }}>
            <p><strong>请求者:</strong> {request.requester_name} ({request.requester_id})</p>
            <p><strong>类型:</strong> {getTypeText(request.type)}</p>
            <p><strong>创建时间:</strong> {TimeHandlerV2.formatUtcToLocal(request.created_at, 'YYYY-MM-DD HH:mm:ss')}</p>
          </div>
          <div style={{
            padding: '15px',
            backgroundColor: '#f8f9fa',
            borderRadius: '6px',
            marginBottom: '15px'
          }}>
            <strong>请求描述:</strong>
            <p style={{ margin: '10px 0 0 0', whiteSpace: 'pre-wrap' }}>{request.description}</p>
          </div>
        </div>

        <form onSubmit={handleSubmit}>
          <div style={{ display: 'grid', gap: '15px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>状态:</label>
                <select
                  value={formData.status}
                  onChange={(e) => setFormData(prev => ({ ...prev, status: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="pending">待处理</option>
                  <option value="processing">处理中</option>
                  <option value="completed">已完成</option>
                  <option value="rejected">已拒绝</option>
                </select>
              </div>
              
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>优先级:</label>
                <select
                  value={formData.priority}
                  onChange={(e) => setFormData(prev => ({ ...prev, priority: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="low">低</option>
                  <option value="medium">中</option>
                  <option value="high">高</option>
                </select>
              </div>
            </div>
            
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>管理员回复:</label>
              <textarea
                value={formData.admin_response}
                onChange={(e) => setFormData(prev => ({ ...prev, admin_response: e.target.value }))}
                style={{
                  width: '100%',
                  padding: '8px',
                  border: '1px solid #ddd',
                  borderRadius: '4px',
                  minHeight: '100px',
                  resize: 'vertical'
                }}
                placeholder="请输入回复内容..."
              />
            </div>
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '10px',
            marginTop: '20px',
            paddingTop: '15px',
            borderTop: '1px solid #eee'
          }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '8px 16px',
                border: '1px solid #ddd',
                background: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              取消
            </button>
            <button
              type="submit"
              style={{
                padding: '8px 16px',
                border: 'none',
                background: '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// 聊天弹窗组件
const ChatModal: React.FC<{
  onClose: () => void;
  onSend: () => void;
  newMessage: string;
  setNewMessage: (message: string) => void;
}> = ({ onClose, onSend, newMessage, setNewMessage }) => {
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSend();
    onClose();
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1100
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '500px',
        width: '90%',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0 }}>发送消息给客服</h3>
          <button
            onClick={onClose}
            style={{
              padding: '6px 12px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
        
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>消息内容:</label>
            <textarea
              value={newMessage}
              onChange={(e) => setNewMessage(e.target.value)}
              style={{
                width: '100%',
                padding: '10px',
                border: '1px solid #ddd',
                borderRadius: '4px',
                minHeight: '120px',
                resize: 'vertical'
              }}
              placeholder="请输入要发送给客服的消息..."
              required
            />
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '10px'
          }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '8px 16px',
                border: '1px solid #ddd',
                background: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              取消
            </button>
            <button
              type="submit"
              style={{
                padding: '8px 16px',
                border: 'none',
                background: '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              发送
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// 辅助函数
const getTypeText = (type: string) => {
  switch (type) {
    case 'task_status': return '任务状态';
    case 'user_ban': return '用户封禁';
    case 'feedback': return '反馈建议';
    case 'other': return '其他';
    default: return type;
  }
};

export default CustomerServiceManagement;
