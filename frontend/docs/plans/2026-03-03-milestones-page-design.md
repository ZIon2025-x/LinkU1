# Milestones Page Design

## Overview
Company milestones/timeline page to build user trust and corporate image. Displays key events in Link2Ur's history — founding, user growth, activities, feature launches, etc.

## Route
`/:lang/milestones` — public, no auth required.

## Page Structure

### 1. Hero Banner
- Gradient background (brand blue)
- Large title: "Our Journey" / "我们的历程"
- Subtitle: company vision/slogan
- Responsive: smaller text on mobile

### 2. Vertical Timeline
- Central vertical line with dot markers
- Event cards alternate left/right on desktop
- Mobile: single-column, all cards on right side of the line
- Each card contains: icon, date, title, description
- Scroll-triggered fade-in animation via IntersectionObserver + CSS keyframes
- Data: hardcoded bilingual array in component

### 3. Stats Section
- 3-4 key numbers (users, tasks completed, cities covered, etc.)
- Count-up animation on scroll into view
- Grid layout, responsive

## Technical Details
- **Files**: `pages/Milestones.tsx`, `pages/Milestones.module.css`
- **Data source**: Hardcoded array with `{ date, icon, titleEn, titleZh, descriptionEn, descriptionZh }` objects
- **i18n**: Switch between en/zh fields based on `useLanguage().language`
- **UI components**: Ant Design Typography, icons from `@ant-design/icons`
- **CSS approach**: CSS Modules (consistent with other pages)
- **Responsive**: `isMobile` state via `window.innerWidth < 768`
- **Animation**: CSS `@keyframes fadeInUp` + `IntersectionObserver` for scroll reveal
- **Shared components**: SEOHead, HamburgerMenu, NotificationButton, Footer

## Out of Scope
- No backend API
- No admin editing
- No images (icons only)
- No scroll parallax effects
