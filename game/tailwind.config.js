/** @type {import('tailwindcss').Config} */
//
// The original game uses `bg-current/80`, `border-current/30` etc. all over.
// Tailwind 3.x cannot emit opacity modifiers for the `currentColor` keyword
// (it has no rgb() form to inject alpha into), so these classes silently fail
// to generate. We add them via a plugin using color-mix(), which works in all
// modern browsers (Chrome 111+ / Safari 16.4+ / Firefox 113+).
const OPACITIES = [5, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95];

export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: { extend: {} },
  plugins: [
    function ({ addUtilities }) {
      const utils = {};
      for (const o of OPACITIES) {
        const c = `color-mix(in srgb, currentColor ${o}%, transparent)`;
        utils[`.bg-current\\/${o}`] = { 'background-color': c };
        utils[`.border-current\\/${o}`] = { 'border-color': c };
        utils[`.text-current\\/${o}`] = { color: c };
        utils[`.hover\\:bg-current\\/${o}:hover`] = { 'background-color': c };
        utils[`.hover\\:border-current\\/${o}:hover`] = { 'border-color': c };
      }
      addUtilities(utils);
    },
  ],
};
