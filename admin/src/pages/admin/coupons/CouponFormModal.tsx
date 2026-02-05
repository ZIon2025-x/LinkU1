import React, { useState } from 'react';
import { AdminModal } from '../../../components/admin';
import { CouponForm } from './types';
import styles from './CouponFormModal.module.css';

interface CouponFormModalProps {
  isOpen: boolean;
  isEdit: boolean;
  formData: CouponForm;
  loading: boolean;
  onClose: () => void;
  onSubmit: () => void;
  setFormData: React.Dispatch<React.SetStateAction<CouponForm>>;
}

const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow",
  "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton",
  "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York",
  "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast",
  "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster",
  "Warwick", "Cambridge", "Oxford", "Other"
];

const TASK_TYPES = [
  'tutoring', 'pet_care', 'delivery', 'cleaning', 'moving',
  'tech_support', 'translation', 'design', 'photography', 'other'
];

const APPLICABLE_SCENARIOS = [
  'task_posting', 'task_accepting', 'expert_service', 'all'
];

export const CouponFormModal: React.FC<CouponFormModalProps> = ({
  isOpen,
  isEdit,
  formData,
  loading,
  onClose,
  onSubmit,
  setFormData,
}) => {
  const [collapsedSections, setCollapsedSections] = useState({
    basic: false,
    discount: false,
    limits: false,
    eligibility: false,
    scenarios: false,
    validity: false,
  });

  const toggleSection = (section: keyof typeof collapsedSections) => {
    setCollapsedSections(prev => ({
      ...prev,
      [section]: !prev[section],
    }));
  };

  const updateField = <K extends keyof CouponForm>(field: K, value: CouponForm[K]) => {
    setFormData(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleSubmit = () => {
    // Validation
    if (!formData.name || !formData.valid_from || !formData.valid_until) {
      alert('请填写优惠券名称和有效期');
      return;
    }
    if (formData.discount_value <= 0) {
      alert('请填写折扣金额');
      return;
    }
    onSubmit();
  };

  const footer = (
    <>
      <button className={styles.btnCancel} onClick={onClose} disabled={loading}>
        取消
      </button>
      <button className={styles.btnSubmit} onClick={handleSubmit} disabled={loading}>
        {loading ? '提交中...' : isEdit ? '更新优惠券' : '创建优惠券'}
      </button>
    </>
  );

  return (
    <AdminModal
      isOpen={isOpen}
      onClose={onClose}
      title={isEdit ? '编辑优惠券' : '创建优惠券'}
      footer={footer}
      width="800px"
      maxHeight="85vh"
    >
      <div className={styles.form}>
        {/* 基本信息 */}
        <div className={styles.section}>
          <div className={styles.sectionHeader} onClick={() => toggleSection('basic')}>
            <h3>基本信息</h3>
            <span className={collapsedSections.basic ? styles.iconCollapsed : styles.iconExpanded}>
              ▼
            </span>
          </div>
          {!collapsedSections.basic && (
            <div className={styles.sectionContent}>
              <div className={styles.formGroup}>
                <label>优惠券代码 *</label>
                <input
                  type="text"
                  value={formData.code}
                  onChange={(e) => updateField('code', e.target.value.toUpperCase())}
                  placeholder="留空自动生成"
                  className={styles.input}
                  disabled={isEdit}
                />
                <small className={styles.hint}>
                  {formData.code ? '用户可以通过输入此代码兑换优惠券' : '留空后只能通过积分兑换，系统会自动生成唯一代码'}
                </small>
              </div>

              <div className={styles.formGroup}>
                <label>优惠券名称 *</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) => updateField('name', e.target.value)}
                  placeholder="优惠券名称"
                  className={styles.input}
                  required
                />
              </div>

              <div className={styles.formGroup}>
                <label>优惠券描述</label>
                <textarea
                  value={formData.description}
                  onChange={(e) => updateField('description', e.target.value)}
                  placeholder="优惠券描述（可选）"
                  className={styles.textarea}
                  rows={3}
                />
              </div>
            </div>
          )}
        </div>

        {/* 折扣设置 */}
        <div className={styles.section}>
          <div className={styles.sectionHeader} onClick={() => toggleSection('discount')}>
            <h3>折扣设置</h3>
            <span className={collapsedSections.discount ? styles.iconCollapsed : styles.iconExpanded}>
              ▼
            </span>
          </div>
          {!collapsedSections.discount && (
            <div className={styles.sectionContent}>
              <div className={styles.formRow}>
                <div className={styles.formGroup}>
                  <label>折扣类型 *</label>
                  <select
                    value={formData.type}
                    onChange={(e) => updateField('type', e.target.value as 'fixed_amount' | 'percentage')}
                    className={styles.select}
                    disabled={isEdit}
                  >
                    <option value="fixed_amount">固定金额</option>
                    <option value="percentage">百分比折扣</option>
                  </select>
                </div>

                <div className={styles.formGroup}>
                  <label>折扣值 * (便士)</label>
                  <input
                    type="number"
                    value={formData.discount_value}
                    onChange={(e) => updateField('discount_value', Number(e.target.value))}
                    placeholder={formData.type === 'percentage' ? '例如: 10 表示 10%' : '例如: 1000 表示 £10'}
                    className={styles.input}
                    min="0"
                    disabled={isEdit}
                  />
                </div>
              </div>

              <div className={styles.formRow}>
                <div className={styles.formGroup}>
                  <label>最低消费金额 (便士)</label>
                  <input
                    type="number"
                    value={formData.min_amount}
                    onChange={(e) => updateField('min_amount', Number(e.target.value))}
                    placeholder="0 表示无限制"
                    className={styles.input}
                    min="0"
                    disabled={isEdit}
                  />
                </div>

                {formData.type === 'percentage' && (
                  <div className={styles.formGroup}>
                    <label>最大折扣金额 (便士)</label>
                    <input
                      type="number"
                      value={formData.max_discount || ''}
                      onChange={(e) => updateField('max_discount', Number(e.target.value) || undefined)}
                      placeholder="留空表示无限制"
                      className={styles.input}
                      min="0"
                      disabled={isEdit}
                    />
                  </div>
                )}
              </div>

              <div className={styles.formGroup}>
                <label>货币</label>
                <select
                  value={formData.currency}
                  onChange={(e) => updateField('currency', e.target.value)}
                  className={styles.select}
                  disabled={isEdit}
                >
                  <option value="GBP">GBP (£)</option>
                  <option value="USD">USD ($)</option>
                  <option value="EUR">EUR (€)</option>
                </select>
              </div>
            </div>
          )}
        </div>

        {/* 使用限制 */}
        <div className={styles.section}>
          <div className={styles.sectionHeader} onClick={() => toggleSection('limits')}>
            <h3>使用限制</h3>
            <span className={collapsedSections.limits ? styles.iconCollapsed : styles.iconExpanded}>
              ▼
            </span>
          </div>
          {!collapsedSections.limits && (
            <div className={styles.sectionContent}>
              <div className={styles.formRow}>
                <div className={styles.formGroup}>
                  <label>总发行量</label>
                  <input
                    type="number"
                    value={formData.total_quantity || ''}
                    onChange={(e) => updateField('total_quantity', Number(e.target.value) || undefined)}
                    placeholder="留空表示无限制"
                    className={styles.input}
                    min="1"
                    disabled={isEdit}
                  />
                </div>

                <div className={styles.formGroup}>
                  <label>每用户限用次数</label>
                  <input
                    type="number"
                    value={formData.per_user_limit}
                    onChange={(e) => updateField('per_user_limit', Number(e.target.value))}
                    className={styles.input}
                    min="1"
                  />
                  <small className={styles.hint}>每个用户最多可以使用此优惠券的次数</small>
                </div>
              </div>

              <div className={styles.formRow}>
                <div className={styles.formGroup}>
                  <label>限用周期</label>
                  <select
                    value={formData.per_user_limit_window}
                    onChange={(e) => updateField('per_user_limit_window', e.target.value as any)}
                    className={styles.select}
                  >
                    <option value="">无限制</option>
                    <option value="day">每天</option>
                    <option value="week">每周</option>
                    <option value="month">每月</option>
                    <option value="year">每年</option>
                  </select>
                </div>

                {formData.per_user_limit_window && (
                  <div className={styles.formGroup}>
                    <label>周期内限用次数</label>
                    <input
                      type="number"
                      value={formData.per_user_per_window_limit || ''}
                      onChange={(e) => updateField('per_user_per_window_limit', Number(e.target.value) || undefined)}
                      className={styles.input}
                      min="1"
                    />
                  </div>
                )}
              </div>

              <div className={styles.formGroup}>
                <label>
                  <input
                    type="checkbox"
                    checked={formData.can_combine}
                    onChange={(e) => updateField('can_combine', e.target.checked)}
                    disabled={isEdit}
                  />
                  允许与其他优惠券叠加使用
                </label>
              </div>
            </div>
          )}
        </div>

        {/* 适用场景 */}
        <div className={styles.section}>
          <div className={styles.sectionHeader} onClick={() => toggleSection('scenarios')}>
            <h3>适用场景</h3>
            <span className={collapsedSections.scenarios ? styles.iconCollapsed : styles.iconExpanded}>
              ▼
            </span>
          </div>
          {!collapsedSections.scenarios && (
            <div className={styles.sectionContent}>
              <div className={styles.formGroup}>
                <label>积分要求</label>
                <input
                  type="number"
                  value={formData.points_required}
                  onChange={(e) => updateField('points_required', Number(e.target.value))}
                  placeholder="0 表示不需要积分"
                  className={styles.input}
                  min="0"
                  disabled={isEdit}
                />
              </div>

              <div className={styles.formGroup}>
                <label>适用场景</label>
                <div className={styles.checkboxGroup}>
                  {APPLICABLE_SCENARIOS.map((scenario) => (
                    <label key={scenario} className={styles.checkboxLabel}>
                      <input
                        type="checkbox"
                        checked={formData.applicable_scenarios.includes(scenario)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            updateField('applicable_scenarios', [...formData.applicable_scenarios, scenario]);
                          } else {
                            updateField('applicable_scenarios', formData.applicable_scenarios.filter(s => s !== scenario));
                          }
                        }}
                        disabled={isEdit}
                      />
                      {scenario}
                    </label>
                  ))}
                </div>
              </div>

              <div className={styles.formGroup}>
                <label>适用任务类型</label>
                <div className={styles.checkboxGroup}>
                  {TASK_TYPES.map((type) => (
                    <label key={type} className={styles.checkboxLabel}>
                      <input
                        type="checkbox"
                        checked={formData.task_types.includes(type)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            updateField('task_types', [...formData.task_types, type]);
                          } else {
                            updateField('task_types', formData.task_types.filter(t => t !== type));
                          }
                        }}
                      />
                      {type}
                    </label>
                  ))}
                </div>
              </div>

              <div className={styles.formGroup}>
                <label>适用地点</label>
                <select
                  multiple
                  value={formData.locations}
                  onChange={(e) => {
                    const selected = Array.from(e.target.selectedOptions, option => option.value);
                    updateField('locations', selected);
                  }}
                  className={styles.selectMultiple}
                  size={6}
                >
                  {CITIES.map((city) => (
                    <option key={city} value={city}>
                      {city}
                    </option>
                  ))}
                </select>
                <small className={styles.hint}>按住 Ctrl/Cmd 可多选</small>
              </div>
            </div>
          )}
        </div>

        {/* 有效期 */}
        <div className={styles.section}>
          <div className={styles.sectionHeader} onClick={() => toggleSection('validity')}>
            <h3>有效期</h3>
            <span className={collapsedSections.validity ? styles.iconCollapsed : styles.iconExpanded}>
              ▼
            </span>
          </div>
          {!collapsedSections.validity && (
            <div className={styles.sectionContent}>
              <div className={styles.formRow}>
                <div className={styles.formGroup}>
                  <label>生效时间 *</label>
                  <input
                    type="datetime-local"
                    value={formData.valid_from}
                    onChange={(e) => updateField('valid_from', e.target.value)}
                    className={styles.input}
                    required
                    disabled={isEdit}
                  />
                </div>

                <div className={styles.formGroup}>
                  <label>失效时间 *</label>
                  <input
                    type="datetime-local"
                    value={formData.valid_until}
                    onChange={(e) => updateField('valid_until', e.target.value)}
                    className={styles.input}
                    required
                  />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </AdminModal>
  );
};

export default CouponFormModal;
