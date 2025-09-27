module.exports = {
  extends: [
    'react-app',
    'react-app/jest'
  ],
  rules: {
    // 忽略未使用变量的警告
    '@typescript-eslint/no-unused-vars': 'off',
    // 忽略 React Hooks 依赖警告
    'react-hooks/exhaustive-deps': 'off',
    // 忽略重复定义警告
    '@typescript-eslint/no-redeclare': 'off',
    // 忽略可访问性警告
    'jsx-a11y/anchor-is-valid': 'off'
  }
};
