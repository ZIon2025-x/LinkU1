-- 为岗位表添加英语字段
ALTER TABLE job_positions 
ADD COLUMN IF NOT EXISTS title_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS department_en VARCHAR(50),
ADD COLUMN IF NOT EXISTS type_en VARCHAR(20),
ADD COLUMN IF NOT EXISTS location_en VARCHAR(100),
ADD COLUMN IF NOT EXISTS experience_en VARCHAR(50),
ADD COLUMN IF NOT EXISTS salary_en VARCHAR(50),
ADD COLUMN IF NOT EXISTS description_en TEXT,
ADD COLUMN IF NOT EXISTS requirements_en TEXT,
ADD COLUMN IF NOT EXISTS tags_en TEXT;

-- 更新现有数据，添加英语翻译
UPDATE job_positions SET 
  title_en = CASE 
    WHEN title = '前端开发工程师' THEN 'Frontend Developer'
    WHEN title = '后端开发工程师' THEN 'Backend Developer'
    WHEN title = '产品经理' THEN 'Product Manager'
    WHEN title = 'UI/UX 设计师' THEN 'UI/UX Designer'
    WHEN title = '运营专员' THEN 'Operations Specialist'
    WHEN title = '客服专员' THEN 'Customer Service Specialist'
    ELSE title
  END,
  department_en = CASE 
    WHEN department = '技术部' THEN 'Technology'
    WHEN department = '产品部' THEN 'Product'
    WHEN department = '设计部' THEN 'Design'
    WHEN department = '运营部' THEN 'Operations'
    WHEN department = '客服部' THEN 'Customer Service'
    ELSE department
  END,
  type_en = CASE 
    WHEN type = '全职' THEN 'Full-time'
    WHEN type = '兼职' THEN 'Part-time'
    WHEN type = '实习' THEN 'Internship'
    ELSE type
  END,
  location_en = CASE 
    WHEN location = '北京/远程' THEN 'Beijing/Remote'
    WHEN location = '北京' THEN 'Beijing'
    ELSE location
  END,
  experience_en = CASE 
    WHEN experience = '3-5年' THEN '3-5 years'
    WHEN experience = '2-4年' THEN '2-4 years'
    WHEN experience = '1-3年' THEN '1-3 years'
    WHEN experience = '1-2年' THEN '1-2 years'
    ELSE experience
  END,
  salary_en = salary,
  description_en = CASE 
    WHEN title = '前端开发工程师' THEN 'Responsible for frontend development, participating in product design and user experience optimization'
    WHEN title = '后端开发工程师' THEN 'Responsible for backend development, API design and database optimization'
    WHEN title = '产品经理' THEN 'Responsible for product planning and design, user requirement analysis and product iteration'
    WHEN title = 'UI/UX 设计师' THEN 'Responsible for product interface design and user experience optimization'
    WHEN title = '运营专员' THEN 'Responsible for user operations and content operations, improving user activity'
    WHEN title = '客服专员' THEN 'Responsible for user consultation and problem handling, maintaining user relationships'
    ELSE description
  END,
  requirements_en = CASE 
    WHEN title = '前端开发工程师' THEN '["Proficient in React, Vue and other frontend frameworks", "Familiar with TypeScript, ES6+ syntax", "Mobile development experience preferred", "Good code standards and team collaboration skills"]'
    WHEN title = '后端开发工程师' THEN '["Proficient in Python and related frameworks", "Familiar with FastAPI, Django and other Web frameworks", "Database design and optimization experience", "Understanding of microservices architecture and cloud services"]'
    WHEN title = '产品经理' THEN '["Internet product experience", "Familiar with product design process", "Data analysis capabilities", "Platform product experience preferred"]'
    WHEN title = 'UI/UX 设计师' THEN '["Proficient in design tools", "Mobile design experience", "Understanding of design standards and user psychology", "Platform product design experience preferred"]'
    WHEN title = '运营专员' THEN '["Internet operations experience", "Familiar with social media operations", "Data analysis capabilities", "Community operations experience preferred"]'
    WHEN title = '客服专员' THEN '["Good communication skills", "Customer service work experience", "Familiar with online customer service tools", "Patience and responsibility"]'
    ELSE requirements
  END,
  tags_en = CASE 
    WHEN title = '前端开发工程师' THEN '["React", "TypeScript", "Vue", "Frontend"]'
    WHEN title = '后端开发工程师' THEN '["Python", "FastAPI", "PostgreSQL", "Redis"]'
    WHEN title = '产品经理' THEN '["Product Design", "User Research", "Data Analysis", "Product"]'
    WHEN title = 'UI/UX 设计师' THEN '["UI Design", "UX Design", "Figma", "Design"]'
    WHEN title = '运营专员' THEN '["User Operations", "Content Operations", "Data Analysis", "Operations"]'
    WHEN title = '客服专员' THEN '["Customer Service", "Communication Skills", "Problem Solving", "Customer Service"]'
    ELSE tags
  END;
