/**
 * 任务达人管理后台
 * 路径: /task-experts/me/dashboard
 * 功能: 服务管理、申请管理
 */

import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { TimeHandlerV2 } from '../utils/timeUtils';
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
  getTaskParticipants,
  startMultiParticipantTask,
  approveParticipant,
  rejectParticipant,
  approveExitRequest,
  rejectExitRequest,
  completeTaskAndDistributeRewardsEqual,
  createExpertMultiParticipantTask,
  getServiceTimeSlots,
  getServiceTimeSlotsPublic,
  batchCreateServiceTimeSlots,
  deleteTimeSlotsByDate,
  deleteServiceTimeSlot,
  getExpertDashboardStats,
  getExpertSchedule,
  createServiceTimeSlot,
  createClosedDate,
  getClosedDates,
  deleteClosedDate,
  deleteClosedDateByDate,
  deleteActivity,
} from '../api';
import LoginModal from '../components/LoginModal';
import ServiceDetailModal from '../components/ServiceDetailModal';
import TabButton from '../components/taskExpertDashboard/TabButton';
import StatCard from '../components/taskExpertDashboard/StatCard';
import { compressImage } from '../utils/imageCompression';
import api from '../api';
import styles from './TaskExpertDashboard.module.css';

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

// 这是一个占位组件，实际实现需要从备份恢复
const TaskExpertDashboard: React.FC = () => {
  return (
    <div>
      <h1>任务达人管理后台</h1>
      <p>此组件需要从备份恢复完整实现</p>
    </div>
  );
};

export default TaskExpertDashboard;