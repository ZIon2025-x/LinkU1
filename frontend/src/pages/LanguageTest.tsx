import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import LanguageSwitcher from '../components/LanguageSwitcher';

const LanguageTest: React.FC = () => {
  const { t, language } = useLanguage();

  return (
    <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
      <div style={{ position: 'absolute', top: '20px', right: '20px' }}>
        <LanguageSwitcher />
      </div>
      
      <h1>语言切换测试页面</h1>
      <p>当前语言: {language}</p>
      
      <h2>通用文本</h2>
      <p>登录: {t('common.login')}</p>
      <p>注册: {t('common.register')}</p>
      <p>首页: {t('common.home')}</p>
      <p>关于: {t('common.about')}</p>
      <p>设置: {t('common.settings')}</p>
      
      <h2>导航文本</h2>
      <p>任务: {t('navigation.tasks')}</p>
      <p>发布: {t('navigation.publish')}</p>
      <p>个人资料: {t('navigation.profile')}</p>
      
      <h2>认证文本</h2>
      <p>登录标题: {t('auth.loginTitle')}</p>
      <p>注册标题: {t('auth.registerTitle')}</p>
      <p>忘记密码: {t('auth.forgotPassword')}</p>
      
      <h2>首页文本</h2>
      <p>欢迎: {t('home.welcome')}</p>
      <p>副标题: {t('home.subtitle')}</p>
      <p>精选任务: {t('home.featuredTasks')}</p>
      
      <h2>关于页面文本</h2>
      <p>标题: {t('about.title')}</p>
      <p>副标题: {t('about.subtitle')}</p>
      <p>使命: {t('about.mission')}</p>
      <p>愿景: {t('about.vision')}</p>
      
      <h2>页脚文本</h2>
      <p>公司名称: {t('footer.companyName')}</p>
      <p>描述: {t('footer.description')}</p>
      <p>支持: {t('footer.support')}</p>
      
      <h2>注册页面</h2>
      <p>标题: {t('register.title')}</p>
      <p>副标题: {t('register.subtitle')}</p>
      <p>用户名: {t('register.username')}</p>
      <p>邮箱: {t('register.email')}</p>
      <p>密码: {t('register.password')}</p>
      <p>确认密码: {t('register.confirmPassword')}</p>
      
      <h2>发布任务</h2>
      <p>标题: {t('publishTask.title')}</p>
      <p>副标题: {t('publishTask.subtitle')}</p>
      <p>任务标题: {t('publishTask.taskTitle')}</p>
      <p>任务描述: {t('publishTask.taskDescription')}</p>
      <p>分类: {t('publishTask.category')}</p>
      <p>截止时间: {t('publishTask.deadline')}</p>
      <p>奖励金额: {t('publishTask.reward')}</p>
      
      <h2>我的任务</h2>
      <p>标题: {t('myTasks.title')}</p>
      <p>副标题: {t('myTasks.subtitle')}</p>
      <p>已发布任务: {t('myTasks.publishedTasks')}</p>
      <p>已申请任务: {t('myTasks.appliedTasks')}</p>
      <p>已完成任务: {t('myTasks.completedTasks')}</p>
      
      <h2>任务详情</h2>
      <p>标题: {t('taskDetail.title')}</p>
      <p>发布者: {t('taskDetail.publishedBy')}</p>
      <p>发布时间: {t('taskDetail.publishedOn')}</p>
      <p>截止时间: {t('taskDetail.deadline')}</p>
      <p>奖励: {t('taskDetail.reward')}</p>
      <p>地点: {t('taskDetail.location')}</p>
      
      <h2>个人资料</h2>
      <p>标题: {t('profile.title')}</p>
      <p>编辑资料: {t('profile.editProfile')}</p>
      <p>个人信息: {t('profile.personalInfo')}</p>
      <p>用户名: {t('profile.username')}</p>
      <p>邮箱: {t('profile.email')}</p>
      <p>电话: {t('profile.phone')}</p>
      <p>个人简介: {t('profile.bio')}</p>
      
      <h2>设置</h2>
      <p>标题: {t('settings.title')}</p>
      <p>常规: {t('settings.general')}</p>
      <p>通知: {t('settings.notifications')}</p>
      <p>隐私: {t('settings.privacy')}</p>
      <p>安全: {t('settings.security')}</p>
      <p>账户: {t('settings.account')}</p>
      
      <h2>钱包</h2>
      <p>标题: {t('wallet.title')}</p>
      <p>余额: {t('wallet.balance')}</p>
      <p>总收入: {t('wallet.totalEarnings')}</p>
      <p>总支出: {t('wallet.totalSpent')}</p>
      <p>交易记录: {t('wallet.transactions')}</p>
      
      <h2>VIP会员</h2>
      <p>标题: {t('vip.title')}</p>
      <p>副标题: {t('vip.subtitle')}</p>
      <p>当前计划: {t('vip.currentPlan')}</p>
      <p>升级: {t('vip.upgrade')}</p>
      <p>降级: {t('vip.downgrade')}</p>
      <p>取消: {t('vip.cancel')}</p>
      
      <h2>管理后台</h2>
      <p>标题: {t('admin.title')}</p>
      <p>副标题: {t('admin.subtitle')}</p>
      <p>概览: {t('admin.overview')}</p>
      <p>用户: {t('admin.users')}</p>
      <p>任务: {t('admin.tasks')}</p>
      <p>报告: {t('admin.reports')}</p>
      
      <h2>客服中心</h2>
      <p>标题: {t('customerService.title')}</p>
      <p>副标题: {t('customerService.subtitle')}</p>
      <p>支持工单: {t('customerService.tickets')}</p>
      <p>创建工单: {t('customerService.createTicket')}</p>
      <p>工单标题: {t('customerService.ticketTitle')}</p>
      
      <h2>加入我们</h2>
      <p>标题: {t('joinUs.title')}</p>
      <p>副标题: {t('joinUs.subtitle')}</p>
      <p>开放职位: {t('joinUs.openPositions')}</p>
      <p>职位名称: {t('joinUs.jobTitle')}</p>
      <p>部门: {t('joinUs.department')}</p>
      <p>地点: {t('joinUs.location')}</p>
    </div>
  );
};

export default LanguageTest;
