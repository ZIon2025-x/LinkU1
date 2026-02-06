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
        minWidth: '500px',
        maxWidth: '600px',
        maxHeight: '90vh',
        overflowY: 'auto',
      }}>
        <h3 style={{ margin: '0 0 20px 0', color: '#333' }}>
          {isEdit ? '编辑优惠券' : '创建优惠券'}
        </h3>

        {/* 优惠券代码 */}
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
            {formData.code ? '用户可以通过输入此代码兑换优惠券' : '留空后只能通过积分兑换，系统会自动生成唯一代码'}
          </small>
        </div>

        {/* 优惠券名称 */}
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

        {/* 优惠券描述 */}
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

        {/* 折扣类型 */}
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

        {/* 折扣值 */}
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

        {/* 最低消费金额 */}
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

        {/* 最大折扣金额（仅百分比类型） */}
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

        {/* 总发行量 */}
        <div style={fieldStyle}>
          <label style={labelStyle}>总发行量</label>
          <input
            type="number"
            value={formData.total_quantity || ''}
            onChange={(e) => updateField('total_quantity', Number(e.target.value) || undefined)}
            placeholder="留空表示无限制"
            min="1"
            disabled={isEdit}
            style={inputStyle}
          />
        </div>

        {/* 每用户限用次数 */}
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

        {/* 积分要求 */}
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

        {/* 适用场景 */}
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

        {/* 适用任务类型 */}
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
        </div>

        {/* 适用地点 */}
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

        {/* 生效时间 */}
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

        {/* 失效时间 */}
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

        {/* 允许叠加 */}
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
