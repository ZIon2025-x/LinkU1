import React, { useEffect, useRef, useState, useCallback } from 'react';
import { API_BASE_URL, WS_BASE_URL } from '../config';
import api, { 
  fetchCurrentUser, 
  getContacts, 
  getChatHistory, 
  sendMessage, 
  markChatMessagesAsRead, 
  getContactUnreadCounts 
} from '../api';
import { useLocation, useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';
import ContactList from '../components/Message/ContactList';
import MessageList from '../components/Message/MessageList';
import MessageInput from '../components/Message/MessageInput';

// 添加时区插件
dayjs.extend(utc);
dayjs.extend(timezone);

interface Contact {
  id: string;
  name: string;
  avatar: string;
  email: string;
  user_level: number;
  task_count: number;
  avg_rating: number;
  last_message_time: string | null;
  is_verified: boolean;
}

interface Message {
  id: number;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
  is_read: number;
}

const MessageOptimized: React.FC = () => {
  // 基础状态
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [showLoginModal, setShowLoginModal] = useState(false);
  
  // 联系人相关状态
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [contactsLoading, setContactsLoading] = useState(false);
  const [activeContact, setActiveContact] = useState<Contact | null>(null);
  const [unreadCounts, setUnreadCounts] = useState<Record<string, number>>({});
  
  // 消息相关状态
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [loadingMessages, setLoadingMessages] = useState(false);
  
  // WebSocket相关状态
  const [ws, setWs] = useState<WebSocket | null>(null);
  const [wsConnected, setWsConnected] = useState(false);
  
  // 图片上传状态
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [uploadingImage, setUploadingImage] = useState(false);
  
  // 时区相关状态
  const [userTimezone, setUserTimezone] = useState<string>('');
  const [timezoneInfo, setTimezoneInfo] = useState<any>(null);
  
  // 移动端相关状态
  const [isMobile, setIsMobile] = useState(false);
  const [showContactsList, setShowContactsList] = useState(false);
  
  // 其他状态
  const [totalUnreadCount, setTotalUnreadCount] = useState(0);
  
  const navigate = useNavigate();
  const location = useLocation();

  // 检测移动端
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent));
    };
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  // 获取当前用户信息
  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
        setLoading(false);
      } catch (error) {
        console.error('Failed to load user:', error);
        setUser(null);
        setLoading(false);
        setShowLoginModal(true);
      }
    };
    loadUser();
  }, []);

  // 加载联系人列表
  const loadContacts = useCallback(async () => {
    if (!user) return;
    
    setContactsLoading(true);
    try {
      const contactsData = await getContacts();
      setContacts(contactsData);
      
      // 加载未读消息数量
      const unreadData = await getContactUnreadCounts();
      const countsMap: Record<string, number> = {};
      unreadData.forEach((item: any) => {
        countsMap[item.contact_id] = item.unread_count;
      });
      setUnreadCounts(countsMap);
      
      // 计算总未读数量
      const total = Object.values(countsMap).reduce((sum, count) => sum + count, 0);
      setTotalUnreadCount(total);
      
    } catch (error) {
      console.error('Failed to load contacts:', error);
    } finally {
      setContactsLoading(false);
    }
  }, [user]);

  // 加载聊天历史
  const loadChatHistory = useCallback(async (contactId: string) => {
    if (!user || !contactId) return;
    
    setLoadingMessages(true);
    try {
      const messagesData = await getChatHistory(contactId, 50);
      setMessages(messagesData.reverse()); // 反转顺序，最新的在底部
    } catch (error) {
      console.error('Failed to load chat history:', error);
    } finally {
      setLoadingMessages(false);
    }
  }, [user]);

  // 选择联系人
  const handleContactSelect = useCallback((contact: Contact) => {
    setActiveContact(contact);
    setShowContactsList(false);
    loadChatHistory(contact.id);
    
    // 标记消息为已读
    if (unreadCounts[contact.id] > 0) {
      markChatMessagesAsRead(contact.id);
      setUnreadCounts(prev => ({
        ...prev,
        [contact.id]: 0
      }));
    }
  }, [loadChatHistory, unreadCounts]);

  // 发送消息
  const handleSendMessage = useCallback(async (content: string) => {
    if (!user || !activeContact || !content.trim()) return;
    
    try {
      await sendMessage({
        receiver_id: activeContact.id,
        content: content.trim()
      });
      
      // 添加到本地消息列表
      const newMessage: Message = {
        id: Date.now(), // 临时ID
        sender_id: user.id,
        receiver_id: activeContact.id,
        content: content.trim(),
        created_at: new Date().toISOString(),
        is_read: 0
      };
      
      setMessages(prev => [...prev, newMessage]);
      
    } catch (error) {
      console.error('Failed to send message:', error);
    }
  }, [user, activeContact]);

  // 发送图片
  const handleSendImage = useCallback(async (imageId: string) => {
    if (!user || !activeContact) return;
    
    const messageContent = `[图片] ${imageId}`;
    await handleSendMessage(messageContent);
  }, [user, activeContact, handleSendMessage]);

  // 处理文件选择
  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      // 检查文件类型
      if (!file.type.startsWith('image/')) {
        alert('请选择图片文件');
        return;
      }
      
      // 检查文件大小 (5MB)
      if (file.size > 5 * 1024 * 1024) {
        alert('图片大小不能超过5MB');
        return;
      }
      
      setSelectedImage(file);
      
      // 创建预览
      const reader = new FileReader();
      reader.onload = (e) => {
        setImagePreview(e.target?.result as string);
      };
      reader.readAsDataURL(file);
    }
  };

  // 初始化时区信息
  const initializeTimezone = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/timezone/info`);
      if (response.ok) {
        const data = await response.json();
        setTimezoneInfo(data);
        setUserTimezone(data.user_timezone || 'Europe/London');
      }
    } catch (error) {
      console.error('Failed to load timezone info:', error);
      setUserTimezone('Europe/London');
    }
  }, []);

  // 初始化数据
  useEffect(() => {
    if (user) {
      loadContacts();
      initializeTimezone();
    }
  }, [user, loadContacts, initializeTimezone]);

  // 处理URL参数
  useEffect(() => {
    if (user && contacts.length > 0) {
      const urlParams = new URLSearchParams(location.search);
      const targetUserId = urlParams.get('uid');
      
      if (targetUserId) {
        const targetContact = contacts.find(contact => contact.id === targetUserId);
        if (targetContact) {
          handleContactSelect(targetContact);
        }
      }
    }
  }, [user, contacts, location.search, handleContactSelect]);

  // 移动端初始化
  useEffect(() => {
    if (isMobile && !activeContact) {
      const urlParams = new URLSearchParams(location.search);
      const targetUserId = urlParams.get('uid');
      
      if (!targetUserId) {
        setShowContactsList(true);
      }
    }
  }, [isMobile, activeContact, location.search]);

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100vh',
        background: '#f9fafb'
      }}>
        <div style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '16px'
        }}>
          <div style={{
            width: '40px',
            height: '40px',
            border: '4px solid #e5e7eb',
            borderTop: '4px solid #3b82f6',
            borderRadius: '50%',
            animation: 'spin 1s linear infinite'
          }} />
          <div style={{ color: '#6b7280' }}>加载中...</div>
        </div>
      </div>
    );
  }

  if (!user) {
    return (
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onLoginSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
      />
    );
  }

  return (
    <div style={{
      display: 'flex',
      height: '100vh',
      background: '#f9fafb'
    }}>
      {/* 联系人列表 */}
      {(showContactsList || !isMobile) && (
        <ContactList
          contacts={contacts}
          activeContact={activeContact}
          onContactSelect={handleContactSelect}
          unreadCounts={unreadCounts}
          loading={contactsLoading}
        />
      )}

      {/* 聊天区域 */}
      <div style={{
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        background: 'white'
      }}>
        {activeContact ? (
          <>
            {/* 聊天头部 */}
            <div style={{
              padding: '16px',
              borderBottom: '1px solid #e5e7eb',
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              background: 'white'
            }}>
              {isMobile && (
                <button
                  onClick={() => setShowContactsList(true)}
                  style={{
                    padding: '8px',
                    border: 'none',
                    background: 'transparent',
                    cursor: 'pointer',
                    borderRadius: '6px',
                    color: '#6b7280'
                  }}
                >
                  ←
                </button>
              )}
              
              <img
                src={activeContact.avatar}
                alt={activeContact.name}
                style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '50%',
                  objectFit: 'cover'
                }}
              />
              
              <div style={{ flex: 1 }}>
                <div style={{
                  fontWeight: '500',
                  color: '#1f2937',
                  fontSize: '16px'
                }}>
                  {activeContact.name}
                </div>
                <div style={{
                  fontSize: '12px',
                  color: '#6b7280'
                }}>
                  {activeContact.task_count} 个任务 • {activeContact.avg_rating.toFixed(1)}⭐
                </div>
              </div>
            </div>

            {/* 消息列表 */}
            <MessageList
              messages={messages}
              currentUserId={user.id}
              userTimezone={userTimezone}
              timezoneInfo={timezoneInfo}
              isServiceMode={false}
              currentChat={null}
            />

            {/* 消息输入 */}
            <MessageInput
              input={input}
              setInput={setInput}
              onSendMessage={handleSendMessage}
              onSendImage={handleSendImage}
              uploadingImage={uploadingImage}
              disabled={loadingMessages}
            />
          </>
        ) : (
          <div style={{
            flex: 1,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#6b7280',
            fontSize: '18px'
          }}>
            选择一个联系人开始聊天
          </div>
        )}
      </div>

      {/* 图片预览模态框 */}
      {imagePreview && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.8)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            position: 'relative',
            maxWidth: '90%',
            maxHeight: '90%'
          }}>
            <img
              src={imagePreview}
              alt="预览"
              style={{
                maxWidth: '100%',
                maxHeight: '100%',
                borderRadius: '8px'
              }}
            />
            <div style={{
              position: 'absolute',
              top: '16px',
              right: '16px',
              display: 'flex',
              gap: '8px'
            }}>
              <button
                onClick={() => {
                  setImagePreview(null);
                  setSelectedImage(null);
                }}
                style={{
                  padding: '8px',
                  background: 'rgba(0, 0, 0, 0.5)',
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: 'pointer'
                }}
              >
                取消
              </button>
              <button
                onClick={handleSendImage}
                disabled={uploadingImage}
                style={{
                  padding: '8px 16px',
                  background: uploadingImage ? '#9ca3af' : '#3b82f6',
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  cursor: uploadingImage ? 'not-allowed' : 'pointer'
                }}
              >
                {uploadingImage ? '发送中...' : '发送'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 隐藏的文件输入 */}
      <input
        type="file"
        accept="image/*"
        onChange={handleFileSelect}
        style={{ display: 'none' }}
      />
    </div>
  );
};

export default MessageOptimized;
