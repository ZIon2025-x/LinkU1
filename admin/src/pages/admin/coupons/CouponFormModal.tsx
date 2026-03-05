import React from 'react';
import { CouponForm } from './types';

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

const TASK_TYPES: { value: string; label: string }[] = [
  { value: 'tutoring', label: '辅导' },
  { value: 'pet_care', label: '宠物照顾' },
  { value: 'delivery', label: '配送' },
  { value: 'cleaning', label: '清洁' },
  { value: 'moving', label: '搬家' },
  { value: 'tech_support', label: '技术支持' },
  { value: 'translation', label: '翻译' },
  { value: 'design', label: '设计' },
  { value: 'photography', label: '摄影' },
  { value: 'other', label: '其他' },
];

const APPLICABLE_SCENARIOS: { value: string; label: string }[] = [
  { value: 'task_posting', label: '发布任务' },
  { value: 'task_accepting', label: '接受任务' },
  { value: 'expert_service', label: '专家服务' },
  { value: 'all', label: '全部场景' },
];

const ELIGIBILITY_TYPES: { value: string; label: string }[] = [
  { value: '', label: '不限制' },
  { value: 'member', label: '会员专属' },
  { value: 'first_order', label: '首单专属' },
  { value: 'new_user', label: '新用户专属' },
  { value: 'user_type', label: '按用户类型' },
  { value: 'all', label: '全部用户' },
];

const ELIGIBILITY_VALUES: { value: string; label: string }[] = [
  { value: '', label: '—' },
  { value: 'vip', label: 'VIP' },
  { value: 'super', label: 'Super' },
  { value: 'vip,super', label: 'VIP 或 Super' },
];

const LIMIT_WINDOWS: { value: string; label: string }[] = [
  { value: '', label: '不限制' },
  { value: 'day', label: '每天' },
  { value: 'week', label: '每周' },
  { value: 'month', label: '每月' },
  { value: 'year', label: '每年' },
];

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '8px',
  border: '1px solid #ddd',
  borderRadius: '4px',
  marginTop: '5px',
  boxSizing: 'border-box',
};

const labelStyle: React.CSSProperties = {
  display: 'block',
  marginBottom: '5px',
  fontWeight: 'bold',
};

const fieldStyle: React.CSSProperties = {
  marginBottom: '15px',
};

const hintStyle: React.CSSProperties = {
  color: '#666',
  fontSize: '12px',
  marginTop: '5px',
  display: 'block',
};

const fieldsetStyle: React.CSSProperties = {
  border: '1px solid #e0e0e0',
  borderRadius: '6px',
  padding: '15px',
  marginBottom: '20px',
};

const legendStyle: React.CSSProperties = {
  fontWeight: 'bold',
  fontSize: '14px',
  color: '#333',
  padding: '0 8px',
};

const sectionHintStyle: React.CSSProperties = {
  color: '#888',
  fontSize: '12px',
  marginBottom: '12px',
  display: 'block',
};

