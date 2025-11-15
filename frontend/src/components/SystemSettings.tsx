import React, { useState, useEffect } from 'react';
import { getSystemSettings, updateSystemSettings, getPointsSettings, updatePointsSettings, getCheckinSettings, updateCheckinSettings } from '../api';

interface SystemSettingsType {
  vip_enabled: boolean;
  super_vip_enabled: boolean;
  vip_task_threshold: number;
  super_vip_task_threshold: number;
  vip_price_threshold: number;
  super_vip_price_threshold: number;
  vip_button_visible: boolean;
  vip_auto_upgrade_enabled: boolean;
  vip_benefits_description: string;
  super_vip_benefits_description: string;
  // VIP晋升超级VIP的条件
  vip_to_super_task_count_threshold: number;
  vip_to_super_rating_threshold: number;
  vip_to_super_completion_rate_threshold: number;
  vip_to_super_enabled: boolean;
}

const SystemSettings: React.FC<{ onClose: () => void }> = ({ onClose }) => {
  const [settings, setSettings] = useState<SystemSettingsType>({
    vip_enabled: true,
    super_vip_enabled: true,
    vip_task_threshold: 5,
    super_vip_task_threshold: 20,
    vip_price_threshold: 10,
    super_vip_price_threshold: 50,
    vip_button_visible: true,
    vip_auto_upgrade_enabled: false,
    vip_benefits_description: '优先任务推荐、专属客服服务、任务发布数量翻倍',
    super_vip_benefits_description: '所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识',
    // VIP晋升超级VIP的条件
    vip_to_super_task_count_threshold: 50,
    vip_to_super_rating_threshold: 4.5,
    vip_to_super_completion_rate_threshold: 0.8,
    vip_to_super_enabled: true
  });
  
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  
  // 积分设置状态
  const [pointsSettings, setPointsSettings] = useState({
    points_task_complete_bonus: 0
  });
  const [checkinSettings, setCheckinSettings] = useState({
    daily_base_points: 0
  });
  const [pointsLoading, setPointsLoading] = useState(false);
  const [pointsSaving, setPointsSaving] = useState(false);

  useEffect(() => {
    loadSettings();
    loadPointsSettings();
  }, []);

  const loadSettings = async () => {
    setLoading(true);
    try {
      const response = await getSystemSettings();
      setSettings(response);
    } catch (error) {
      console.error('加载系统设置失败:', error);
      setError('加载系统设置失败');
    } finally {
      setLoading(false);
    }
  };

  const loadPointsSettings = async () => {
    setPointsLoading(true);
    try {
      const [pointsData, checkinData] = await Promise.all([
        getPointsSettings(),
        getCheckinSettings()
      ]);
      setPointsSettings({
        points_task_complete_bonus: pointsData.points_task_complete_bonus || 0
      });
      setCheckinSettings({
        daily_base_points: checkinData.daily_base_points || 0
      });
    } catch (error) {
      console.error('加载积分设置失败:', error);
    } finally {
      setPointsLoading(false);
    }
  };

  const handleSavePointsSettings = async () => {
    setPointsSaving(true);
    setError(null);
    setSuccess(null);
    
    try {
      await Promise.all([
        updatePointsSettings(pointsSettings),
        updateCheckinSettings(checkinSettings)
      ]);
      setSuccess('积分设置保存成功！');
      setTimeout(() => setSuccess(null), 3000);
    } catch (error) {
      console.error('保存积分设置失败:', error);
      setError('保存积分设置失败');
    } finally {
      setPointsSaving(false);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    setError(null);
    setSuccess(null);
    
    try {
      await updateSystemSettings(settings);
      setSuccess('系统设置保存成功！');
      setTimeout(() => setSuccess(null), 3000);
    } catch (error) {
      console.error('保存系统设置失败:', error);
      setError('保存系统设置失败');
    } finally {
      setSaving(false);
    }
  };

  const handleInputChange = (field: keyof SystemSettingsType, value: any) => {
    setSettings(prev => ({
      ...prev,
      [field]: value
    }));
  };

  const resetToDefaults = () => {
    setSettings({
      vip_enabled: true,
      super_vip_enabled: true,
      vip_task_threshold: 5,
      super_vip_task_threshold: 20,
      vip_price_threshold: 10,
      super_vip_price_threshold: 50,
      vip_button_visible: true,
      vip_auto_upgrade_enabled: false,
      vip_benefits_description: '优先任务推荐、专属客服服务、任务发布数量翻倍',
      super_vip_benefits_description: '所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识',
      // VIP晋升超级VIP的条件
      vip_to_super_task_count_threshold: 50,
      vip_to_super_rating_threshold: 4.5,
      vip_to_super_completion_rate_threshold: 0.8,
      vip_to_super_enabled: true
    });
  };

  return (
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
        background: 'white',
        borderRadius: '10px',
        padding: '30px',
        maxWidth: '800px',
        width: '90%',
        maxHeight: '90vh',
        overflowY: 'auto',
        boxShadow: '0 10px 30px rgba(0, 0, 0, 0.3)'
      }}>
        {/* 标题栏 */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '30px',
          paddingBottom: '15px',
          borderBottom: '2px solid #f0f0f0'
        }}>
          <h2 style={{ margin: 0, color: '#333', fontSize: '24px' }}>
            ⚙️ 系统设置
          </h2>
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#999',
              padding: '5px'
            }}
          >
            ✕
          </button>
        </div>

        {loading && (
          <div style={{ textAlign: 'center', padding: '20px' }}>
            <div>加载中...</div>
          </div>
        )}

        {!loading && (
          <div>
            {/* VIP功能控制 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#007bff', marginBottom: '20px', fontSize: '18px' }}>
                🎯 VIP功能控制
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* VIP功能开关 */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div>
                    <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>启用VIP功能</div>
                    <div style={{ fontSize: '14px', color: '#666' }}>
                      控制VIP会员功能是否可用
                    </div>
                  </div>
                  <label style={{ position: 'relative', display: 'inline-block', width: '60px', height: '34px' }}>
                    <input
                      type="checkbox"
                      checked={settings.vip_enabled}
                      onChange={(e) => handleInputChange('vip_enabled', e.target.checked)}
                      style={{ opacity: 0, width: 0, height: 0 }}
                    />
                    <span style={{
                      position: 'absolute',
                      cursor: 'pointer',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      backgroundColor: settings.vip_enabled ? '#007bff' : '#ccc',
                      transition: '.4s',
                      borderRadius: '34px'
                    }}>
                      <span style={{
                        position: 'absolute',
                        content: '""',
                        height: '26px',
                        width: '26px',
                        left: '4px',
                        bottom: '4px',
                        backgroundColor: 'white',
                        transition: '.4s',
                        borderRadius: '50%',
                        transform: settings.vip_enabled ? 'translateX(26px)' : 'translateX(0)'
                      }} />
                    </span>
                  </label>
                </div>

                {/* 超级VIP功能开关 */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div>
                    <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>启用超级VIP功能</div>
                    <div style={{ fontSize: '14px', color: '#666' }}>
                      控制超级VIP会员功能是否可用
                    </div>
                  </div>
                  <label style={{ position: 'relative', display: 'inline-block', width: '60px', height: '34px' }}>
                    <input
                      type="checkbox"
                      checked={settings.super_vip_enabled}
                      onChange={(e) => handleInputChange('super_vip_enabled', e.target.checked)}
                      style={{ opacity: 0, width: 0, height: 0 }}
                    />
                    <span style={{
                      position: 'absolute',
                      cursor: 'pointer',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      backgroundColor: settings.super_vip_enabled ? '#dc3545' : '#ccc',
                      transition: '.4s',
                      borderRadius: '34px'
                    }}>
                      <span style={{
                        position: 'absolute',
                        content: '""',
                        height: '26px',
                        width: '26px',
                        left: '4px',
                        bottom: '4px',
                        backgroundColor: 'white',
                        transition: '.4s',
                        borderRadius: '50%',
                        transform: settings.super_vip_enabled ? 'translateX(26px)' : 'translateX(0)'
                      }} />
                    </span>
                  </label>
                </div>

                {/* VIP按钮显示控制 */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div>
                    <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>显示VIP按钮</div>
                    <div style={{ fontSize: '14px', color: '#666' }}>
                      控制首页是否显示VIP按钮
                    </div>
                  </div>
                  <label style={{ position: 'relative', display: 'inline-block', width: '60px', height: '34px' }}>
                    <input
                      type="checkbox"
                      checked={settings.vip_button_visible}
                      onChange={(e) => handleInputChange('vip_button_visible', e.target.checked)}
                      style={{ opacity: 0, width: 0, height: 0 }}
                    />
                    <span style={{
                      position: 'absolute',
                      cursor: 'pointer',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      backgroundColor: settings.vip_button_visible ? '#28a745' : '#ccc',
                      transition: '.4s',
                      borderRadius: '34px'
                    }}>
                      <span style={{
                        position: 'absolute',
                        content: '""',
                        height: '26px',
                        width: '26px',
                        left: '4px',
                        bottom: '4px',
                        backgroundColor: 'white',
                        transition: '.4s',
                        borderRadius: '50%',
                        transform: settings.vip_button_visible ? 'translateX(26px)' : 'translateX(0)'
                      }} />
                    </span>
                  </label>
                </div>
              </div>
            </div>

            {/* 自动升级设置 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#007bff', marginBottom: '20px', fontSize: '18px' }}>
                🚀 自动升级设置
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* 自动升级开关 */}
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div>
                    <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>启用自动升级</div>
                    <div style={{ fontSize: '14px', color: '#666' }}>
                      根据任务完成数量自动升级用户等级
                    </div>
                  </div>
                  <label style={{ position: 'relative', display: 'inline-block', width: '60px', height: '34px' }}>
                    <input
                      type="checkbox"
                      checked={settings.vip_auto_upgrade_enabled}
                      onChange={(e) => handleInputChange('vip_auto_upgrade_enabled', e.target.checked)}
                      style={{ opacity: 0, width: 0, height: 0 }}
                    />
                    <span style={{
                      position: 'absolute',
                      cursor: 'pointer',
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      backgroundColor: settings.vip_auto_upgrade_enabled ? '#ffc107' : '#ccc',
                      transition: '.4s',
                      borderRadius: '34px'
                    }}>
                      <span style={{
                        position: 'absolute',
                        content: '""',
                        height: '26px',
                        width: '26px',
                        left: '4px',
                        bottom: '4px',
                        backgroundColor: 'white',
                        transition: '.4s',
                        borderRadius: '50%',
                        transform: settings.vip_auto_upgrade_enabled ? 'translateX(26px)' : 'translateX(0)'
                      }} />
                    </span>
                  </label>
                </div>

                {/* VIP升级阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>VIP升级阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    完成任务数量达到此值时自动升级为VIP
                  </div>
                  <input
                    type="number"
                    value={settings.vip_task_threshold}
                    onChange={(e) => handleInputChange('vip_task_threshold', parseInt(e.target.value) || 0)}
                    style={{
                      width: '100px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="1"
                    max="100"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>个任务</span>
                </div>

                {/* 超级VIP升级阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>超级VIP升级阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    完成任务数量达到此值时自动升级为超级VIP
                  </div>
                  <input
                    type="number"
                    value={settings.super_vip_task_threshold}
                    onChange={(e) => handleInputChange('super_vip_task_threshold', parseInt(e.target.value) || 0)}
                    style={{
                      width: '100px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="1"
                    max="1000"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>个任务</span>
                </div>
              </div>
            </div>

            {/* VIP任务价格阈值设置 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#007bff', marginBottom: '20px', fontSize: '18px' }}>
                💰 VIP任务价格阈值
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* VIP任务价格阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>VIP任务价格阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    任务价格达到此值时自动标记为VIP任务
                  </div>
                  <input
                    type="number"
                    value={settings.vip_price_threshold}
                    onChange={(e) => handleInputChange('vip_price_threshold', parseFloat(e.target.value) || 0)}
                    style={{
                      width: '100px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="0"
                    max="1000"
                    step="0.1"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>英镑</span>
                </div>

                {/* 超级VIP任务价格阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>超级VIP任务价格阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    任务价格达到此值时自动标记为超级VIP任务
                  </div>
                  <input
                    type="number"
                    value={settings.super_vip_price_threshold}
                    onChange={(e) => handleInputChange('super_vip_price_threshold', parseFloat(e.target.value) || 0)}
                    style={{
                      width: '100px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="0"
                    max="10000"
                    step="0.1"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>英镑</span>
                </div>
              </div>
            </div>

            {/* VIP晋升超级VIP条件设置 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#007bff', marginBottom: '20px', fontSize: '18px' }}>
                🚀 VIP晋升超级VIP条件
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* 启用自动晋升 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input
                      type="checkbox"
                      checked={settings.vip_to_super_enabled}
                      onChange={(e) => handleInputChange('vip_to_super_enabled', e.target.checked)}
                      style={{ transform: 'scale(1.2)' }}
                    />
                    <div>
                      <div style={{ fontWeight: 'bold', marginBottom: '5px' }}>启用自动晋升</div>
                      <div style={{ fontSize: '14px', color: '#666' }}>
                        当VIP用户满足条件时自动晋升为超级VIP
                      </div>
                    </div>
                  </div>
                </div>

                {/* 任务数量阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>任务数量阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    发布任务和接受任务的总数量达到此值时符合晋升条件
                  </div>
                  <input
                    type="number"
                    value={settings.vip_to_super_task_count_threshold}
                    onChange={(e) => handleInputChange('vip_to_super_task_count_threshold', parseInt(e.target.value) || 0)}
                    style={{
                      width: '200px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="1"
                    max="1000"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>个任务</span>
                </div>

                {/* 平均评分阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>平均评分阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    用户平均评分达到此值时符合晋升条件
                  </div>
                  <input
                    type="number"
                    value={settings.vip_to_super_rating_threshold}
                    onChange={(e) => handleInputChange('vip_to_super_rating_threshold', parseFloat(e.target.value) || 0)}
                    style={{
                      width: '200px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="0"
                    max="5"
                    step="0.1"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>分</span>
                </div>

                {/* 任务完成率阈值 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>任务完成率阈值</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    任务完成率（已完成任务/总接受任务）达到此值时符合晋升条件
                  </div>
                  <input
                    type="number"
                    value={settings.vip_to_super_completion_rate_threshold}
                    onChange={(e) => handleInputChange('vip_to_super_completion_rate_threshold', parseFloat(e.target.value) || 0)}
                    style={{
                      width: '200px',
                      padding: '8px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px'
                    }}
                    min="0"
                    max="1"
                    step="0.01"
                  />
                  <span style={{ marginLeft: '10px', color: '#666' }}>（0-1之间）</span>
                </div>
              </div>
            </div>

            {/* 积分设置 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#28a745', marginBottom: '20px', fontSize: '18px' }}>
                ⭐ 积分设置
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* 任务完成奖励积分 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>任务完成奖励积分（默认值）</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    所有任务完成时的默认奖励积分（0表示不奖励）。管理员可以为指定任务单独调整积分。
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input
                      type="number"
                      value={pointsSettings.points_task_complete_bonus}
                      onChange={(e) => setPointsSettings(prev => ({
                        ...prev,
                        points_task_complete_bonus: parseInt(e.target.value) || 0
                      }))}
                      style={{
                        width: '150px',
                        padding: '8px',
                        border: '1px solid #ddd',
                        borderRadius: '4px',
                        fontSize: '14px'
                      }}
                      min="0"
                      step="100"
                    />
                    <span style={{ color: '#666' }}>积分（100积分 = £1.00）</span>
                  </div>
                </div>

                {/* 签到基础积分 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>签到基础积分</div>
                  <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
                    用户每日签到获得的基础积分奖励。
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <input
                      type="number"
                      value={checkinSettings.daily_base_points}
                      onChange={(e) => setCheckinSettings(prev => ({
                        ...prev,
                        daily_base_points: parseInt(e.target.value) || 0
                      }))}
                      style={{
                        width: '150px',
                        padding: '8px',
                        border: '1px solid #ddd',
                        borderRadius: '4px',
                        fontSize: '14px'
                      }}
                      min="0"
                      step="100"
                    />
                    <span style={{ color: '#666' }}>积分（100积分 = £1.00）</span>
                  </div>
                </div>

                {/* 保存按钮 */}
                <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                  <button
                    onClick={handleSavePointsSettings}
                    disabled={pointsSaving}
                    style={{
                      padding: '8px 20px',
                      border: 'none',
                      background: pointsSaving ? '#6c757d' : '#28a745',
                      color: 'white',
                      borderRadius: '5px',
                      cursor: pointsSaving ? 'not-allowed' : 'pointer',
                      fontSize: '14px',
                      fontWeight: '500'
                    }}
                  >
                    {pointsSaving ? '保存中...' : '保存积分设置'}
                  </button>
                </div>
              </div>
            </div>

            {/* 会员权益描述 */}
            <div style={{ marginBottom: '30px' }}>
              <h3 style={{ color: '#007bff', marginBottom: '20px', fontSize: '18px' }}>
                📝 会员权益描述
              </h3>
              
              <div style={{ display: 'grid', gap: '20px' }}>
                {/* VIP权益描述 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>VIP权益描述</div>
                  <textarea
                    value={settings.vip_benefits_description}
                    onChange={(e) => handleInputChange('vip_benefits_description', e.target.value)}
                    style={{
                      width: '100%',
                      height: '80px',
                      padding: '10px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px',
                      resize: 'vertical'
                    }}
                    placeholder="请输入VIP会员权益描述..."
                  />
                </div>

                {/* 超级VIP权益描述 */}
                <div style={{
                  padding: '15px',
                  background: '#f8f9fa',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  <div style={{ fontWeight: 'bold', marginBottom: '10px' }}>超级VIP权益描述</div>
                  <textarea
                    value={settings.super_vip_benefits_description}
                    onChange={(e) => handleInputChange('super_vip_benefits_description', e.target.value)}
                    style={{
                      width: '100%',
                      height: '80px',
                      padding: '10px',
                      border: '1px solid #ddd',
                      borderRadius: '4px',
                      fontSize: '14px',
                      resize: 'vertical'
                    }}
                    placeholder="请输入超级VIP会员权益描述..."
                  />
                </div>
              </div>
            </div>

            {/* 错误和成功消息 */}
            {error && (
              <div style={{
                background: '#f8d7da',
                color: '#721c24',
                padding: '10px',
                borderRadius: '4px',
                marginBottom: '20px',
                border: '1px solid #f5c6cb'
              }}>
                {error}
              </div>
            )}

            {success && (
              <div style={{
                background: '#d4edda',
                color: '#155724',
                padding: '10px',
                borderRadius: '4px',
                marginBottom: '20px',
                border: '1px solid #c3e6cb'
              }}>
                {success}
              </div>
            )}

            {/* 操作按钮 */}
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              paddingTop: '20px',
              borderTop: '2px solid #f0f0f0'
            }}>
              <button
                onClick={resetToDefaults}
                style={{
                  padding: '10px 20px',
                  border: '1px solid #6c757d',
                  background: 'white',
                  color: '#6c757d',
                  borderRadius: '5px',
                  cursor: 'pointer',
                  fontSize: '14px',
                  fontWeight: '500'
                }}
              >
                恢复默认
              </button>
              
              <div style={{ display: 'flex', gap: '10px' }}>
                <button
                  onClick={onClose}
                  style={{
                    padding: '10px 20px',
                    border: '1px solid #6c757d',
                    background: 'white',
                    color: '#6c757d',
                    borderRadius: '5px',
                    cursor: 'pointer',
                    fontSize: '14px',
                    fontWeight: '500'
                  }}
                >
                  取消
                </button>
                <button
                  onClick={handleSave}
                  disabled={saving}
                  style={{
                    padding: '10px 20px',
                    border: 'none',
                    background: saving ? '#6c757d' : '#007bff',
                    color: 'white',
                    borderRadius: '5px',
                    cursor: saving ? 'not-allowed' : 'pointer',
                    fontSize: '14px',
                    fontWeight: '500'
                  }}
                >
                  {saving ? '保存中...' : '保存设置'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default SystemSettings;
