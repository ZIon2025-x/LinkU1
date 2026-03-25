-- 迁移 133：更新法律文档 — 披露 AI 对话分析与用户画像
-- 更新隐私政策和用户协议中关于 AI 数据处理的条款，
-- 明确说明 AI 助手从对话中提取用户画像（兴趣、技能、阶段、偏好）及其用途。

-- ===== zh 隐私政策：更新 dataCollection.aiChatData =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{dataCollection,aiChatData}',
  $VAL$"AI 助手数据：当您使用平台 AI 助手「Linker」时，我们收集您的对话内容、查询记录和交互数据。此外，AI 助手会自动分析对话内容，提取您的兴趣偏好（如关注的任务类别）、技能特长、生活阶段信号（如搬家、毕业等）及服务偏好等信息，形成用户画像数据。这些数据用于：（1）提供和改进 AI 助手服务；（2）优化回答质量与个性化推荐；（3）驱动平台任务推荐算法，为您匹配更相关的任务与服务；（4）保障服务安全。用户画像数据以汇总形式存储，不包含原始对话文本。AI 对话数据通常保留不超过 12 个月，用户画像数据在您的账户存续期内保留，账户注销时一并删除。您可在设置中退出基于 AI 分析的个性化推荐。我们不会将 AI 对话或画像数据用于营销或与第三方共享（合同履行/合法利益）。"$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- ===== zh 隐私政策：更新 dataCollection.recommendationData =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{dataCollection,recommendationData}',
  $VAL$"推荐系统数据：我们收集浏览与搜索行为、交互数据（您查看、接受、跳过或收藏的任务/商品）、偏好与历史数据，以及通过 AI 助手对话分析得出的用户画像数据（兴趣、技能、需求预测等），以提供个性化任务与内容推荐。您可在设置中退出个性化推荐（合法利益）。"$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'zh';

-- ===== zh 用户协议：更新 aiServiceTerms.dataHandling =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{aiServiceTerms,dataHandling}',
  $VAL$"数据处理：AI 助手处理的用户对话数据用于提供和改进服务。AI 助手会自动从对话中分析您的兴趣偏好、技能特长、生活阶段及服务偏好，生成用户画像数据，该数据将用于优化 AI 回答质量及平台任务推荐算法。用户画像数据以汇总形式存储，不包含原始对话文本，您可在设置中退出基于 AI 分析的个性化推荐。平台不会将 AI 对话或画像数据用于与服务无关的目的。AI 对话数据的存储与保护适用本平台《隐私通知》的相关规定。详见下方《隐私通知》中的「AI 助手数据」部分。"$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'terms' AND lang = 'zh';

-- ===== en 隐私政策：更新 dataCollection.aiChatData =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{dataCollection,aiChatData}',
  $VAL$"AI Assistant Data: When you use the platform AI assistant 'Linker', we collect your conversation content, query records, and interaction data. Additionally, the AI assistant automatically analyses conversation content to extract your interest preferences (such as task categories of interest), skills, life stage signals (such as moving, graduation, etc.), and service preferences to build a user profile. This data is used for: (1) Providing and improving the AI assistant service; (2) Optimising response quality and personalised recommendations; (3) Powering the platform's task recommendation algorithm to match you with more relevant tasks and services; (4) Ensuring service security. User profile data is stored in aggregated form and does not contain original conversation text. AI conversation data is typically retained for no more than 12 months; user profile data is retained for the duration of your account and deleted upon account cancellation. You can opt out of AI-analysis-based personalised recommendations in settings. We do not use AI conversation or profile data for marketing or share it with third parties (contract performance/legitimate interests)."$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- ===== en 隐私政策：更新 dataCollection.recommendationData =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{dataCollection,recommendationData}',
  $VAL$"Recommendation System Data: We collect browsing and search behaviour, interaction data (tasks/items you view, accept, skip or favourite), preference and historical data, as well as user profile data derived from AI assistant conversation analysis (interests, skills, predicted needs, etc.), to provide personalised task and content recommendations. You can opt out of personalised recommendations in settings (legitimate interests)."$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'privacy' AND lang = 'en';

-- ===== en 用户协议：更新 aiServiceTerms.dataHandling =====
UPDATE legal_documents
SET content_json = jsonb_set(
  content_json,
  '{aiServiceTerms,dataHandling}',
  $VAL$"Data Handling: User conversation data processed by the AI Assistant is used to provide and improve services. The AI Assistant automatically analyses your conversations to extract interest preferences, skills, life stages, and service preferences to generate user profile data. This profile data is used to optimise AI response quality and the platform's task recommendation algorithm. User profile data is stored in aggregated form and does not contain original conversation text. You can opt out of AI-analysis-based personalised recommendations in settings. The platform will not use AI conversation or profile data for purposes unrelated to the service. Storage and protection of AI conversation data is subject to the relevant provisions of this platform's Privacy Notice. See the 'AI Assistant Data' section in the Privacy Notice below."$VAL$::jsonb
),
    updated_at = NOW()
WHERE type = 'terms' AND lang = 'en';
