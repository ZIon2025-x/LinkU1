import React, { useEffect, useRef, useState, useCallback } from 'react';
import { API_BASE_URL, WS_BASE_URL, API_ENDPOINTS } from '../config';
import { fetchCurrentUser, getContacts, getChatHistory, assignCustomerService, sendMessage, checkCustomerServiceAvailability } from '../api';
import { useLocation, useNavigate } from 'react-router-dom';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';

// 移动端检测函数
const isMobileDevice = () => {
  return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
};

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

// 时区检测和转换工具函数
const getUserTimezone = () => {
  return Intl.DateTimeFormat().resolvedOptions().timeZone;
};

const formatTimeWithUserTimezone = (time: string | Date, serverTimezone: string = 'Europe/London') => {
  const userTimezone = getUserTimezone();
  return dayjs(time).tz(serverTimezone).tz(userTimezone).format('YYYY/MM/DD HH:mm:ss');
};

const getTimezoneInfo = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/api/users/timezone/info`);
    return await response.json();
  } catch (error) {
    console.error('获取时区信息失败:', error);
    return null;
  }
};

interface Message {
  id?: number;
  from: string;
  content: string;
  created_at: string;
}

interface Contact {
  id: string;
  name: string;
  avatar: string;
  unreadCount?: number;
  is_verified?: boolean;
  last_message_time?: string | null;
  email?: string;
  user_level?: number;
  task_count?: number;
  avg_rating?: number;
}


interface CustomerServiceChat {
  chat_id: string;
  user_id: string;
  service_id: string;
  is_ended: number;
  created_at: string;
  ended_at?: string;
  last_message_at: string;
  total_messages: number;
  user_rating?: number;
  user_comment?: string;
  rated_at?: string;
}

const MessagePage: React.FC = () => {
  // 添加CSS动画样式
  React.useEffect(() => {
    const style = document.createElement('style');
    style.textContent = `
      @keyframes pulse {
        0%, 100% { opacity: 1; }
        50% { opacity: 0.5; }
      }
    `;
    document.head.appendChild(style);
    return () => {
      if (document.head.contains(style)) {
        document.head.removeChild(style);
      }
    };
  }, []);
  const [user, setUser] = useState<any>(null);
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [contactsLoading, setContactsLoading] = useState<boolean>(false);
  const [activeContact, setActiveContact] = useState<Contact | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [ws, setWs] = useState<WebSocket | null>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [isServiceMode, setIsServiceMode] = useState(false);
  const [currentChat, setCurrentChat] = useState<CustomerServiceChat | null>(null);
  const [rating, setRating] = useState(5);
  const [ratingComment, setRatingComment] = useState('');
  const [timezoneInfo, setTimezoneInfo] = useState<any>(null);
  const [userTimezone, setUserTimezone] = useState<string>('');
  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const [loading, setLoading] = useState(true);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [isConnectingToService, setIsConnectingToService] = useState(false);
  const [serviceConnected, setServiceConnected] = useState(false);
  const [showSystemWarning, setShowSystemWarning] = useState(true);
  const [currentChatId, setCurrentChatId] = useState<string | null>(null);
  const [showRatingModal, setShowRatingModal] = useState(false);
  const [ratingChatId, setRatingChatId] = useState<string | null>(null);
  const [serviceAvailable, setServiceAvailable] = useState<boolean>(false);
  const [serviceStatusLoading, setServiceStatusLoading] = useState<boolean>(true);
  const [isMobile, setIsMobile] = useState(false);
  const [showContactsList, setShowContactsList] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);

  const location = useLocation();
  const navigate = useNavigate();

  // 格式化时间为英国时间
  const formatTime = (timeString: string) => {
    try {
      // 始终显示英国时间
      return dayjs(timeString).tz('Europe/London').format('YYYY/MM/DD HH:mm:ss') + ' (英国时间)';
    } catch (error) {
      console.error('时间格式化错误:', error);
      return timeString;
    }
  };


  // 表情列表
  const emojis = ['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'];

  // 添加表情到输入框
  const addEmoji = (emoji: string) => {
    setInput(prev => prev + emoji);
    setShowEmojiPicker(false);
  };

  // 处理图片选择
  const handleImageSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // 检查文件大小（限制为5MB）
      if (file.size > 5 * 1024 * 1024) {
        alert('图片大小不能超过5MB');
        return;
      }
      
      // 检查文件类型
      if (!file.type.startsWith('image/')) {
        alert('请选择图片文件');
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

  // 发送图片
  const sendImage = async () => {
    if (!selectedImage) return;
    
    setUploadingImage(true);
    
    try {
      const formData = new FormData();
      formData.append('image', selectedImage);
      
      console.log('开始上传图片:', selectedImage.name, '大小:', selectedImage.size);
      
      // 上传图片到服务器
      const uploadResponse = await fetch(`${API_BASE_URL}/api/upload/image`, {
        method: 'POST',
        credentials: 'include',  // 使用Cookie认证
        body: formData
      });
      
      console.log('上传响应状态:', uploadResponse.status);
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
        console.error('上传失败响应:', errorText);
        throw new Error(`图片上传失败: ${uploadResponse.status} - ${errorText}`);
      }
      
      const uploadResult = await uploadResponse.json();
      console.log('上传成功结果:', uploadResult);
      
      if (!uploadResult.url) {
        throw new Error('服务器未返回图片URL');
      }
      
      const imageUrl = uploadResult.url;
      
      // 发送包含图片URL的消息
      const messageContent = `[图片] ${imageUrl}`;
      
      if (ws && ws.readyState === WebSocket.OPEN) {
        if (isServiceMode && currentChat) {
          const messageData = {
            receiver_id: currentChat.service_id,
            content: messageContent,
            chat_id: currentChat.chat_id
          };
          ws.send(JSON.stringify(messageData));
        } else if (activeContact) {
          const messageData = {
            receiver_id: activeContact.id,
            content: messageContent
          };
          ws.send(JSON.stringify(messageData));
        }
        
        // 立即添加消息到本地状态
        const newMessage = {
          id: Date.now(),
          from: '我',
          content: messageContent,
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, newMessage]);
        
        // 更新联系人排序
        if (activeContact && !isServiceMode) {
          updateContactOrder(activeContact.id);
        }
      } else {
        // WebSocket未连接，使用HTTP API
        if (isServiceMode && currentChat) {
          const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${currentChat.chat_id}/send-message`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            credentials: 'include',  // 使用Cookie认证
            body: JSON.stringify({ content: messageContent })
          });
          
          if (!response.ok) {
            throw new Error('发送消息失败');
          }
          
          const newMessage = {
            id: Date.now(),
            from: '我',
            content: messageContent,
            created_at: new Date().toISOString()
          };
          setMessages(prev => [...prev, newMessage]);
        } else if (activeContact) {
          const response = await sendMessage({
            receiver_id: activeContact.id,
            content: messageContent
          });
          
          const newMessage = {
            id: response.id,
            from: '我',
            content: messageContent,
            created_at: response.created_at
          };
          setMessages(prev => [...prev, newMessage]);
          
          if (activeContact) {
            updateContactOrder(activeContact.id);
          }
        }
      }
      
      // 清除图片选择
      setSelectedImage(null);
      setImagePreview(null);
      
    } catch (error) {
      console.error('发送图片失败:', error);
      
      // 如果上传失败，尝试使用base64编码直接发送
      try {
        console.log('尝试使用base64编码发送图片...');
        const reader = new FileReader();
        reader.onload = async (e) => {
          const base64Data = e.target?.result as string;
          const messageContent = `[图片] ${base64Data}`;
          
          console.log('使用base64发送图片消息:', messageContent.substring(0, 100) + '...');
          
          if (ws && ws.readyState === WebSocket.OPEN) {
            if (isServiceMode && currentChat) {
              const messageData = {
                receiver_id: currentChat.service_id,
                content: messageContent,
                chat_id: currentChat.chat_id
              };
              ws.send(JSON.stringify(messageData));
            } else if (activeContact) {
              const messageData = {
                receiver_id: activeContact.id,
                content: messageContent
              };
              ws.send(JSON.stringify(messageData));
            }
            
            // 立即添加消息到本地状态
            const newMessage = {
              id: Date.now(),
              from: '我',
              content: messageContent,
              created_at: new Date().toISOString()
            };
            setMessages(prev => [...prev, newMessage]);
            
            // 更新联系人排序
            if (activeContact && !isServiceMode) {
              updateContactOrder(activeContact.id);
            }
            
            // 清除图片选择
            setSelectedImage(null);
            setImagePreview(null);
            console.log('base64图片发送成功');
          } else {
            throw new Error('WebSocket未连接');
          }
        };
        reader.readAsDataURL(selectedImage);
      } catch (base64Error) {
        console.error('base64发送也失败:', base64Error);
        alert(`发送图片失败: ${error instanceof Error ? error.message : String(error)}\n\n可能的原因:\n1. 网络连接问题\n2. 图片文件过大\n3. 服务器上传功能未启用\n\n请检查网络连接或尝试发送较小的图片。`);
      }
    } finally {
      setUploadingImage(false);
    }
  };

  // 取消图片选择
  const cancelImageSelection = () => {
    setSelectedImage(null);
    setImagePreview(null);
  };

  // 渲染消息内容（支持图片）
  const renderMessageContent = (content: string) => {
    // 检查是否是图片消息
    if (content.startsWith('[图片] ')) {
      const imageData = content.replace('[图片] ', '');
      
      // 判断是URL还是base64数据
      const isBase64 = imageData.startsWith('data:image/');
      const imageUrl = isBase64 ? imageData : imageData;
      
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <div style={{ fontSize: '14px', opacity: 0.8 }}>
            📷 图片 {isBase64 ? '(内嵌)' : '(链接)'}
          </div>
          <img
            src={imageUrl}
            alt="发送的图片"
            style={{
              maxWidth: '200px',
              maxHeight: '200px',
              borderRadius: '8px',
              objectFit: 'cover',
              cursor: 'pointer'
            }}
            onClick={() => {
              if (isBase64) {
                // 对于base64图片，创建新窗口显示
                const newWindow = window.open();
                if (newWindow) {
                  newWindow.document.write(`
                    <html>
                      <head><title>图片预览</title></head>
                      <body style="margin:0; padding:20px; text-align:center; background:#f5f5f5;">
                        <img src="${imageUrl}" style="max-width:100%; max-height:100%; border-radius:8px; box-shadow:0 4px 12px rgba(0,0,0,0.1);" />
                      </body>
                    </html>
                  `);
                }
              } else {
                // 对于URL图片，直接打开
                window.open(imageUrl, '_blank');
              }
            }}
            onError={(e) => {
              console.error('图片加载失败:', imageData.substring(0, 50) + '...');
              e.currentTarget.style.display = 'none';
              e.currentTarget.parentElement!.innerHTML = `
                <div style="padding: 20px; text-align: center; color: #6b7280; background: #f3f4f6; border-radius: 8px;">
                  📷 图片加载失败
                  <div style="font-size: 12px; margin-top: 4px;">请检查网络连接</div>
                </div>
              `;
            }}
          />
        </div>
      );
    }
    
    // 普通文本消息
    return <div style={{ fontSize: 16 }}>{content}</div>;
  };

  // 发送消息
  const handleSend = async () => {
    console.log('handleSend 被调用');
    console.log('input:', input);
    console.log('isServiceMode:', isServiceMode);
    console.log('currentChat:', currentChat);
    console.log('activeContact:', activeContact);
    console.log('ws:', ws);
    console.log('ws.readyState:', ws ? ws.readyState : 'null');
    
    if (!input.trim()) {
      console.log('输入内容为空，返回');
      return;
    }
    
    const messageContent = input.trim();
    setInput('');
    
    try {
      if (ws && ws.readyState === WebSocket.OPEN) {
        if (isServiceMode && currentChat) {
          // 客服模式发送消息
          const messageData = {
            receiver_id: currentChat.service_id,
            content: messageContent,
            chat_id: currentChat.chat_id
          };
          console.log('用户发送客服消息:', messageData);
          ws.send(JSON.stringify(messageData));
        } else if (activeContact) {
          // 普通聊天模式发送消息
          const messageData = {
            receiver_id: activeContact.id,
            content: messageContent
          };
          console.log('用户发送普通消息:', messageData);
          ws.send(JSON.stringify(messageData));
        }
        
        // 立即添加消息到本地状态以提供即时反馈
        const newMessage = {
          id: Date.now(), // 临时ID
          from: '我',
          content: messageContent,
          created_at: new Date().toISOString(),
          is_admin_msg: 0
        };
        console.log('发送消息前，当前消息数量:', messages.length);
        setMessages(prev => {
          const newMessages = [...prev, newMessage];
          console.log('发送消息后，新消息数量:', newMessages.length);
          return newMessages;
        });
        
        // 更新联系人排序（如果是普通聊天模式）
        if (activeContact && !isServiceMode) {
          updateContactOrder(activeContact.id);
        }
        
        console.log('消息发送成功，已添加到本地状态');
      } else {
        console.log('WebSocket未连接，状态:', ws ? ws.readyState : 'null');
        // WebSocket未连接，使用HTTP API作为备用
        if (isServiceMode && currentChat) {
          const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${currentChat.chat_id}/send-message`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json'
            },
            credentials: 'include',  // 使用Cookie认证
            body: JSON.stringify({ content: messageContent })
          });
          
          if (!response.ok) {
            throw new Error('发送消息失败');
          }
          
          // 立即添加消息到本地状态
          const newMessage = {
            id: Date.now(), // 临时ID
            from: '我',
            content: messageContent,
            created_at: new Date().toISOString(),
            is_admin_msg: 0
          };
          setMessages(prev => [...prev, newMessage]);
          console.log('客服消息发送成功，已添加到本地状态');
        } else if (activeContact) {
          const response = await sendMessage({
            receiver_id: activeContact.id,
            content: messageContent
          });
          
          // 使用服务器返回的消息数据，避免重复
          if (response) {
            const newMessage = {
              id: response.id,
              from: '我',
              content: response.content,
              created_at: response.created_at,
              is_admin_msg: 0
            };
            setMessages(prev => [...prev, newMessage]);
            
            // 更新联系人排序（如果是普通聊天模式）
            if (activeContact && !isServiceMode) {
              updateContactOrder(activeContact.id);
            }
            
            console.log('普通消息发送成功，已添加到本地状态');
          }
        }
      }
      
    } catch (error) {
      console.error('发送消息失败:', error);
      alert('发送消息失败，请重试');
      setInput(messageContent); // 恢复输入内容
    }
  };

  // 检测移动端设备
  useEffect(() => {
    const checkMobile = () => {
      setIsMobile(isMobileDevice());
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
  }, [navigate]);

  // 加载联系人列表
  useEffect(() => {
    if (user) {
      loadContacts();
      restoreCustomerServiceChat();
      initializeTimezone();
      checkServiceAvailability(); // 检查客服在线状态
    }
  }, [user]);

  // 当URL参数变化时，强制重新加载联系人列表
  useEffect(() => {
    if (user && location.search.includes('uid=')) {
      console.log('检测到URL参数变化，重新加载联系人列表');
      loadContacts();
    }
  }, [location.search, user]);

  // 处理URL参数，自动选择指定的联系人
  useEffect(() => {
    console.log('URL参数处理useEffect触发:', { user: !!user, contactsLength: contacts.length, locationSearch: location.search });
    if (user) {
      const urlParams = new URLSearchParams(location.search);
      const targetUserId = urlParams.get('uid');
      
      if (targetUserId) {
        console.log('从URL参数获取目标用户ID:', targetUserId);
        
        // 首先尝试在现有联系人中查找
        const targetContact = contacts.find(contact => contact.id === targetUserId);
        if (targetContact) {
          console.log('在现有联系人中找到目标联系人:', targetContact);
          setActiveContact(targetContact);
          setIsServiceMode(false);
          setMessages([]); // 清空消息列表，准备加载新的聊天历史
        } else {
          console.log('未在现有联系人中找到，创建临时联系人信息');
          // 如果不在现有联系人中，创建一个临时的联系人信息
          const tempContact: Contact = {
            id: targetUserId,
            name: `用户${targetUserId}`,
            avatar: "/static/avatar1.png",
            email: "",
            user_level: 1, // 1 = normal, 2 = vip, 3 = super
            task_count: 0,
            avg_rating: 0.0,
            last_message_time: null,
            is_verified: false
          };
          
          console.log('创建临时联系人:', tempContact);
          setActiveContact(tempContact);
          setIsServiceMode(false);
          setMessages([]); // 清空消息列表，准备加载新的聊天历史
        }
      }
    }
  }, [user, contacts, location.search]);

  // 定期检查客服在线状态（每30秒检查一次）
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      checkServiceAvailability();
    }, 30000); // 30秒检查一次

    return () => clearInterval(interval);
  }, [user]);

  // 初始化时区信息
  const initializeTimezone = useCallback(async () => {
    try {
      const detectedTimezone = getUserTimezone();
      setUserTimezone(detectedTimezone);
      
      const serverTimezoneInfo = await getTimezoneInfo();
      if (serverTimezoneInfo) {
        setTimezoneInfo(serverTimezoneInfo);
        console.log('时区信息已加载:', {
          userTimezone: detectedTimezone,
          serverTimezone: serverTimezoneInfo.server_timezone,
          serverTime: serverTimezoneInfo.server_time,
          isDST: serverTimezoneInfo.is_dst
        });
      }
    } catch (error) {
      console.error('初始化时区信息失败:', error);
    }
  }, []);

  // 恢复客服聊天状态
  const restoreCustomerServiceChat = useCallback(async () => {
    try {
      const savedChat = localStorage.getItem('currentCustomerServiceChat');
      if (savedChat) {
        const chatData = JSON.parse(savedChat);
        console.log('发现已保存的客服对话:', chatData);
        
        // 检查对话是否已结束
        if (chatData.chat && chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          console.log('验证对话是否仍然有效...');
          try {
            const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatData.chat.chat_id}/messages`, {
              headers: {
    credentials: 'include'  // 使用Cookie认证
              }
            });
            
            if (response.ok) {
              // 对话仍然有效，恢复现有对话
              console.log('对话仍然有效，恢复现有客服对话');
              setIsServiceMode(true);
              setServiceConnected(true);
              setCurrentChatId(chatData.chat.chat_id);
              setCurrentChat(chatData.chat);
              // setService(chatData.service); // 已移除service状态
              
              // 加载该对话的聊天历史记录
              await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
            } else {
              // 对话无效，清除localStorage并重置状态
              console.log('对话无效，清除localStorage并重置状态');
              localStorage.removeItem('currentCustomerServiceChat');
              setServiceConnected(false);
              setCurrentChatId(null);
              setCurrentChat(null);
              // setService(null); // 已移除service状态
            }
          } catch (error) {
            console.error('验证对话有效性失败:', error);
            // 验证失败，清除localStorage并重置状态
            localStorage.removeItem('currentCustomerServiceChat');
            setServiceConnected(false);
            setCurrentChatId(null);
            setCurrentChat(null);
            // setService(null); // 已移除service状态
          }
        } else {
          // 对话已结束，清除localStorage并重置状态
          console.log('保存的对话已结束，清除localStorage并重置状态');
          localStorage.removeItem('currentCustomerServiceChat');
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
          // setService(null); // 已移除service状态
        }
      }
    } catch (error) {
      console.error('恢复客服对话失败:', error);
      localStorage.removeItem('currentCustomerServiceChat');
      setServiceConnected(false);
      setCurrentChatId(null);
      setCurrentChat(null);
      // setService(null); // 已移除service状态
    }
  }, []);

  const loadContacts = async () => {
    try {
      console.log('开始加载联系人列表...');
      setContactsLoading(true);
      const contactsData = await getContacts();
      console.log('联系人API响应:', contactsData);
      setContacts(contactsData || []);
      console.log('联系人列表已更新，数量:', (contactsData || []).length);
    } catch (error: any) {
      console.error('加载联系人失败:', error);
      console.error('错误详情:', error.response?.data || error.message);
      // API调用失败时显示空列表，但不影响URL参数处理
      setContacts([]);
    } finally {
      setContactsLoading(false);
    }
  };

  // 更新联系人排序（当有新消息时）
  const updateContactOrder = (contactId: string) => {
    setContacts(prevContacts => {
      const contactIndex = prevContacts.findIndex(c => c.id === contactId);
      if (contactIndex === -1) return prevContacts;
      
      // 将联系人移到列表顶部
      const updatedContacts = [...prevContacts];
      const [contact] = updatedContacts.splice(contactIndex, 1);
      contact.last_message_time = new Date().toISOString();
      updatedContacts.unshift(contact);
      
      return updatedContacts;
    });
  };

  // 页面加载时检查localStorage但不自动恢复客服会话
  useEffect(() => {
    const checkCustomerServiceChat = async () => {
      try {
        const savedChat = localStorage.getItem('currentCustomerServiceChat');
        console.log('页面加载时检查localStorage:', savedChat);
        if (savedChat && user) {
          const chatData = JSON.parse(savedChat);
          console.log('发现保存的客服对话:', chatData);
          
          // 检查对话是否已结束
          if (chatData.chat.is_ended === 1) {
            console.log('对话已结束，清除localStorage');
            localStorage.removeItem('currentCustomerServiceChat');
            return;
          }
          
          // 只保存数据，不自动切换到客服模式
          // 用户需要主动点击"联系在线客服"才会恢复会话
          console.log('客服对话数据已准备，等待用户主动连接');
        }
      } catch (error) {
        console.error('检查客服对话失败:', error);
        // 清除可能损坏的localStorage数据
        localStorage.removeItem('currentCustomerServiceChat');
      }
    };
    
    if (user) {
      checkCustomerServiceChat();
    }
  }, [user]);

  // 选择联系人时加载聊天历史
  useEffect(() => {
    if (activeContact && user) {
      // 如果选择了联系人，切换到普通聊天模式
      if (!isServiceMode || serviceConnected) {
        console.log('切换到普通聊天模式，加载聊天记录');
        setIsServiceMode(false);
        setServiceConnected(false);
        setCurrentChatId(null);
        setCurrentChat(null);
        // setService(null); // 已移除service状态
      }
      
      // 加载聊天记录
      loadChatHistory(activeContact.id);
      // 切换到新联系人时重新显示系统提示
      setShowSystemWarning(true);
    }
  }, [activeContact, user, isServiceMode, serviceConnected]);

  // 自动滚动到底部
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages]);

  // 点击外部区域和ESC键关闭表情框
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (showEmojiPicker) {
        const target = event.target as HTMLElement;
        // 检查点击的元素是否在表情框内部
        const emojiPicker = document.querySelector('[data-emoji-picker]');
        const emojiButton = document.querySelector('[data-emoji-button]');
        
        if (emojiPicker && !emojiPicker.contains(target) && 
            emojiButton && !emojiButton.contains(target)) {
          setShowEmojiPicker(false);
        }
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (showEmojiPicker && event.key === 'Escape') {
        setShowEmojiPicker(false);
      }
    };

    if (showEmojiPicker) {
      document.addEventListener('mousedown', handleClickOutside);
      document.addEventListener('keydown', handleKeyDown);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [showEmojiPicker]);

  // WebSocket连接 - 实时接收消息
  useEffect(() => {
    if (user) {
      let socket: WebSocket | null = null;
      let reconnectAttempts = 0;
      const maxReconnectAttempts = 5;
      const reconnectDelay = 3000; // 3秒

      const connectWebSocket = () => {
        // 使用Cookie认证，无需在URL中传递token
        const wsUrl = `${WS_BASE_URL}/ws/chat/${user.id}`;
        socket = new WebSocket(wsUrl);
        
        socket.onopen = () => {
          console.log('用户WebSocket连接已建立');
          setWs(socket);
          reconnectAttempts = 0; // 重置重连次数
        };
        
        socket.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);
            
            if (msg.error) {
              return;
            }
            
            // 处理心跳消息
            if (msg.type === 'heartbeat') {
              console.log('收到心跳消息:', msg.timestamp);
              return;
            }
            
            // 处理接收到的消息
            if (msg.type === 'message_sent') {
              // 这是发送确认消息，不需要显示，只记录日志
              console.log('收到发送确认消息:', msg);
              return;
            }
            
            if (msg.from) {
              // 确定消息发送者显示名称
              let fromName = '对方';
              if (msg.from === user.id) {
                fromName = '我';
              } else if (msg.sender_type === 'system') {
                fromName = '系统';
              } else if (msg.sender_type === 'customer_service') {
                fromName = '客服';
              } else if (msg.sender_type === 'admin') {
                fromName = '管理员';
              } else if (msg.from === 'system') {
                fromName = '系统';
              }
              
              // 只处理有内容的消息
              if (msg.content && msg.content.trim()) {
                const messageId = msg.message_id || Date.now();
                
                // 检查是否已经存在相同的消息（避免重复显示）
                setMessages(prev => {
                  console.log('WebSocket收到消息，当前消息数量:', prev.length);
                  console.log('收到消息内容:', msg.content, 'from:', fromName);
                  
                  // 检查是否已经存在相同内容、相同发送者、时间相近的消息
                  const exists = prev.some(m => 
                    m.content === msg.content.trim() && 
                    m.from === fromName && 
                    Math.abs(new Date(m.created_at).getTime() - new Date(msg.created_at).getTime()) < 2000 // 2秒内的消息认为是重复的
                  );
                  
                  if (exists) {
                    console.log('检测到重复消息，跳过添加:', msg.content);
                    return prev; // 如果已存在，不添加
                  }
                  
                  console.log('添加新消息:', msg.content, 'from:', fromName);
                  const newMessages = [...prev, {
                    id: messageId,
                    from: fromName,
                    content: msg.content.trim(), 
                    created_at: msg.created_at 
                  }];
                  console.log('添加消息后，新消息数量:', newMessages.length);
                  return newMessages;
                });
                
                // 如果是接收到的消息（不是自己发送的），更新联系人排序
                if (msg.from !== user.id && msg.from !== 'system' && msg.from !== 'customer_service' && msg.from !== 'admin') {
                  updateContactOrder(msg.from);
                }
              }
            }
          } catch (error) {
            // 静默处理解析错误
          }
        };
        
        socket.onerror = (error) => {
          console.error('用户WebSocket连接错误:', error);
        };
        
        socket.onclose = (event) => {
          console.log('用户WebSocket连接已关闭', event.code, event.reason);
          setWs(null);
          
          // 只在异常关闭时重连（代码1000是正常关闭）
          if (event.code !== 1000 && reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            console.log(`用户WebSocket异常关闭，尝试重连 (${reconnectAttempts}/${maxReconnectAttempts})`);
            setTimeout(() => {
              connectWebSocket();
            }, reconnectDelay);
          } else if (event.code === 1000) {
            console.log('用户WebSocket正常关闭，不重连');
          } else {
            console.error('用户WebSocket重连失败，已达到最大重连次数');
          }
        };
      };

      // 初始连接
      connectWebSocket();
      
      return () => {
        if (socket) {
          socket.close();
        }
        setWs(null);
      };
    }
  }, [user?.id]);

  const loadChatHistory = useCallback(async (contactId: string, chatId?: string) => {
    try {
      console.log('加载聊天历史:', { contactId, chatId, isServiceMode, serviceConnected });
      
      // 如果有chatId，加载特定对话的聊天记录（客服聊天）
      if (chatId) {
        console.log('使用客服对话API加载消息');
        const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatId}/messages`, {
          credentials: 'include'  // 使用Cookie认证
        });
        
        if (response.ok) {
          const chatData = await response.json();
          console.log('客服对话聊天记录:', chatData);
          const formattedMessages = chatData.map((msg: any) => {
            console.log('格式化消息:', {
              msg_sender_type: msg.sender_type,
              user_id: user.id,
              is_me: msg.sender_type === 'user',
              is_system: msg.sender_type === 'system'
            });
            return {
              id: msg.id,
              from: msg.sender_type === 'user' ? '我' : (msg.sender_type === 'system' ? '系统' : '客服'),
              content: msg.content,
              created_at: msg.created_at,
              is_admin_msg: msg.sender_type === 'system' ? 1 : 0
            };
          });
          
          // 按时间排序（最新的在最后）
          formattedMessages.sort((a: any, b: any) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
          setMessages(formattedMessages);
          return;
        }
      }
      
      // 只有在没有chatId且非客服模式下才加载普通用户之间的聊天记录
      if (!chatId && !isServiceMode && !serviceConnected) {
        console.log('使用普通聊天API加载消息');
        // 显示加载状态
        setMessages([{
          id: -1, // 使用负数ID表示加载状态
          from: '系统',
          content: '正在加载历史消息...',
          created_at: new Date().toISOString()
        }]);
        
        const chatData = await getChatHistory(contactId, 20); // 增加加载数量
        const formattedMessages = chatData.map((msg: any) => ({
          id: msg.id,
          from: String(msg.sender_id) === String(user.id) ? '我' : (msg.is_admin_msg === 1 ? '系统' : '对方'),
          content: msg.content, 
          created_at: msg.created_at 
        }));
        
        // 按时间排序（最新的在最后）
        formattedMessages.sort((a: any, b: any) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
        console.log('loadChatHistory: 设置消息列表，消息数量:', formattedMessages.length);
        setMessages(formattedMessages);
      }
    } catch (error) {
      console.error('加载聊天历史失败:', error);
      // API调用失败时显示空消息列表
      setMessages([]);
    }
  }, [isServiceMode, serviceConnected, user]);

  // 联系在线客服
  const handleContactCustomerService = async () => {
    // 首先检查客服是否在线
    if (!serviceAvailable) {
      console.log('客服不在线，无法连接');
      const noServiceMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '当前无可用客服，请您稍后尝试。客服时间为每日8:00-18:00，如有紧急情况请发送邮件至客服邮箱。',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, noServiceMessage]);
      return;
    }

    // 先检查localStorage中是否已有活跃的客服对话
    const savedChat = localStorage.getItem('currentCustomerServiceChat');
    console.log('联系在线客服时检查localStorage:', savedChat);
    
    if (savedChat) {
      try {
        const chatData = JSON.parse(savedChat);
        console.log('发现已保存的客服对话:', chatData);
        
        // 检查对话是否已结束
        if (chatData.chat.is_ended === 0) {
          // 对话未结束，验证对话是否仍然有效
          console.log('验证对话是否仍然有效...');
          try {
            const response = await fetch(`${API_BASE_URL}/api/users/customer-service/chat/${chatData.chat.chat_id}/messages`, {
              headers: {
    credentials: 'include'  // 使用Cookie认证
              }
            });
            
            if (response.ok) {
              // 对话仍然有效，恢复现有对话
              console.log('对话仍然有效，恢复现有客服对话');
              setIsConnectingToService(true);
              setIsServiceMode(true);
              setActiveContact(null);
              setServiceConnected(true);
              setCurrentChatId(chatData.chat.chat_id);
              setCurrentChat(chatData.chat);
              // setService(chatData.service); // 已移除service状态
              
              // 加载该对话的聊天历史记录
              await loadChatHistory(chatData.service.id, chatData.chat.chat_id);
              setIsConnectingToService(false);
              return; // 直接返回，不创建新对话
            } else {
              // 对话无效，清除localStorage并重置状态
              console.log('对话无效，清除localStorage并重置状态');
              localStorage.removeItem('currentCustomerServiceChat');
              setServiceConnected(false);
              setCurrentChatId(null);
              setCurrentChat(null);
              // setService(null); // 已移除service状态
            }
          } catch (error) {
            console.error('验证对话有效性失败:', error);
            // 验证失败，清除localStorage并重置状态
            localStorage.removeItem('currentCustomerServiceChat');
            setServiceConnected(false);
            setCurrentChatId(null);
            setCurrentChat(null);
            // setService(null); // 已移除service状态
          }
        } else {
          // 对话已结束，清除localStorage并重置状态
          console.log('保存的对话已结束，清除localStorage并重置状态');
          localStorage.removeItem('currentCustomerServiceChat');
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
          // setService(null); // 已移除service状态
        }
      } catch (error) {
        console.error('解析保存的对话失败:', error);
        localStorage.removeItem('currentCustomerServiceChat');
        setServiceConnected(false);
        setCurrentChatId(null);
        setCurrentChat(null);
        // setService(null); // 已移除service状态
      }
    }
    
    // 如果没有未结束的对话，尝试连接客服
    console.log('没有未结束的客服对话，尝试连接客服');
    setIsConnectingToService(true);
    
    try {
      // 检查客服在线状态
      console.log('检查客服在线状态...');
      const isServiceAvailable = await checkCustomerServiceAvailabilityLocal();
      console.log('客服在线状态:', isServiceAvailable);
      
      if (isServiceAvailable) {
        // 客服在线，尝试分配客服
        console.log('客服在线，尝试分配客服...');
        const response = await assignCustomerService();
        console.log('客服分配响应:', response);
        
        if (response.error) {
          console.error('客服连接失败:', response.error);
          const errorMessage: Message = {
            id: Date.now(),
            from: '系统',
            content: `连接客服失败: ${response.error}`,
            created_at: new Date().toISOString()
          };
          setMessages(prev => [...prev, errorMessage]);
          return;
        }
        
        // 连接成功
        console.log('客服连接成功，响应:', response);
        setServiceConnected(true);
        setCurrentChatId(response.chat.chat_id);
        setCurrentChat(response.chat);
        // setService(response.service); // 已移除service状态
        
        // 保存对话信息到localStorage
        const chatToSave = {
          chat: response.chat,
          service: response.service,
          chatId: response.chat.chat_id
        };
        localStorage.setItem('currentCustomerServiceChat', JSON.stringify(chatToSave));
        
        // 加载该对话的聊天历史记录
        await loadChatHistory(response.service.id, response.chat.chat_id);
        
        const successMessage: Message = {
          id: Date.now(),
          from: '系统',
          content: `已为您连接到在线客服 ${response.service.name}，请稍候...`,
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, successMessage]);
      } else {
        // 客服不在线，显示系统提示
        console.log('客服不在线，显示系统提示');
        const noServiceMessage: Message = {
          id: Date.now(),
          from: '系统',
          content: '当前无可用客服，请您稍后尝试',
          created_at: new Date().toISOString()
        };
        setMessages(prev => [...prev, noServiceMessage]);
      }
    } catch (error) {
      console.error('连接客服失败:', error);
      const errorMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '连接客服时出现错误，请稍后重试',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsConnectingToService(false);
    }
  };

  // 检查客服可用性（真实API调用）
  const checkCustomerServiceAvailabilityLocal = async (): Promise<boolean> => {
    try {
      const response = await checkCustomerServiceAvailability();
      console.log('客服在线状态:', response);
      return response.available;
      } catch (error) {
      console.error('检查客服可用性失败:', error);
      // 如果API调用失败，返回false（无客服在线）
      return false;
    }
  };

  // 检查并更新客服在线状态
  const checkServiceAvailability = useCallback(async () => {
    setServiceStatusLoading(true);
    try {
      const isAvailable = await checkCustomerServiceAvailabilityLocal();
      setServiceAvailable(isAvailable);
      console.log('客服在线状态已更新:', isAvailable);
    } catch (error) {
      console.error('检查客服状态失败:', error);
      setServiceAvailable(false);
    } finally {
      setServiceStatusLoading(false);
    }
  }, []);

  // 结束客服对话
  const handleEndConversation = async () => {
    console.log('handleEndConversation 被调用');
    console.log('currentChatId:', currentChatId);
    console.log('serviceConnected:', serviceConnected);
    
    if (!currentChatId) {
      console.error('没有活跃的客服对话');
      const errorMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '没有活跃的客服对话，无法结束对话',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
      return;
    }
    
    try {
      console.log('正在调用 endCustomerServiceChat API...');
      const response = await fetch(`${API_BASE_URL}/api/users/customer-service/end-chat/${currentChatId}`, {
        method: 'POST',
        credentials: 'include'  // 使用Cookie认证
      });
      
      if (!response.ok) {
        // 如果返回400或404，说明对话不存在或已结束，清理localStorage
        if (response.status === 400 || response.status === 404) {
          console.log('对话不存在或已结束，清理localStorage并重置状态');
          // 保存chat_id用于评价（如果存在）
          if (currentChatId) {
            setRatingChatId(currentChatId);
            setShowRatingModal(true);
          }
          localStorage.removeItem('currentCustomerServiceChat');
          setServiceConnected(false);
          setCurrentChatId(null);
          setCurrentChat(null);
          // setService(null); // 已移除service状态
          
          const cleanupMessage: Message = {
            id: Date.now(),
            from: '系统',
            content: '对话已结束，状态已重置',
            created_at: new Date().toISOString()
          };
          setMessages(prev => [...prev, cleanupMessage]);
          return;
        }
        throw new Error('结束对话失败');
      }
      
      console.log('endCustomerServiceChat API 调用成功');
      
      // 显示系统消息
      const endMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '对话已结束，感谢您的使用！',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, endMessage]);
      
      // 保存chat_id用于评价
      setRatingChatId(currentChatId);
      
      // 重置状态
      setServiceConnected(false);
      setCurrentChatId(null);
      setCurrentChat(null);
      
      // 清除localStorage中的对话信息
      localStorage.removeItem('currentCustomerServiceChat');
      
      // 显示评价弹窗
      setShowRatingModal(true);
      
    } catch (error) {
      console.error('结束对话失败:', error);
      const errorMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '结束对话失败，请稍后重试',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, errorMessage]);
    }
  };

  // 提交评价
  const handleSubmitRating = async () => {
    if (!ratingChatId) {
      console.error('没有对话ID');
      return;
    }
    
    try {
      const response = await fetch(`${API_BASE_URL}/api/users/customer-service/rate/${ratingChatId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        credentials: 'include',  // 使用Cookie认证
        body: JSON.stringify({
          rating: rating,
          comment: ratingComment
        })
      });
      
      if (!response.ok) {
        throw new Error('评分提交失败');
      }
      
      // 关闭评价弹窗
      setShowRatingModal(false);
      setRating(5);
      setRatingComment('');
      setRatingChatId(null);
      
      // 显示感谢消息
      const thankMessage: Message = {
        id: Date.now(),
        from: '系统',
        content: '感谢您的评价！',
        created_at: new Date().toISOString()
      };
      setMessages(prev => [...prev, thankMessage]);
      
    } catch (error) {
      console.error('提交评价失败:', error);
      alert('提交评价失败，请稍后重试');
    }
  };

  if (loading) {
    return (
      <div style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{
          background: '#fff',
          padding: '40px',
          borderRadius: '20px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{
            fontSize: '48px',
            marginBottom: '20px',
            animation: 'spin 1s linear infinite'
          }}>⏳</div>
          <div style={{
            fontSize: '18px',
            color: '#3b82f6',
            fontWeight: '600'
          }}>加载消息中心...</div>
        </div>
      </div>
    );
  }

  if (!user) {
  return (
      <div style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        <div style={{
          background: '#fff',
          padding: '40px',
          borderRadius: '20px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{
            fontSize: '48px',
            marginBottom: '20px'
          }}>🔒</div>
          <div style={{
            fontSize: '18px',
            color: '#ef4444',
            fontWeight: '600',
            marginBottom: '20px'
          }}>请先登录</div>
          <button
            onClick={() => setShowLoginModal(true)}
            style={{
              padding: '12px 24px',
              background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              color: '#fff',
              border: 'none',
              borderRadius: '12px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              transition: 'all 0.3s ease'
            }}
          >
            前往登录
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      height: '100vh', 
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: '0',
      overflow: 'hidden',
      boxSizing: 'border-box'
    }}>
      <div style={{ 
        width: '100%',
        height: '100vh',
        background: '#fff',
        overflow: 'hidden',
        display: 'flex',
        boxSizing: 'border-box'
      }}>
        
        {/* 左侧联系人列表 */}
        <div style={{ 
          width: isMobile ? (showContactsList ? '100%' : '0') : '350px', 
          borderRight: isMobile ? 'none' : '1px solid #e2e8f0', 
          background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
          display: 'flex',
          flexDirection: 'column',
          position: isMobile ? 'absolute' : 'relative',
          zIndex: isMobile ? 1000 : 'auto',
          transition: 'all 0.3s ease',
          overflow: isMobile ? 'hidden' : 'visible'
        }}>
          {/* 头部标题 */}
          <div style={{ 
            padding: isMobile ? '20px 16px' : '30px 24px', 
            textAlign: 'center', 
            fontWeight: '800', 
            fontSize: isMobile ? '20px' : '24px',
            background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
            color: '#fff',
            position: 'relative'
          }}>
            <div style={{ 
              position: 'absolute', 
              left: isMobile ? '16px' : '20px', 
              top: '50%', 
              transform: 'translateY(-50%)',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: isMobile ? '6px 12px' : '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: isMobile ? '12px' : '14px',
              fontWeight: '600',
              backdropFilter: 'blur(10px)',
              transition: 'all 0.3s ease'
            }}
            onClick={() => {
              if (isMobile) {
                setShowContactsList(false);
              } else {
                navigate('/');
              }
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
              e.currentTarget.style.transform = 'translateY(-50%) scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
            }}
          >
            {isMobile ? '← 关闭' : '← 返回'}
        </div>
            💬 消息中心
          </div>

          {/* 搜索框 */}
          <div style={{ 
            padding: isMobile ? '16px' : '20px 24px',
            borderBottom: '1px solid #e2e8f0'
          }}>
            <div style={{ 
              position: 'relative',
              background: '#fff',
              borderRadius: '25px',
              border: '2px solid #e2e8f0',
              overflow: 'hidden',
              transition: 'all 0.3s ease'
            }}>
              <input
                type="text"
                placeholder="搜索联系人..."
                style={{
                  width: '100%',
                  padding: '12px 20px 12px 45px',
                  border: 'none',
                  outline: 'none',
                  fontSize: '14px',
                  background: 'transparent'
                }}
              />
              <div style={{
                position: 'absolute',
                left: '15px',
                top: '50%',
                transform: 'translateY(-50%)',
                fontSize: '16px',
                color: '#94a3b8'
              }}>
                🔍
              </div>
            </div>
          </div>

          {/* 联系人列表 */}
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {/* 客服中心 - 固定在顶部 */}
            <div
              onClick={() => {
                // 先检查localStorage中是否已有活跃的客服对话
                const savedChat = localStorage.getItem('currentCustomerServiceChat');
                console.log('点击客服中心时检查localStorage:', savedChat);
                
                if (savedChat) {
                  try {
                    const chatData = JSON.parse(savedChat);
                    console.log('发现已保存的客服对话:', chatData);
                    
                    // 检查对话是否已结束
                    if (chatData.chat.is_ended === 0) {
                      // 对话未结束，恢复现有对话
                      console.log('恢复现有客服对话');
                      setIsConnectingToService(true);
                      setIsServiceMode(true);
                      setActiveContact(null);
                      setServiceConnected(true);
                      setCurrentChatId(chatData.chat.chat_id);
                      setCurrentChat(chatData.chat);
                      // setService(chatData.service); // 已移除service状态
                      
                      // 加载该对话的聊天历史记录
                      loadChatHistory(chatData.service.id, chatData.chat.chat_id);
                      setIsConnectingToService(false);
                      return; // 直接返回，不创建新对话
                    } else {
                      // 对话已结束，清除localStorage并重置状态
                      console.log('保存的对话已结束，清除localStorage并重置状态');
                      localStorage.removeItem('currentCustomerServiceChat');
                      setServiceConnected(false);
                      setCurrentChatId(null);
                      setCurrentChat(null);
                      // setService(null); // 已移除service状态
                    }
                  } catch (error) {
                    console.error('解析保存的对话失败:', error);
                    localStorage.removeItem('currentCustomerServiceChat');
                    setServiceConnected(false);
                    setCurrentChatId(null);
                    setCurrentChat(null);
                    // setService(null); // 已移除service状态
                  }
                }
                
                // 如果没有未结束的对话，只显示客服聊天框
                console.log('没有未结束的客服对话，显示客服聊天框');
                setIsServiceMode(true);
                setActiveContact(null);
                setMessages([]);
                setShowSystemWarning(true);
              }}
              style={{ 
                display: 'flex', 
                alignItems: 'center', 
                gap: '16px', 
                padding: '20px 24px', 
                cursor: 'pointer', 
                background: isServiceMode ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'linear-gradient(135deg, #fef3c7, #fde68a)', 
                color: isServiceMode ? '#fff' : '#92400e',
                fontWeight: isServiceMode ? 700 : 600,
                transition: 'all 0.3s ease',
                borderBottom: '3px solid #f59e0b',
                position: 'relative',
                boxShadow: isServiceMode ? '0 4px 12px rgba(59, 130, 246, 0.3)' : '0 2px 8px rgba(245, 158, 11, 0.2)'
              }}
            >
              <div style={{ 
                position: 'relative',
                width: '50px',
                height: '50px'
              }}>
                <img src={'/static/service.png'} alt="客服" style={{ 
                  width: '50px', 
                  height: '50px', 
                  borderRadius: '50%', 
                  border: '3px solid #f59e0b', 
                  background: '#fffbe6', 
                  objectFit: 'cover',
                  boxShadow: '0 4px 12px rgba(245, 158, 11, 0.3)',
                  transition: 'none' // 禁用过渡效果，防止形变
                }} 
                onLoad={(e) => {
                  console.log('客服头像加载成功:', e.currentTarget.src);
                }}
                onError={(e) => {
                  console.error('客服头像加载失败:', e.currentTarget.src);
                  e.currentTarget.src = '/static/avatar1.png'; // 备用头像
                }}
                />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '16px', fontWeight: '700', marginBottom: '4px' }}>
                  🎧 客服中心
                </div>
                <div style={{ 
                  fontSize: '12px', 
                  opacity: 0.8,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}>
                  <span>在线服务</span>
                  <div style={{
                    width: '6px',
                    height: '6px',
                    background: '#10b981',
                    borderRadius: '50%'
                  }}></div>
                </div>
              </div>
            </div>

            {/* 分割线 */}
            <div style={{
              height: '2px',
              background: 'linear-gradient(90deg, #f59e0b, #fbbf24, #f59e0b)',
              margin: '0 24px',
              borderRadius: '1px',
              boxShadow: '0 1px 3px rgba(245, 158, 11, 0.3)'
            }}></div>

            {/* 分割线标题 */}
            <div style={{
              padding: '12px 24px 8px 24px',
              fontSize: '12px',
              fontWeight: '600',
              color: '#6b7280',
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
              borderBottom: '1px solid #e2e8f0'
            }}>
              💬 联系人
            </div>

            {/* 联系人列表 */}
            {contactsLoading ? (
              <div style={{ 
                color: '#64748b', 
                textAlign: 'center', 
                padding: '60px 24px',
                fontSize: '16px'
              }}>
                <div style={{ 
                  fontSize: '48px', 
                  marginBottom: '16px',
                  opacity: 0.5,
                  animation: 'pulse 1.5s ease-in-out infinite'
                }}>⏳</div>
                <div style={{ fontWeight: '600', marginBottom: '8px' }}>正在加载联系人...</div>
                <div style={{ fontSize: '14px', opacity: 0.7 }}>
                  请稍候
                </div>
              </div>
            ) : contacts.length === 0 ? (
              <div style={{ 
                color: '#64748b', 
                textAlign: 'center', 
                padding: '60px 24px',
                fontSize: '16px'
              }}>
                <div style={{ 
                  fontSize: '48px', 
                  marginBottom: '16px',
                  opacity: 0.5
                }}>👥</div>
                <div style={{ fontWeight: '600', marginBottom: '8px' }}>暂无联系人</div>
                <div style={{ fontSize: '14px', opacity: 0.7 }}>
                  开始与其他人聊天吧
                </div>
              </div>
            ) : (
              contacts.map(c => {
                // 格式化最新消息时间
                const formatLastMessageTime = (timeString: string | null) => {
                  if (!timeString) return '暂无消息';
                  
                  const now = new Date();
                  const messageTime = new Date(timeString);
                  const diffInMinutes = Math.floor((now.getTime() - messageTime.getTime()) / (1000 * 60));
                  
                  if (diffInMinutes < 1) return '刚刚';
                  if (diffInMinutes < 60) return `${diffInMinutes}分钟前`;
                  
                  const diffInHours = Math.floor(diffInMinutes / 60);
                  if (diffInHours < 24) return `${diffInHours}小时前`;
                  
                  const diffInDays = Math.floor(diffInHours / 24);
                  if (diffInDays < 7) return `${diffInDays}天前`;
                  
                  return messageTime.toLocaleDateString('zh-CN', {
                    month: 'short',
                    day: 'numeric'
                  });
                };

                return (
                  <div
                    key={c.id}
                    onClick={() => { 
                      // 如果点击的是同一个联系人，不执行任何操作
                      if (activeContact?.id === c.id && !isServiceMode) {
                        return;
                      }
                      
                      setActiveContact(c); 
                      setIsServiceMode(false); 
                      setMessages([]); // 清空消息列表，准备加载新的聊天历史
                    }}
                    style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '16px', 
                      padding: '20px 24px', 
                      cursor: 'pointer', 
                      background: activeContact?.id === c.id && !isServiceMode ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' : 'transparent', 
                      color: activeContact?.id === c.id && !isServiceMode ? '#fff' : '#475569',
                      fontWeight: activeContact?.id === c.id && !isServiceMode ? 700 : 600, 
                      position: 'relative',
                      transition: 'all 0.3s ease',
                      borderBottom: '1px solid #e2e8f0'
                    }}
                    onMouseEnter={(e) => {
                      if (activeContact?.id !== c.id || isServiceMode) {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (activeContact?.id !== c.id || isServiceMode) {
                        e.currentTarget.style.background = 'transparent';
                      }
                    }}
                  >
                    <div style={{ 
                      position: 'relative',
                      width: '50px',
                      height: '50px'
                    }}>
                      <img 
                        src={c.avatar || '/static/avatar1.png'} 
                        alt="头像" 
                        style={{ 
                          width: '50px', 
                          height: '50px', 
                          borderRadius: '50%', 
                          border: '3px solid #3b82f6', 
                          background: '#f8fbff', 
                          objectFit: 'cover',
                          cursor: 'pointer',
                          boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                        }}
                        onClick={(e) => {
                          e.stopPropagation();
                          navigate(`/user/${c.id}`);
                        }}
                      />
                    </div>
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
                      <div style={{ 
                        fontSize: '16px', 
                        fontWeight: '700', 
                        marginBottom: '4px',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px'
                      }}>
                        {c.name || `用户${c.id}`}
                      </div>
                      <div style={{ 
                        fontSize: '12px', 
                        opacity: 0.7,
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}>
                        <span>{formatLastMessageTime(c.last_message_time || null)}</span>
                        <div style={{
                          width: '6px',
                          height: '6px',
                          background: '#10b981',
                          borderRadius: '50%'
                        }}></div>
                      </div>
                    </div>
                    {false && (
                      <div style={{ 
                        background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                        borderRadius: '50%',
                        width: '24px',
                        height: '24px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '12px',
                        color: '#fff',
                        fontWeight: 'bold',
                        boxShadow: '0 2px 8px rgba(239, 68, 68, 0.4)'
                      }}>
                        {/* 未读消息计数功能已移除 */}
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
      </div>
        
        {/* 右侧聊天区域 */}
        <div style={{ 
          flex: 1, 
          display: 'flex', 
          flexDirection: 'column',
          background: '#fff',
          width: isMobile ? '100%' : 'auto',
          position: isMobile ? 'relative' : 'static'
        }}>
          {/* 聊天头部 */}
        <div style={{ 
            padding: isMobile ? '16px' : '24px 30px', 
            borderBottom: '1px solid #e2e8f0', 
            background: 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)',
          display: 'flex',
          alignItems: 'center',
            gap: '16px',
            minHeight: '80px'
          }}>
            {/* 移动端菜单按钮 */}
            {isMobile && (
              <button
                onClick={() => setShowContactsList(true)}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  border: 'none',
                  color: '#fff',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: '600',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '4px'
                }}
              >
                ☰ 联系人
              </button>
            )}
            {isServiceMode ? (
              <>
                <div style={{ 
                  position: 'relative',
                  width: '60px',
                  height: '60px'
                }}>
                  <img 
                    src="/static/service.png" 
                    alt="客服头像" 
                    style={{ 
                      width: '60px', 
                      height: '60px', 
                      borderRadius: '50%', 
                      border: '3px solid #f59e0b', 
                      cursor: 'pointer',
                      objectFit: 'cover',
                      boxShadow: '0 4px 12px rgba(245, 158, 11, 0.3)',
                      transition: 'none' // 禁用过渡效果，防止形变
                    }}
                    onLoad={(e) => {
                      console.log('客服头像加载成功:', e.currentTarget.src);
                    }}
                    onError={(e) => {
                      console.error('客服头像加载失败:', e.currentTarget.src);
                      e.currentTarget.src = '/static/avatar1.png'; // 备用头像
                    }}
                  />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    fontSize: '20px', 
                    fontWeight: '700', 
                    color: '#1e293b',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    客服中心
                  </div>
                  <div style={{ 
                    fontSize: '14px', 
                    color: '#64748b',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <div style={{
                      width: '8px',
                      height: '8px',
                      background: '#10b981',
                      borderRadius: '50%'
                    }}></div>
                    <span>服务时间：8:00-18:00</span>
                  </div>
                </div>
              </>
            ) : activeContact ? (
              <>
                <div style={{ 
                  position: 'relative',
                  width: '60px',
                  height: '60px'
                }}>
            <img 
              src={activeContact.avatar || '/static/avatar1.png'} 
              alt="头像" 
              style={{ 
                      width: '60px', 
                      height: '60px', 
                borderRadius: '50%', 
                      border: '3px solid #3b82f6', 
                cursor: 'pointer',
                      objectFit: 'cover',
                      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
              }}
              onClick={() => navigate(`/user/${activeContact.id}`)}
            />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ 
                    fontSize: '20px', 
                    fontWeight: '700', 
                    color: '#1e293b',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    {activeContact.name || `用户${activeContact.id}`}
        </div>
                  <div style={{ 
                    fontSize: '14px', 
                    color: '#64748b',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px'
                  }}>
                    <div style={{
                      width: '8px',
                      height: '8px',
                      background: '#10b981',
                      borderRadius: '50%'
                    }}></div>
                    <span>在线</span>
                  </div>
                </div>
              </>
            ) : (
              <div style={{ 
                flex: 1, 
                textAlign: 'center',
                color: '#64748b'
              }}>
                <div style={{ 
                  fontSize: '18px', 
                  fontWeight: '600',
                  marginBottom: '4px'
                }}>
                  消息中心
                </div>
                <div style={{ 
                  fontSize: '14px',
                  opacity: 0.7
                }}>
                  选择左侧联系人开始聊天
                </div>
              </div>
            )}
          </div>

          {/* 消息显示区域 */}
          <div style={{ 
            flex: 1, 
            overflowY: 'auto', 
            padding: isMobile ? '16px' : '30px', 
            background: 'linear-gradient(135deg, #f8fbff 0%, #f1f5f9 100%)',
            display: 'flex', 
            flexDirection: 'column'
          }}>
            {/* 用户聊天模式下的系统提示 */}
            {activeContact && !isServiceMode && showSystemWarning && (
              <div style={{
                background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
                border: '2px solid #f59e0b',
                borderRadius: '12px',
                padding: '16px 20px',
                marginBottom: '20px',
                boxShadow: '0 4px 12px rgba(245, 158, 11, 0.2)',
                position: 'sticky',
                top: '0',
                zIndex: 10
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px'
                }}>
                  <div style={{
                    fontSize: '20px',
                    color: '#92400e'
                  }}>
                    ⚠️
                  </div>
                  <div style={{
                    flex: 1,
                    color: '#92400e',
                    fontSize: '14px',
                    fontWeight: '600',
                    lineHeight: '1.4'
                  }}>
                    请谨慎交易，注意保护个人财产与隐私安全，避免私下交易风险。
                  </div>
                        <button
                    onClick={() => {
                      setShowSystemWarning(false);
                    }}
                          style={{
                            background: 'none',
                            border: 'none',
                      color: '#92400e',
                      fontSize: '16px',
                            cursor: 'pointer',
                      padding: '4px',
                      borderRadius: '4px',
                      transition: 'all 0.3s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = 'rgba(146, 64, 14, 0.1)';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'none';
                    }}
                  >
                    ✕
                        </button>
                    </div>
                    </div>
            )}
          {isServiceMode ? (
              <div style={{ 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'center', 
                height: '100%',
                color: '#64748b',
                fontSize: '18px',
                flexDirection: 'column',
                gap: '20px',
                padding: '40px'
              }}>
                <div style={{ 
                  fontSize: '80px', 
                  opacity: 0.3,
                  marginBottom: '10px'
                }}>🎧</div>
                <div style={{
                  fontSize: '20px',
                  fontWeight: '600',
                  color: '#374151',
                  marginBottom: '8px'
                }}>
                  客服中心
                  </div>
                <div style={{
                  fontSize: '16px',
                  color: '#6b7280',
                  textAlign: 'center',
                  lineHeight: '1.5',
                  maxWidth: '300px',
                  marginBottom: '20px'
                }}>
                  我们的客服团队随时为您提供帮助<br/>
                  服务时间：每日 8:00-18:00
                  </div>
                <div style={{
                  background: '#fef3c7',
                  border: '1px solid #f59e0b',
                  borderRadius: '12px',
                  padding: '16px',
                  maxWidth: '400px',
                  textAlign: 'center'
                }}>
                  <div style={{
                    fontSize: '14px',
                    color: '#92400e',
                    fontWeight: '600',
                    marginBottom: '8px'
                  }}>
                    📋 服务说明
                  </div>
                  <div style={{
                    fontSize: '13px',
                    color: '#b45309',
                    lineHeight: '1.4'
                  }}>
                    • 工作时间：周一至周日 8:00-18:00<br/>
                    • 响应时间：通常5分钟内回复<br/>
                    • 支持语言：中文、英文<br/>
                    • 紧急情况请发送邮件至客服邮箱
                  </div>
                </div>
              </div>
            ) : !activeContact ? (
              isServiceMode ? (
                // 客服模式下的连接界面
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  height: '100%',
                  color: '#64748b',
                  fontSize: '18px',
                  flexDirection: 'column',
                  gap: '20px',
                  padding: '40px'
                }}>
                  <div style={{ 
                    fontSize: '80px', 
                    opacity: 0.3,
                    marginBottom: '10px'
                  }}>🎧</div>
                  <div style={{
                    fontSize: '20px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>
                    联系在线客服
                  </div>
                  <div style={{
                    fontSize: '16px',
                    color: '#6b7280',
                    textAlign: 'center',
                    lineHeight: '1.5',
                    maxWidth: '400px',
                    marginBottom: '20px'
                  }}>
                    我们的客服团队随时为您提供帮助，请点击下方按钮开始对话
                  </div>
                  <button
                    onClick={async () => {
                      console.log('开始对话按钮被点击');
                      setIsConnectingToService(true);
                      try {
                        // 检查客服在线状态
                        console.log('检查客服在线状态...');
                        const isServiceAvailable = await checkCustomerServiceAvailabilityLocal();
                        console.log('客服在线状态:', isServiceAvailable);
                        
                        if (isServiceAvailable) {
                          // 客服在线，尝试分配客服
                          const response = await assignCustomerService();
                          console.log('客服分配响应:', response);
                          
                          if (response.error) {
                            console.error('客服连接失败:', response.error);
                            const errorMessage: Message = {
                              id: Date.now(),
                              from: '系统',
                              content: `连接客服失败: ${response.error}`,
                              created_at: new Date().toISOString()
                            };
                            setMessages(prev => [...prev, errorMessage]);
                            return;
                          }
                          
                          // 连接成功
                          console.log('客服连接成功，响应:', response);
                          setServiceConnected(true);
                          setCurrentChatId(response.chat.chat_id);
                          setCurrentChat(response.chat);
                          // setService(response.service); // 已移除service状态
                          
                          // 保存对话信息到localStorage
                          const chatToSave = {
                            chat: response.chat,
                            service: response.service,
                            chatId: response.chat.chat_id
                          };
                          localStorage.setItem('currentCustomerServiceChat', JSON.stringify(chatToSave));
                          
                          // 加载该对话的聊天历史记录
                          await loadChatHistory(response.service.id, response.chat.chat_id);
                          
                          const successMessage: Message = {
                            id: Date.now(),
                            from: '系统',
                            content: `已为您连接到在线客服 ${response.service.name}，请稍候...`,
                            created_at: new Date().toISOString()
                          };
                          setMessages(prev => [...prev, successMessage]);
                        } else {
                          // 客服不在线，显示系统提示
                          const noServiceMessage: Message = {
                            id: Date.now(),
                            from: '系统',
                            content: '当前无可用客服，请您稍后尝试',
                            created_at: new Date().toISOString()
                          };
                          setMessages(prev => [...prev, noServiceMessage]);
                        }
                      } catch (error) {
                        console.error('连接客服失败:', error);
                        const errorMessage: Message = {
                          id: Date.now(),
                          from: '系统',
                          content: '连接客服时出现错误，请稍后重试',
                          created_at: new Date().toISOString()
                        };
                        setMessages(prev => [...prev, errorMessage]);
                      } finally {
                        setIsConnectingToService(false);
                      }
                    }}
                    disabled={isConnectingToService}
                    style={{
                      background: isConnectingToService ? '#9ca3af' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '25px',
                      padding: '16px 32px',
                      fontSize: '16px',
                      fontWeight: '600',
                      cursor: isConnectingToService ? 'not-allowed' : 'pointer',
                      transition: 'all 0.3s ease',
                      boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                    }}
                  >
                    {isConnectingToService ? '连接中...' : '开始对话'}
                  </button>
                </div>
              ) : (
                // 普通模式下的默认界面
                <div style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center', 
                  height: '100%',
                  color: '#64748b',
                  fontSize: '18px',
                  flexDirection: 'column',
                  gap: '20px',
                  padding: '40px'
                }}>
                  <div style={{ 
                    fontSize: '80px', 
                    opacity: 0.3,
                    marginBottom: '10px'
                  }}>💬</div>
                  <div style={{
                    fontSize: '20px',
                    fontWeight: '600',
                    color: '#374151',
                    marginBottom: '8px'
                  }}>
                    欢迎使用消息中心
                  </div>
                  <div style={{
                    fontSize: '16px',
                    color: '#6b7280',
                    textAlign: 'center',
                    lineHeight: '1.5',
                    maxWidth: '300px'
                  }}>
                    从左侧选择联系人或客服中心开始对话
                    </div>
                  <div style={{
                    display: 'flex',
                    gap: '12px',
                    marginTop: '20px'
                  }}>
                    <div style={{
                          padding: '8px 16px',
                      background: 'linear-gradient(135deg, #f3f4f6, #e5e7eb)',
                      borderRadius: '20px',
                      fontSize: '14px',
                      color: '#6b7280',
                      border: '1px solid #d1d5db'
                    }}>
                      💬 私聊
                    </div>
                    <div style={{
                              padding: '8px 16px',
                      background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
                      borderRadius: '20px',
                      fontSize: '14px',
                      color: '#92400e',
                      border: '1px solid #f59e0b'
                    }}>
                      🎧 客服
                    </div>
                  </div>
                </div>
              )
                    ) : null}
            
            {((activeContact && !isServiceMode) || (isServiceMode && messages.length > 0)) && messages.map((msg, idx) => (
              <div key={idx} style={{ 
                marginBottom: 16, 
                display: 'flex',
                justifyContent: msg.from === '系统' ? 'center' : (msg.from === '我' ? 'flex-end' : 'flex-start'),
                width: '100%'
              }}>
                <div style={{ 
                  background: msg.from === '系统' 
                    ? 'linear-gradient(135deg, #f3f4f6, #e5e7eb)' 
                    : msg.from === '我' 
                      ? 'linear-gradient(135deg, #3b82f6, #1d4ed8)' 
                      : '#fff', 
                  color: msg.from === '系统' 
                    ? '#374151' 
                    : msg.from === '我' 
                      ? '#fff' 
                      : '#333', 
                  borderRadius: 16, 
                  padding: '12px 20px', 
                  maxWidth: msg.from === '系统' ? '80%' : '70%', 
                  wordBreak: 'break-word',
                  display: 'flex',
                  flexDirection: 'column',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
                  border: msg.from === '系统' 
                    ? '1px solid #d1d5db' 
                    : msg.from === '我' 
                      ? 'none' 
                      : '1px solid #e2e8f0',
                  textAlign: msg.from === '系统' ? 'center' : 'left'
                }}>
                  {msg.from !== '系统' && (
                    <div style={{ fontSize: 14, marginBottom: 4, fontWeight: '600' }}>{msg.from}</div>
                  )}
                  {renderMessageContent(msg.content)}
                  <div style={{ 
                    fontSize: 12, 
                    color: msg.from === '系统' 
                      ? '#6b7280' 
                      : msg.from === '我' 
                        ? 'rgba(255,255,255,0.7)' 
                        : '#888', 
                    marginTop: 4 
                  }}>
                    {formatTime(msg.created_at)}
                  </div>
                </div>
              </div>
            ))}
            <div ref={messagesEndRef} />
                  </div>

          {/* 输入区域 */}
          <div style={{ 
            padding: isMobile ? '16px' : '24px 30px', 
            borderTop: '1px solid #e2e8f0', 
            background: '#fff',
            position: 'relative'
          }}>
            {/* 功能按钮行 */}
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              gap: '16px', 
              marginBottom: '16px',
              flexWrap: 'wrap'
            }}>
              {/* 表情按钮 */}
                    <button
                onClick={() => setShowEmojiPicker(!showEmojiPicker)}
                data-emoji-button
                      style={{
                  background: 'linear-gradient(135deg, #f8fafc, #f1f5f9)',
                  border: '2px solid #e2e8f0',
                  fontSize: '20px',
                  cursor: 'pointer',
                        padding: '12px',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #1d4ed8)';
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                }}
              >
                😊
                    </button>

              {/* 图片按钮 */}
                    <button
                onClick={() => {
                  const fileInput = document.getElementById('image-upload') as HTMLInputElement;
                  if (fileInput) {
                    fileInput.click();
                  }
                }}
                      style={{
                  background: 'linear-gradient(135deg, #f8fafc, #f1f5f9)',
                  border: '2px solid #e2e8f0',
                  fontSize: '18px',
                        cursor: 'pointer',
                  padding: '12px',
                  borderRadius: '12px',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #3b82f6, #1d4ed8)';
                  e.currentTarget.style.borderColor = '#3b82f6';
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc, #f1f5f9)';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
                }}
              >
                📷
                    </button>

              {/* 客服模式专用按钮 */}
              {isServiceMode && (
                <>

                  {/* 联系在线客服按钮 / 结束对话按钮 */}
                  {!serviceConnected ? (
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                      {/* 客服在线状态指示器 */}
                      <div style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: '6px',
                        fontSize: '12px',
                        color: serviceStatusLoading ? '#6b7280' : (serviceAvailable ? '#10b981' : '#ef4444'),
                        fontWeight: '500'
                      }}>
                        <div style={{
                          width: '8px',
                          height: '8px',
                          borderRadius: '50%',
                          backgroundColor: serviceStatusLoading ? '#6b7280' : (serviceAvailable ? '#10b981' : '#ef4444'),
                          animation: serviceStatusLoading ? 'pulse 1.5s ease-in-out infinite' : 'none'
                        }}></div>
                        {serviceStatusLoading ? '检查客服状态中...' : (serviceAvailable ? '客服在线' : '客服离线')}
                      </div>
                      
                      <button
                        onClick={handleContactCustomerService}
                        disabled={isConnectingToService || !serviceAvailable}
                        style={{
                          background: isConnectingToService || !serviceAvailable
                            ? 'linear-gradient(135deg, #9ca3af, #6b7280)' 
                            : 'linear-gradient(135deg, #10b981, #059669)',
                          border: `2px solid ${isConnectingToService || !serviceAvailable ? '#9ca3af' : '#10b981'}`,
                          fontSize: '14px',
                          cursor: isConnectingToService || !serviceAvailable ? 'not-allowed' : 'pointer',
                          padding: '12px 16px',
                          borderRadius: '12px',
                          transition: 'all 0.3s ease',
                          boxShadow: isConnectingToService || !serviceAvailable
                            ? '0 2px 8px rgba(156, 163, 175, 0.2)' 
                            : '0 2px 8px rgba(16, 185, 129, 0.2)',
                          color: '#fff',
                          fontWeight: '600',
                          opacity: isConnectingToService || !serviceAvailable ? 0.7 : 1
                        }}
                        onMouseEnter={(e) => {
                          if (!isConnectingToService && serviceAvailable) {
                            e.currentTarget.style.background = 'linear-gradient(135deg, #059669, #047857)';
                            e.currentTarget.style.borderColor = '#059669';
                            e.currentTarget.style.transform = 'translateY(-2px)';
                            e.currentTarget.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.4)';
                          }
                        }}
                        onMouseLeave={(e) => {
                          if (!isConnectingToService && serviceAvailable) {
                            e.currentTarget.style.background = 'linear-gradient(135deg, #10b981, #059669)';
                            e.currentTarget.style.borderColor = '#10b981';
                            e.currentTarget.style.transform = 'translateY(0)';
                            e.currentTarget.style.boxShadow = '0 2px 8px rgba(16, 185, 129, 0.2)';
                          }
                        }}
                      >
                        {isConnectingToService ? '⏳ 连接中...' : 
                         !serviceAvailable ? '🚫 客服离线' : 
                         '🎧 联系在线客服'}
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={handleEndConversation}
                      style={{
                        background: 'linear-gradient(135deg, #ef4444, #dc2626)',
                        border: '2px solid #ef4444',
                        fontSize: '14px',
                        cursor: 'pointer',
                        padding: '12px 16px',
                        borderRadius: '12px',
                        transition: 'all 0.3s ease',
                        boxShadow: '0 2px 8px rgba(239, 68, 68, 0.2)',
                        color: '#fff',
                        fontWeight: '600'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #dc2626, #b91c1c)';
                        e.currentTarget.style.borderColor = '#dc2626';
                        e.currentTarget.style.transform = 'translateY(-2px)';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(239, 68, 68, 0.4)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'linear-gradient(135deg, #ef4444, #dc2626)';
                        e.currentTarget.style.borderColor = '#ef4444';
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(239, 68, 68, 0.2)';
                      }}
                    >
                      🚪 结束对话
                    </button>
                  )}
                  
                  {/* 调试按钮 - 临时添加 */}
                  {serviceConnected && (
                        <button
                      onClick={() => {
                        console.log('调试按钮被点击');
                        console.log('currentChatId:', currentChatId);
                        console.log('serviceConnected:', serviceConnected);
                        alert(`调试信息:\ncurrentChatId: ${currentChatId}\nserviceConnected: ${serviceConnected}`);
                      }}
                          style={{
                        background: 'linear-gradient(135deg, #6b7280, #4b5563)',
                        border: '2px solid #6b7280',
                        fontSize: '12px',
                        cursor: 'pointer',
                        padding: '8px 12px',
                        borderRadius: '8px',
                        transition: 'all 0.3s ease',
                        boxShadow: '0 2px 8px rgba(107, 114, 128, 0.2)',
                            color: '#fff',
                        fontWeight: '600',
                        marginLeft: '8px'
                      }}
                    >
                      🔧 调试
                        </button>
                  )}
                </>
              )}
            </div>

            {/* 隐藏的文件输入 */}
            <input
              type="file"
              accept="image/*"
              onChange={handleImageSelect}
              style={{ display: 'none' }}
              id="image-upload"
            />

            {/* 图片预览区域 */}
            {imagePreview && (
              <div style={{
                marginBottom: '12px',
                padding: '12px',
                background: '#f8fafc',
                borderRadius: '12px',
                border: '2px solid #e2e8f0'
              }}>
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  marginBottom: '8px'
                }}>
                  <span style={{
                    fontSize: '14px',
                    fontWeight: '600',
                    color: '#374151'
                  }}>
                    📷 图片预览
                  </span>
                  <button
                    onClick={cancelImageSelection}
                    style={{
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '6px',
                      padding: '4px 8px',
                      fontSize: '12px',
                      cursor: 'pointer',
                      transition: 'all 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#dc2626';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = '#ef4444';
                    }}
                  >
                    取消
                  </button>
                </div>
                <img
                  src={imagePreview}
                  alt="预览"
                  style={{
                    maxWidth: '200px',
                    maxHeight: '200px',
                    borderRadius: '8px',
                    objectFit: 'cover'
                  }}
                />
                <div style={{
                  marginTop: '8px',
                  display: 'flex',
                  gap: '8px'
                }}>
                  <button
                    onClick={sendImage}
                    disabled={uploadingImage}
                    style={{
                      background: uploadingImage ? '#cbd5e1' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 16px',
                      fontSize: '14px',
                      fontWeight: '600',
                      cursor: uploadingImage ? 'not-allowed' : 'pointer',
                      transition: 'all 0.3s ease'
                    }}
                  >
                    {uploadingImage ? '发送中...' : '发送图片'}
                  </button>
                </div>
              </div>
            )}

            {/* 输入框和发送按钮 */}
            <div style={{ 
              display: 'flex', 
              gap: '12px', 
              alignItems: 'flex-end',
              position: 'relative'
            }}>
              {/* 表情选择器 */}
              {showEmojiPicker && (
                <div 
                  data-emoji-picker
                  style={{
                    position: 'absolute',
                    bottom: '100%',
                    left: 0,
                    background: '#fff',
                    border: '2px solid #e2e8f0',
                    borderRadius: '16px',
                    padding: '20px',
                    maxHeight: '250px',
                    overflowY: 'auto',
                    boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
                    zIndex: 1000,
                    display: 'grid',
                    gridTemplateColumns: 'repeat(8, 1fr)',
                    gap: '8px',
                    marginBottom: '12px'
                  }}>
                  {/* 关闭按钮 */}
                  <div style={{
                    gridColumn: '1 / -1',
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: '8px',
                    paddingBottom: '8px',
                    borderBottom: '1px solid #e2e8f0'
                  }}>
                    <span style={{
                      fontSize: '14px',
                      fontWeight: '600',
                      color: '#374151'
                    }}>选择表情</span>
                    <button
                      onClick={() => setShowEmojiPicker(false)}
                      style={{
                        background: 'none',
                        border: 'none',
                        fontSize: '18px',
                        cursor: 'pointer',
                        padding: '4px',
                        borderRadius: '4px',
                        color: '#6b7280',
                        transition: 'all 0.2s ease'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                        e.currentTarget.style.color = '#374151';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'none';
                        e.currentTarget.style.color = '#6b7280';
                      }}
                    >
                      ✕
                    </button>
                  </div>
                  
                  {emojis.map((emoji, index) => (
                  <button
                      key={index}
                      onClick={() => addEmoji(emoji)}
                    style={{
                        background: 'none',
                      border: 'none',
                        fontSize: '20px',
                        cursor: 'pointer',
                        padding: '8px',
                        borderRadius: '8px',
                        transition: 'all 0.3s ease'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.background = '#f3f4f6';
                        e.currentTarget.style.transform = 'scale(1.1)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.background = 'none';
                        e.currentTarget.style.transform = 'scale(1)';
                      }}
                    >
                      {emoji}
                  </button>
                  ))}
        </div>
              )}
              
          <input
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
                placeholder={
                  isServiceMode 
                    ? '输入您的问题，我们的客服团队会尽快回复...' 
                    : activeContact 
                      ? '输入消息...' 
                      : '请先选择联系人'
                }
                style={{ 
                  flex: 1, 
                  padding: isMobile ? '12px 16px' : '16px 20px', 
                  borderRadius: '25px', 
                  border: '2px solid #e2e8f0',
                  background: '#fff',
                  color: '#1e293b',
                  fontSize: isMobile ? '14px' : '16px',
                  fontFamily: 'inherit',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.05)'
                }}
                disabled={!activeContact && !(isServiceMode && serviceConnected)}
              />
              
          <button
            onClick={handleSend}
                style={{ 
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)', 
                  color: '#fff', 
                  border: 'none', 
                  borderRadius: '25px', 
                  padding: '16px 24px', 
                  fontWeight: '700',
                  fontSize: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.3s ease',
                  boxShadow: '0 4px 12px rgba(59, 130, 246, 0.3)'
                }}
                disabled={(() => {
                  const condition1 = !activeContact && !(isServiceMode && serviceConnected);
                  const condition2 = !input.trim();
                  const isDisabled = condition1 || condition2;
                  console.log('发送按钮状态检查:', {
                    activeContact: !!activeContact,
                    isServiceMode,
                    serviceConnected,
                    input: input.trim(),
                    condition1,
                    condition2,
                    isDisabled
                  });
                  return isDisabled;
                })()}
              >
                发送
              </button>
        </div>
      </div>
        </div>
      </div>

      {/* 评价弹窗 */}
      {showRatingModal && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000
        }}>
          <div style={{
            background: '#fff',
            borderRadius: '20px',
            padding: '30px',
            maxWidth: '500px',
            width: '90%',
            boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)'
          }}>
            <h3 style={{
              margin: '0 0 20px 0',
              fontSize: '20px',
              fontWeight: '700',
              color: '#1e293b',
              textAlign: 'center'
            }}>
              💬 评价客服服务
            </h3>
            
            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '15px',
                fontSize: '16px',
                fontWeight: '600',
                color: '#374151',
                textAlign: 'center'
              }}>
                请为本次客服服务评分：
              </label>
              
              {/* 交互式星星评分 */}
              <div style={{ 
                display: 'flex', 
                gap: '30px', 
                justifyContent: 'center',
                marginBottom: '12px'
              }}>
                {[1, 2, 3, 4, 5].map((star) => (
                  <button
                    key={star}
                    onClick={() => setRating(star)}
                    style={{
                      background: 'none',
                      border: 'none',
                      fontSize: '36px',
                      cursor: 'pointer',
                      padding: '4px',
                      borderRadius: '4px',
                      transition: 'all 0.3s ease',
                      position: 'relative'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'scale(1.2)';
                      e.currentTarget.style.filter = 'drop-shadow(0 4px 8px rgba(251, 191, 36, 0.4))';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'scale(1)';
                      e.currentTarget.style.filter = 'none';
                    }}
                  >
                    {/* 星星轮廓 */}
                    <span style={{
                      position: 'absolute',
                      top: '50%',
                      left: '50%',
                      transform: 'translate(-50%, -50%)',
                      fontSize: '36px',
                      color: '#d1d5db',
                      zIndex: 1
                    }}>
                      ⭐
                    </span>
                    
                    {/* 填充的星星 */}
                    {star <= rating && (
                      <span style={{
                        position: 'absolute',
                        top: '50%',
                        left: '50%',
                        transform: 'translate(-50%, -50%)',
                        fontSize: '36px',
                        color: '#fbbf24',
                        zIndex: 2,
                        textShadow: '0 2px 4px rgba(251, 191, 36, 0.3)'
                      }}>
                        ⭐
                      </span>
                    )}
                  </button>
                ))}
              </div>
              
              {/* 评分文字说明 */}
              <div style={{
                textAlign: 'center',
                fontSize: '16px',
                fontWeight: '600',
                color: rating >= 4 ? '#059669' : rating >= 3 ? '#d97706' : '#dc2626',
                padding: '8px 16px',
                borderRadius: '20px',
                background: rating >= 4 ? '#ecfdf5' : rating >= 3 ? '#fef3c7' : '#fef2f2',
                border: `2px solid ${rating >= 4 ? '#10b981' : rating >= 3 ? '#f59e0b' : '#ef4444'}`,
                display: 'inline-block',
                margin: '0 auto',
                minWidth: '120px'
              }}>
                {rating === 1 && '😞 很不满意'}
                {rating === 2 && '😕 不满意'}
                {rating === 3 && '😐 一般'}
                {rating === 4 && '😊 满意'}
                {rating === 5 && '😍 非常满意'}
              </div>
              
              {/* 评分数字显示 */}
              <div style={{
                textAlign: 'center',
                marginTop: '8px',
                fontSize: '14px',
                color: '#6b7280'
              }}>
                当前评分: {rating} 星
              </div>
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{
                display: 'block',
                marginBottom: '10px',
                fontSize: '14px',
                fontWeight: '600',
                color: '#374151'
              }}>
                评价内容（可选）：
              </label>
              <textarea
                value={ratingComment}
                onChange={(e) => setRatingComment(e.target.value)}
                placeholder="请分享您对本次客服服务的感受..."
                style={{
                  width: '100%',
                  minHeight: '80px',
                  padding: '12px',
                  border: '2px solid #e5e7eb',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontFamily: 'inherit',
                  resize: 'vertical',
                  outline: 'none',
                  transition: 'border-color 0.2s ease'
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = '#e5e7eb';
                }}
              />
            </div>

            <div style={{
              display: 'flex',
              gap: '12px',
              justifyContent: 'center'
            }}>
              <button
                onClick={() => {
                  setShowRatingModal(false);
                  setRating(5);
                  setRatingComment('');
                  setRatingChatId(null);
                }}
                style={{
                  background: '#f3f4f6',
                  color: '#374151',
                  border: 'none',
                  padding: '12px 24px',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#e5e7eb';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f3f4f6';
                }}
              >
                取消
              </button>
              <button
                onClick={handleSubmitRating}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  padding: '12px 24px',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-1px)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = 'none';
                }}
              >
                提交评价
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
          window.location.reload();
        }}
        onReopen={() => {
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />
    </div>
  );
};

export default MessagePage; 
