// frontend/src/components/TaskStructuredData.tsx
import React from 'react';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import { obfuscateLocation } from '../utils/formatUtils';

dayjs.extend(utc);

interface TaskStructuredDataProps {
  task: any;
  language: string;
}

const getReward = (task: any): number => {
  return (
    task.agreed_reward ??
    task.final_reward ??      // 加上这个兜底（关键！）
    task.base_reward ??
    task.reward ??
    task.budget ??
    0
  );
};

const TaskStructuredData: React.FC<TaskStructuredDataProps> = ({ task, language }) => {
  const isOnline = !task.location || task.location.toLowerCase().includes('online');
  const reward = getReward(task);

  // 格式化日期为 ISO 8601 日期格式（YYYY-MM-DD）
  const formatISODate = (dateString?: string): string | undefined => {
    if (!dateString) return undefined;
    try {
      return dayjs(dateString).utc().format('YYYY-MM-DD');
    } catch {
      return undefined;
    }
  };

  // 清理描述文本，移除HTML标签，保留更多内容供AI理解
  const cleanDescription = task.description?.replace(/<[^>]*>/g, '').trim() || '';
  const descriptionForAI = cleanDescription.length > 1500 ? cleanDescription.slice(0, 1500) + '...' : cleanDescription;
  
  // 构建AI友好的结构化数据
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "JobPosting",
    "title": task.title,
    "description": descriptionForAI || `Task available on Link²Ur platform. ${task.task_type === 'one-off' ? 'One-time project' : 'Ongoing position'}.`,
    "identifier": {
      "@type": "PropertyValue",
      "name": "Link²Ur",
      "value": `task-${task.id}`
    },
    "datePosted": formatISODate(task.created_at),
    "validThrough": formatISODate(task.deadline),
    "employmentType": task.task_type === 'one-off' ? "CONTRACTOR" : "PART_TIME",
    "hiringOrganization": {
      "@type": "Organization",
      "name": "Link²Ur",
      "sameAs": "https://www.link2ur.com",
      "logo": "https://www.link2ur.com/static/logo.png"
    },
    "applicantLocationRequirements": isOnline ? undefined : {
      "@type": "Country",
      "name": "GB"
    },
    "jobLocation": isOnline ? {
      "@type": "Place",
      "address": { "@type": "PostalAddress", "addressCountry": "GB" }
    } : {
      "@type": "Place",
      "address": {
        "@type": "PostalAddress",
        "addressLocality": obfuscateLocation(task.location) || "London",
        "addressCountry": "GB"
      }
    },
    "baseSalary": reward > 0 ? {
      "@type": "MonetaryAmount",
      "currency": "GBP",
      "value": {
        "@type": "QuantitativeValue",
        "value": reward,
        "unitText": task.task_type === 'one-off' ? "ONE_TIME" : "HOUR"
      }
    } : undefined,
    // AI友好的额外信息
    "workHours": task.task_type === 'one-off' ? undefined : "PART_TIME",
    "jobLocationType": isOnline ? "TELECOMMUTE" : "ONSITE",
    "url": `https://www.link2ur.com/${language}/tasks/${task.id}`,
    // 添加关键词帮助AI理解任务类型
    "keywords": task.category ? `${task.category}, ${task.task_type}, UK, ${isOnline ? 'remote' : 'local'}` : undefined
  };

  // 移除 undefined 字段
  const cleanedData = JSON.parse(JSON.stringify(structuredData));

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(cleanedData, null, 2) }}
    />
  );
};

export default TaskStructuredData;