export const CouponFormModal: React.FC<CouponFormModalProps> = ({
  isOpen,
  isEdit,
  formData,
  loading,
  onClose,
  onSubmit,
  setFormData,
}) => {
  if (!isOpen) return null;

  const updateField = <K extends keyof CouponForm>(field: K, value: CouponForm[K]) => {
    setFormData(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleSubmit = () => {
    if (!formData.name || !formData.valid_from || !formData.valid_until) {
      alert('请填写优惠券名称和有效期');
      return;
    }
    if (formData.discount_value <= 0) {
      alert('请填写折扣金额');
      return;
    }
    if (formData.type === 'percentage' && (formData.discount_value < 1 || formData.discount_value > 10000)) {
      alert('百分比折扣的折扣值必须在 1–10000 之间（0.01%–100%）');
      return;
    }
    if (new Date(formData.valid_until) <= new Date(formData.valid_from)) {
      alert('失效时间必须晚于生效时间');
      return;
    }
    onSubmit();
  };

  const handleClose = () => {
    onClose();
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
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000,
    }}>
      <div style={{
        background: 'white',
        padding: '30px',
        borderRadius: '8px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.3)',
        minWidth: '520px',
        maxWidth: '680px',
        maxHeight: '90vh',
        overflowY: 'auto',
      }}>
        <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>
          {isEdit ? '编辑优惠券' : '创建优惠券'}
        </h3>

        {/* ========== 1. 基本信息 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>基本信息</legend>
          <small style={sectionHintStyle}>留空优惠券代码则只能通过积分兑换或兑换码领取</small>

          <div style={fieldStyle}>
            <label style={labelStyle}>优惠券代码</label>
            <input
              type="text"
              value={formData.code}
              onChange={(e) => updateField('code', e.target.value.toUpperCase())}
              placeholder="留空自动生成"
              disabled={isEdit}
              style={inputStyle}
            />
            <small style={hintStyle}>
              {formData.code ? '用户可以通过输入此代码兑换优惠券' : '留空后系统会自动生成唯一代码'}
            </small>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>
              优惠券名称 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => updateField('name', e.target.value)}
              placeholder="请输入优惠券名称"
              style={inputStyle}
            />
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>描述</label>
            <textarea
              value={formData.description}
              onChange={(e) => updateField('description', e.target.value)}
              placeholder="请输入优惠券描述（可选）"
              rows={3}
              style={{ ...inputStyle, resize: 'vertical' }}
            />
          </div>
        </fieldset>

        {/* ========== 2. 折扣设置 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>折扣设置</legend>
          <small style={sectionHintStyle}>固定金额直接减免；百分比按订单折扣，可设封顶</small>

          <div style={fieldStyle}>
            <label style={labelStyle}>
              折扣类型 <span style={{ color: 'red' }}>*</span>
            </label>
            <select
              value={formData.type}
              onChange={(e) => updateField('type', e.target.value as 'fixed_amount' | 'percentage')}
              disabled={isEdit}
              style={inputStyle}
            >
              <option value="fixed_amount">固定金额</option>
              <option value="percentage">百分比折扣</option>
            </select>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>
              折扣值 {formData.type === 'percentage' ? '(基点)' : '(便士)'} <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="number"
              value={formData.discount_value}
              onChange={(e) => updateField('discount_value', Number(e.target.value))}
              placeholder={formData.type === 'percentage' ? '例如: 1000 表示 10%' : '例如: 1000 表示 £10'}
              min="0"
              disabled={isEdit}
              style={inputStyle}
            />
            <small style={hintStyle}>
              {formData.type === 'percentage'
                ? '基点制：100=1%, 1000=10%, 10000=100%'
                : '便士制：100=£1, 1000=£10'}
            </small>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>最低消费金额 (便士)</label>
            <input
              type="number"
              value={formData.min_amount}
              onChange={(e) => updateField('min_amount', Number(e.target.value))}
              placeholder="0 表示无限制"
              min="0"
              disabled={isEdit}
              style={inputStyle}
            />
          </div>

          {formData.type === 'percentage' && (
            <div style={fieldStyle}>
              <label style={labelStyle}>最大折扣金额 (便士)</label>
              <input
                type="number"
                value={formData.max_discount || ''}
                onChange={(e) => updateField('max_discount', Number(e.target.value) || undefined)}
                placeholder="留空表示无限制"
                min="0"
                disabled={isEdit}
                style={inputStyle}
              />
            </div>
          )}
        </fieldset>

        {/* ========== 3. 发放规则 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>发放规则</legend>
          <small style={sectionHintStyle}>控制谁能领、怎么领、领多少</small>

          <div style={fieldStyle}>
            <label style={labelStyle}>分发方式</label>
            <select
              value={formData.distribution_type}
              onChange={(e) => updateField('distribution_type', e.target.value as 'public' | 'code_only')}
              style={inputStyle}
            >
              <option value="public">公开展示</option>
              <option value="code_only">仅限兑换码</option>
            </select>
            <small style={hintStyle}>
              {formData.distribution_type === 'code_only'
                ? '不会在用户可领券列表中展示，只能通过推广码领取'
                : '用户在积分页或券列表中可直接看到并领取'}
            </small>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>积分要求</label>
            <input
              type="number"
              value={formData.points_required}
              onChange={(e) => updateField('points_required', Number(e.target.value))}
              placeholder="0 表示不需要积分"
              min="0"
              disabled={isEdit}
              style={inputStyle}
            />
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>总发行量</label>
            <input
              type="number"
              value={formData.total_quantity || ''}
              onChange={(e) => updateField('total_quantity', Number(e.target.value) || undefined)}
              placeholder="留空表示无限制"
              min="1"
              style={inputStyle}
            />
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>每用户限用次数</label>
            <input
              type="number"
              value={formData.per_user_limit}
              onChange={(e) => updateField('per_user_limit', Number(e.target.value))}
              min="1"
              style={inputStyle}
            />
            <small style={hintStyle}>每个用户最多可以使用此优惠券的次数</small>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>资格类型</label>
            <select
              value={formData.eligibility_type}
              onChange={(e) => updateField('eligibility_type', e.target.value as CouponForm['eligibility_type'])}
              style={inputStyle}
            >
              {ELIGIBILITY_TYPES.map((opt) => (
                <option key={opt.value} value={opt.value}>{opt.label}</option>
              ))}
            </select>
            <small style={hintStyle}>会员专属仅 VIP/Super 用户可领取</small>
          </div>

          {(formData.eligibility_type === 'user_type' || formData.eligibility_type === 'member') && (
            <div style={fieldStyle}>
              <label style={labelStyle}>资格值</label>
              <select
                value={formData.eligibility_value}
                onChange={(e) => updateField('eligibility_value', e.target.value as CouponForm['eligibility_value'])}
                style={inputStyle}
              >
                {ELIGIBILITY_VALUES.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
          )}
        </fieldset>

        {/* ========== 4. 周期限制 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>周期限制</legend>
          <small style={sectionHintStyle}>可叠加使用，如"每月限领1次 + 每日限领1次"</small>

          <div style={{ ...fieldStyle, display: 'flex', gap: '15px', flexWrap: 'wrap' }}>
            <div style={{ flex: 1, minWidth: '140px' }}>
              <label style={labelStyle}>限领周期</label>
              <select
                value={formData.per_user_limit_window}
                onChange={(e) => updateField('per_user_limit_window', e.target.value as CouponForm['per_user_limit_window'])}
                style={inputStyle}
              >
                {LIMIT_WINDOWS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{opt.label}</option>
                ))}
              </select>
            </div>
            {formData.per_user_limit_window && (
              <div style={{ flex: 1, minWidth: '140px' }}>
                <label style={labelStyle}>每周期限领次数</label>
                <input
                  type="number"
                  value={formData.per_user_per_window_limit ?? ''}
                  onChange={(e) => updateField('per_user_per_window_limit', e.target.value ? Number(e.target.value) : undefined)}
                  placeholder="例如: 1"
                  min="1"
                  style={inputStyle}
                />
              </div>
            )}
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>每日限领次数</label>
            <input
              type="number"
              value={formData.per_day_limit ?? ''}
              onChange={(e) => updateField('per_day_limit', e.target.value ? Number(e.target.value) : undefined)}
              placeholder="留空表示不限制"
              min="1"
              style={inputStyle}
            />
          </div>
        </fieldset>

        {/* ========== 5. 使用条件 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>使用条件</legend>
          <small style={sectionHintStyle}>不选 = 不限制</small>

          <div style={fieldStyle}>
            <label style={labelStyle}>适用场景</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', marginTop: '5px' }}>
              {APPLICABLE_SCENARIOS.map((scenario) => (
                <label key={scenario.value} style={{ display: 'flex', alignItems: 'center', gap: '5px', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={formData.applicable_scenarios.includes(scenario.value)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        updateField('applicable_scenarios', [...formData.applicable_scenarios, scenario.value]);
                      } else {
                        updateField('applicable_scenarios', formData.applicable_scenarios.filter(s => s !== scenario.value));
                      }
                    }}
                    disabled={isEdit}
                    style={{ width: '16px', height: '16px', cursor: 'pointer' }}
                  />
                  {scenario.label}
                </label>
              ))}
            </div>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>适用任务类型</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', marginTop: '5px' }}>
              {TASK_TYPES.map((type) => (
                <label key={type.value} style={{ display: 'flex', alignItems: 'center', gap: '5px', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={formData.task_types.includes(type.value)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        updateField('task_types', [...formData.task_types, type.value]);
                      } else {
                        updateField('task_types', formData.task_types.filter(t => t !== type.value));
                      }
                    }}
                    style={{ width: '16px', height: '16px', cursor: 'pointer' }}
                  />
                  {type.label}
                </label>
              ))}
            </div>
            <small style={hintStyle}>不选表示不限任务类型</small>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>排除的任务类型</label>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', marginTop: '5px' }}>
              {TASK_TYPES.map((type) => (
                <label key={type.value} style={{ display: 'flex', alignItems: 'center', gap: '5px', cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={formData.excluded_task_types.includes(type.value)}
                    onChange={(e) => {
                      if (e.target.checked) {
                        updateField('excluded_task_types', [...formData.excluded_task_types, type.value]);
                      } else {
                        updateField('excluded_task_types', formData.excluded_task_types.filter(t => t !== type.value));
                      }
                    }}
                    style={{ width: '16px', height: '16px', cursor: 'pointer' }}
                  />
                  {type.label}
                </label>
              ))}
            </div>
            <small style={hintStyle}>勾选的任务类型不可使用此优惠券</small>
          </div>

          <div style={{ ...fieldStyle, display: 'flex', gap: '15px', flexWrap: 'wrap' }}>
            <div style={{ flex: 1, minWidth: '140px' }}>
              <label style={labelStyle}>最低任务金额 (便士)</label>
              <input
                type="number"
                value={formData.min_task_amount ?? ''}
                onChange={(e) => updateField('min_task_amount', e.target.value ? Number(e.target.value) : undefined)}
                placeholder="留空不限制"
                min="0"
                style={inputStyle}
              />
            </div>
            <div style={{ flex: 1, minWidth: '140px' }}>
              <label style={labelStyle}>最高任务金额 (便士)</label>
              <input
                type="number"
                value={formData.max_task_amount ?? ''}
                onChange={(e) => updateField('max_task_amount', e.target.value ? Number(e.target.value) : undefined)}
                placeholder="留空不限制"
                min="0"
                style={inputStyle}
              />
            </div>
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>适用地点</label>
            <select
              multiple
              value={formData.locations}
              onChange={(e) => {
                const selected = Array.from(e.target.selectedOptions, option => option.value);
                updateField('locations', selected);
              }}
              style={{ ...inputStyle, height: '120px' }}
            >
              {CITIES.map((city) => (
                <option key={city} value={city}>
                  {city}
                </option>
              ))}
            </select>
            <small style={hintStyle}>按住 Ctrl/Cmd 可多选</small>
          </div>
        </fieldset>

        {/* ========== 6. 有效期与高级 ========== */}
        <fieldset style={fieldsetStyle}>
          <legend style={legendStyle}>有效期与高级</legend>

          <div style={fieldStyle}>
            <label style={labelStyle}>
              生效时间 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="datetime-local"
              value={formData.valid_from}
              onChange={(e) => updateField('valid_from', e.target.value)}
              disabled={isEdit}
              style={inputStyle}
            />
          </div>

          <div style={fieldStyle}>
            <label style={labelStyle}>
              失效时间 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="datetime-local"
              value={formData.valid_until}
              onChange={(e) => updateField('valid_until', e.target.value)}
              style={inputStyle}
            />
          </div>

          <div style={{ marginBottom: '20px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={formData.can_combine}
                onChange={(e) => updateField('can_combine', e.target.checked)}
                disabled={isEdit}
                style={{ width: '18px', height: '18px', cursor: 'pointer' }}
              />
              <span style={{ fontWeight: 'bold' }}>允许与其他优惠券叠加使用</span>
            </label>
          </div>
        </fieldset>

        {/* 按钮 */}
        <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
          <button
            onClick={handleClose}
            disabled={loading}
            style={{
              padding: '10px 20px',
              border: '1px solid #ddd',
              background: 'white',
              color: '#666',
              borderRadius: '4px',
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.6 : 1,
            }}
          >
            取消
          </button>
          <button
            onClick={handleSubmit}
            disabled={loading}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: '#007bff',
              color: 'white',
              borderRadius: '4px',
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.6 : 1,
            }}
          >
            {loading ? '提交中...' : isEdit ? '更新' : '创建'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default CouponFormModal;
