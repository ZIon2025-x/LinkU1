import type React from 'react';
import { Select } from 'antd';
import { GlobalOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import styled from 'styled-components';

const LanguageSwitcherContainer = styled.div`
  display: flex;
  align-items: center;
  gap: 8px;
  
  .ant-select {
    min-width: 100px;
  }
  
  .ant-select-selector {
    border: 1px solid #d9d9d9 !important;
    border-radius: 6px !important;
    background: #fff !important;
    
    &:hover {
      border-color: #40a9ff !important;
    }
  }
  
  .ant-select-focused .ant-select-selector {
    border-color: #40a9ff !important;
    box-shadow: 0 0 0 2px rgba(24, 144, 255, 0.2) !important;
  }
`;

const LanguageSwitcher: React.FC = () => {
  const { language, setLanguage, t } = useLanguage();
  const navigate = useNavigate();

  const handleLanguageChange = (value: string) => {
    setLanguage(value as 'en' | 'zh', navigate);
  };

  return (
    <LanguageSwitcherContainer>
      <GlobalOutlined style={{ color: '#666', fontSize: '16px' }} />
      <Select
        value={language}
        onChange={handleLanguageChange}
        options={[
          { value: 'en', label: 'English' },
          { value: 'zh', label: '中文' }
        ]}
        size="small"
      />
    </LanguageSwitcherContainer>
  );
};

export default LanguageSwitcher;
