// frontend/src/components/TaskStructuredData.tsx
import React from 'react';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';

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

  const structuredData = {
    "@context": "https://schema.org",
    "@type": "JobPosting",
    "title": task.title,
    "description": task.description?.replace(/<[^>]*>/g, '').slice(0, 1000) || '',
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
        "addressLocality": task.location || "London",
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
    } : undefined
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

