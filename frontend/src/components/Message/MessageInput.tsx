import React, { useState, useRef, useCallback } from 'react';
import api from '../../api';

interface MessageInputProps {
  input: string;
  setInput: (value: string) => void;
  onSendMessage: (content: string) => void;
  onSendImage: (imageId: string) => void;
  uploadingImage: boolean;
  disabled?: boolean;
  placeholder?: string;
}

const MessageInput: React.FC<MessageInputProps> = ({
  input,
  setInput,
  onSendMessage,
  onSendImage,
  uploadingImage,
  disabled = false,
  placeholder = "输入消息..."
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleImageUpload = useCallback(async (file: File) => {
    try {
      const formData = new FormData();
      formData.append('image', file);
      
      const response = await api.post('/api/upload/image', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      if (response.data.success) {
        const { image_id } = response.data;
        onSendImage(image_id);
      } else {
        throw new Error('图片上传失败');
      }
    } catch (error) {
      console.error('图片上传错误:', error);
      alert('图片上传失败，请重试');
    }
  }, [onSendImage]);

  const handleFileSelect = useCallback((event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      // 检查文件类型
      if (!file.type.startsWith('image/')) {
        alert('请选择图片文件');
        return;
      }
      
      // 检查文件大小 (5MB)
      if (file.size > 5 * 1024 * 1024) {
        alert('图片文件过大，请选择小于5MB的图片');
        return;
      }
      
      handleImageUpload(file);
    }
  }, [handleImageUpload]);

  const handleImageClick = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const [showEmojiPicker, setShowEmojiPicker] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (input.trim() && !disabled && !uploadingImage) {
      onSendMessage(input.trim());
      setInput('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setInput(e.target.value);
    
    // 自动调整高度
    const textarea = e.target;
    textarea.style.height = 'auto';
    textarea.style.height = Math.min(textarea.scrollHeight, 120) + 'px';
  };


  const insertEmoji = (emoji: string) => {
    setInput(prev => prev + emoji);
    setShowEmojiPicker(false);
    textareaRef.current?.focus();
  };

  const emojis = ['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'];

  return (
    <div style={{ 
      padding: '16px', 
      borderTop: '1px solid #e5e7eb',
      background: 'white'
    }}>
      <form onSubmit={handleSubmit}>
        <div style={{ 
          display: 'flex', 
          alignItems: 'flex-end', 
          gap: '8px',
          position: 'relative'
        }}>
          {/* 文件上传按钮 */}
          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            disabled={disabled || uploadingImage}
            style={{
              padding: '8px',
              border: 'none',
              background: 'transparent',
              cursor: disabled || uploadingImage ? 'not-allowed' : 'pointer',
              borderRadius: '6px',
              color: disabled || uploadingImage ? '#9ca3af' : '#6b7280',
              fontSize: '18px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minWidth: '36px',
              height: '36px'
            }}
            onMouseEnter={(e) => {
              if (!disabled && !uploadingImage) {
                e.currentTarget.style.background = '#f3f4f6';
              }
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
            }}
          >
            📎
          </button>

          {/* 图片上传按钮 */}
          <button
            type="button"
            onClick={handleImageClick}
            disabled={disabled || uploadingImage}
            style={{
              padding: '8px',
              border: 'none',
              background: 'transparent',
              cursor: disabled || uploadingImage ? 'not-allowed' : 'pointer',
              borderRadius: '6px',
              color: disabled || uploadingImage ? '#9ca3af' : '#6b7280',
              fontSize: '18px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minWidth: '36px',
              height: '36px'
            }}
            onMouseEnter={(e) => {
              if (!disabled && !uploadingImage) {
                e.currentTarget.style.background = '#f3f4f6';
              }
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
            }}
          >
            {uploadingImage ? '⏳' : '📷'}
          </button>

          {/* 表情按钮 */}
          <button
            type="button"
            onClick={() => setShowEmojiPicker(!showEmojiPicker)}
            disabled={disabled}
            style={{
              padding: '8px',
              border: 'none',
              background: 'transparent',
              cursor: disabled ? 'not-allowed' : 'pointer',
              borderRadius: '6px',
              color: disabled ? '#9ca3af' : '#6b7280',
              fontSize: '18px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minWidth: '36px',
              height: '36px'
            }}
            onMouseEnter={(e) => {
              if (!disabled) {
                e.currentTarget.style.background = '#f3f4f6';
              }
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'transparent';
            }}
          >
            😊
          </button>

          {/* 输入框 */}
          <div style={{ flex: 1, position: 'relative' }}>
            <textarea
              ref={textareaRef}
              value={input}
              onChange={handleInputChange}
              onKeyPress={handleKeyPress}
              placeholder={placeholder}
              disabled={disabled || uploadingImage}
              style={{
                width: '100%',
                minHeight: '36px',
                maxHeight: '120px',
                padding: '8px 12px',
                border: '1px solid #d1d5db',
                borderRadius: '18px',
                resize: 'none',
                outline: 'none',
                fontSize: '14px',
                lineHeight: '1.4',
                fontFamily: 'inherit',
                background: disabled ? '#f9fafb' : 'white',
                color: disabled ? '#9ca3af' : '#1f2937'
              }}
            />
          </div>

          {/* 发送按钮 */}
          <button
            type="submit"
            disabled={!input.trim() || disabled || uploadingImage}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: (!input.trim() || disabled || uploadingImage) ? '#e5e7eb' : '#3b82f6',
              color: (!input.trim() || disabled || uploadingImage) ? '#9ca3af' : 'white',
              borderRadius: '18px',
              cursor: (!input.trim() || disabled || uploadingImage) ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              transition: 'all 0.2s ease'
            }}
          >
            {uploadingImage ? '发送中...' : '发送'}
            {!uploadingImage && '→'}
          </button>
        </div>
      </form>

      {/* 表情选择器 */}
      {showEmojiPicker && (
        <div style={{
          position: 'absolute',
          bottom: '100%',
          left: '0',
          right: '0',
          background: 'white',
          border: '1px solid #e5e7eb',
          borderRadius: '8px',
          padding: '12px',
          marginBottom: '8px',
          maxHeight: '200px',
          overflowY: 'auto',
          boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
          zIndex: 1000
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(8, 1fr)',
            gap: '4px'
          }}>
            {emojis.map((emoji, index) => (
              <button
                key={index}
                onClick={() => insertEmoji(emoji)}
                style={{
                  padding: '4px',
                  border: 'none',
                  background: 'transparent',
                  cursor: 'pointer',
                  borderRadius: '4px',
                  fontSize: '16px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  minWidth: '32px',
                  height: '32px'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#f3f4f6';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'transparent';
                }}
              >
                {emoji}
              </button>
            ))}
          </div>
        </div>
      )}

      {/* 隐藏的文件输入 */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileSelect}
        style={{ display: 'none' }}
      />
    </div>
  );
};

export default MessageInput;
