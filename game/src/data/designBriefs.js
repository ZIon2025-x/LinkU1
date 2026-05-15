// Link2Ur AI 设计单 · 客户简介解码 minigame 数据
//
// 每个 brief = 1 个客户 case,4 步选择 (intent / mood / palette / format)。
// 每步 4 选项,1 正确 + 3 典型失败。最终评分 = 答对数。
//
// **难度线性**:
// · Phase 1 (W2-15):brief 表述直白,正确答最显眼。
// · Phase 2 (W16-30):带隐喻 / 多义 / 客户矛盾要求 (e.g. "便宜但不要 cheap")。
// · Phase 3 (W30+):客户挑剔,wrong option 也 plausible。

// ── 配色快捷 swatch 集合 ──
const PALETTES = {
  cream:    { name: '柔奶咖', swatches: ['#f5e6d3','#d4a574','#a67c52','#5a4332'], desc: '温柔 + 复古' },
  pop:      { name: 'Y2K Pop', swatches: ['#ff6bb5','#ffe156','#56d8ff','#a070ff'], desc: '荧光糖果 · 偏 cheap' },
  moody:    { name: '深夜黑金', swatches: ['#1a1612','#3a3028','#d4b070','#8b7355'], desc: '编辑级 · 偏 dark' },
  mint:     { name: '薄荷渐变', swatches: ['#d4f4dd','#86d4a6','#54a87b','#2d6448'], desc: 'wellness · 不甜' },
  pastel:   { name: '马卡龙粉', swatches: ['#fde2e4','#fad2cf','#f5b7b1','#cd6155'], desc: '甜 · 少女' },
  earth:    { name: '土陶', swatches: ['#e8d5b5','#c89878','#8a5a44','#3e2c1e'], desc: '手工感 · 不商业' },
  navy:     { name: '海军蓝白', swatches: ['#1e3a5f','#3e6a8f','#a0bfd9','#f5f5f5'], desc: '商务 · 信任感' },
  sunset:   { name: '夕阳橙', swatches: ['#ffe5b4','#ffb573','#ff7e5f','#a83a3a'], desc: '热闹 · 餐饮' },
  forest:   { name: '森林绿', swatches: ['#2d3a2e','#4a6051','#86a982','#dde4dc'], desc: '自然 · sustainability' },
  monochrome:{ name: '极简灰', swatches: ['#ffffff','#dadada','#666666','#1a1a1a'], desc: '极简 · 高级' },
  warm:     { name: '暖橘咖', swatches: ['#fff4e6','#ffcc99','#cc7a52','#5e2e1f'], desc: '咖啡馆温暖' },
  cool:     { name: '冷青蓝', swatches: ['#e5f2f5','#a8c8d0','#5a8a9e','#1e3a4a'], desc: '冷静 · 科技' },
  vivid:    { name: '撞色亮', swatches: ['#ff3b3b','#ffd700','#3bd6ff','#1a1a1a'], desc: '抓眼 · 但廉价' },
  retro:    { name: '复古海报', swatches: ['#e8d3a0','#c45528','#5a3825','#1c1814'], desc: '70s · 怀旧' },
  ethereal: { name: '清透虚白', swatches: ['#f0eef5','#cfc7e5','#8b7ec0','#3a2f5e'], desc: '梦幻 · spiritual' },
};

// ── 共用 mood / format option 类型 ──
const MOOD_OPTIONS = {
  warm_nostalgic: '温暖怀旧 · "妈妈的厨房"',
  bright_playful: '明亮俏皮 · "周末野餐"',
  moody_editorial: '冷静编辑级 · "深夜 cocktail bar"',
  soft_dreamy: '柔软梦幻 · "ins 网红打卡"',
  minimal_luxe: '极简高级 · "MUJI x APPLE"',
  raw_authentic: '粗糙真实 · "vlog 原片感"',
  energetic_youth: '青春跳动 · "Z 世代"',
  serene_wellness: '宁静治愈 · "瑜伽 retreat"',
  bold_punk: '叛逆撞色 · "Y2K club"',
  professional_trust: '专业可信 · "B2B office"',
};

const FORMAT_OPTIONS = {
  ig_square: 'IG 1:1 方图 · 主 feed 用',
  ig_story:  'IG Story 9:16 · 24h 弹幕',
  poster_a3: 'A3 海报 · 实体张贴',
  banner_wide: '横幅 banner · 公众号头图',
  reel_vertical: '小红书竖图 3:4',
  carousel: 'IG / 红书 carousel 多图',
  brand_kit: '完整 brand kit · logo + 字体 + 模板',
  poster_a1: 'A1 大海报 · 节庆主视觉',
};

export const DESIGN_BRIEFS = [
  // ════════════════ Phase 1 · W2-15 (6 briefs) ════════════════
  // 表述直白,正确选项明显。
  {
    id: 'brief_p1_tang_shui',
    phase: 1,
    client: { name: '小芳', emoji: '🍡', desc: '糖水铺主理人 · 30 岁' },
    subject: '糖水铺七夕 IG post',
    reward: 50,
    brief: '"我那个糖水铺子要做七夕的 IG post，要那种治愈系小红书爆款感哎 ❤️ 颜色要温柔一点，不要太甜了显得 cheap，但也不要太暗显得 sad。预算 £60 谢谢～"',
    steps: [
      {
        q: '她真正要的是?',
        options: [
          { text: '"七夕 + 温馨家庭感的氛围照"', correct: true, why: '七夕 + 糖水铺 = 情侣聚餐的怀旧感' },
          { text: '"促销折扣大字 + 优惠码"', correct: false, why: '她没说要 sale,加 sale 会破坏氛围' },
          { text: '"恋爱情侣亲密照"', correct: false, why: '太露骨,小红书算法会限流' },
          { text: '"产品 close-up + 价格清单"', correct: false, why: '她说"治愈感"不是 menu 卡' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.warm_nostalgic, correct: true, why: '"治愈" 中文等于这种暖怀旧' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '太跳,不是糖水的 vibe' },
          { text: MOOD_OPTIONS.moody_editorial, correct: false, why: '太暗,客户说不要 sad' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '完全错向' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.cream.name, paletteId: 'cream', correct: true, why: '温柔 + 复古 + 不甜不暗' },
          { text: PALETTES.pop.name, paletteId: 'pop', correct: false, why: '客户说不要 cheap' },
          { text: PALETTES.moody.name, paletteId: 'moody', correct: false, why: '太暗 / 像 cocktail bar' },
          { text: PALETTES.mint.name, paletteId: 'mint', correct: false, why: '不是七夕 vibe' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.reel_vertical, correct: true, why: '小红书主战场 = 3:4 竖图' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'IG 方图,但她说"小红书"' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅在小红书显示会被裁' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: '单 post 不需要整套 kit' },
        ],
      },
    ],
  },
  {
    id: 'brief_p1_bubble_tea',
    phase: 1,
    client: { name: '阿凯', emoji: '🧋', desc: '奶茶店学生兼职合伙人 · 22 岁' },
    subject: '校园奶茶店开业 IG',
    reward: 45,
    brief: '"哥们 / 姐妹儿 我们下周校园奶茶店开业 想搞个 IG post 给同学们看 要那种 \'年轻人就要喝奶茶\' 的感觉。预算 £50 帮帮忙。"',
    steps: [
      {
        q: '他真正要传达的核心信息?',
        options: [
          { text: '"开业了 + 学生氛围 + 第一杯 buy one get one"', correct: true, why: '校园开业必含优惠 hook' },
          { text: '"高端手工茶艺"', correct: false, why: '不是路线,他要 cheap & happy' },
          { text: '"严肃公司声明"', correct: false, why: '完全错' },
          { text: '"暗黑 cocktail vibe"', correct: false, why: '错风格' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.energetic_youth, correct: true, why: '校园 + Z 世代' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '不是 MUJI 客户群' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: '太严肃' },
          { text: MOOD_OPTIONS.serene_wellness, correct: false, why: '奶茶 ≠ wellness' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: true, why: '抓眼撞色 = 校园开业' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '极简对学生没有 stopping power' },
          { text: PALETTES.earth.name, paletteId: 'earth', correct: false, why: '土陶 = 手工咖啡馆,不是奶茶' },
          { text: PALETTES.navy.name, paletteId: 'navy', correct: false, why: '商务感不对' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.ig_story, correct: true, why: 'Story 9:16 短期 hype 最有效' },
          { text: FORMAT_OPTIONS.poster_a3, correct: false, why: '实体海报 OK 但不是 IG post' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: '太 over-scope' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅 IG 显示差' },
        ],
      },
    ],
  },
  {
    id: 'brief_p1_chinatown_market',
    phase: 1,
    client: { name: '王阿姨', emoji: '🥬', desc: 'Chinatown 华人超市老板娘 · 55 岁' },
    subject: '冬至饺子粉 IG 推广',
    reward: 40,
    brief: '"小同学 我超市冬至要推自磨饺子粉 你帮我做个 IG 让北区华人看到 我儿子说要那种很有中国年味儿的 不要太年轻 我们客户是 40+ 阿姨们。"',
    steps: [
      {
        q: '核心受众 + 信息?',
        options: [
          { text: '"40+ 华人妈妈 + 冬至传统 + 自磨饺子粉 nostalgic"', correct: true, why: '客户已经说清楚了' },
          { text: '"Z 世代留学生想吃饺子"', correct: false, why: '错受众' },
          { text: '"高端 fine dining 食材"', correct: false, why: '错路线' },
          { text: '"通用便利店 sale"', correct: false, why: '失去 nostalgic 卖点' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.warm_nostalgic, correct: true, why: '冬至 + 阿姨 = 怀旧家庭' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '阿姨不吃极简' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '太年轻' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '完全错' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.warm.name, paletteId: 'warm', correct: true, why: '暖橘咖 = 家里饺子 + 红灯笼' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '极简灰阿姨看不出"中国年味"' },
          { text: PALETTES.cool.name, paletteId: 'cool', correct: false, why: '冷色 = 冷,不是冬至' },
          { text: PALETTES.mint.name, paletteId: 'mint', correct: false, why: 'wellness 调子不对' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.ig_square, correct: true, why: '阿姨主要看 IG/微信 1:1' },
          { text: FORMAT_OPTIONS.reel_vertical, correct: false, why: '小红书她客户用得少' },
          { text: FORMAT_OPTIONS.poster_a1, correct: false, why: 'A1 海报 over-scope' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope' },
        ],
      },
    ],
  },
  {
    id: 'brief_p1_yoga_studio',
    phase: 1,
    client: { name: 'Sarah Lin', emoji: '🧘', desc: 'Hackney 瑜伽教室创始人 · 28 岁' },
    subject: '冬季 21 天 challenge 招募',
    reward: 55,
    brief: '"Hi! We\'re launching a 21-day winter challenge — looking for an IG post that feels calm and inviting, NOT another bootcamp shouty thing. Our community is mostly 25-35 year-old women who burnt out at corporate jobs. Budget £60."',
    steps: [
      {
        q: '客户 anti-pattern 是?',
        options: [
          { text: '"宁静邀请感,反 bootcamp 喊麦"', correct: true, why: '她明确说 NOT shouty' },
          { text: '"高强度 \'30 days transform\' 喊麦"', correct: false, why: '她拒绝这个' },
          { text: '"健身房 hardcore"', correct: false, why: '同上' },
          { text: '"奢侈品 luxury 大牌"', correct: false, why: '错路线' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.serene_wellness, correct: true, why: '宁静治愈 = burnout 群 default' },
          { text: MOOD_OPTIONS.energetic_youth, correct: false, why: '能量过头' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '完全错' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: '太 B2B' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.mint.name, paletteId: 'mint', correct: true, why: 'wellness default · 不甜不暗' },
          { text: PALETTES.pop.name, paletteId: 'pop', correct: false, why: '荧光 = bootcamp,她拒绝了' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色太 aggressive' },
          { text: PALETTES.warm.name, paletteId: 'warm', correct: false, why: '暖橙偏咖啡馆不是 studio' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.carousel, correct: true, why: 'Carousel 10 图,日程 + 引言 + CTA = 完整 story' },
          { text: FORMAT_OPTIONS.ig_story, correct: false, why: 'Story 24h 消失,21 天 challenge 信息要 evergreen' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅 IG 显示差' },
          { text: FORMAT_OPTIONS.poster_a1, correct: false, why: '物理海报 over-scope' },
        ],
      },
    ],
  },
  {
    id: 'brief_p1_book_club',
    phase: 1,
    client: { name: '李同学', emoji: '📚', desc: 'CSSA 读书会发起人 · 23 岁' },
    subject: '中文读书会招新',
    reward: 35,
    brief: '"我搞个伦敦中文读书会 想招 12 个人 每两周读一本 我想要那种安静的咖啡馆感 不要 CSSA 那种喊麦感 但也不要太 cold。预算 £40 学生价帮个忙。"',
    steps: [
      {
        q: '关键 tension?',
        options: [
          { text: '"安静咖啡馆 + 温度 / 不冷"', correct: true, why: '客户两面要的精准中间' },
          { text: '"高调艺术 vibes"', correct: false, why: '过头' },
          { text: '"促销 + 限时折扣"', correct: false, why: '读书会不收钱不需要折扣' },
          { text: '"完全 minimal 性冷淡"', correct: false, why: '她说"不要太 cold"' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.warm_nostalgic, correct: true, why: '咖啡馆 + 不冷 = 温暖' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: 'MUJI cold' },
          { text: MOOD_OPTIONS.energetic_youth, correct: false, why: 'CSSA 喊麦感' },
          { text: MOOD_OPTIONS.moody_editorial, correct: false, why: '太 dark' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.warm.name, paletteId: 'warm', correct: true, why: '暖橘咖 = 咖啡馆温度 ✓' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '太 cold' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色 = CSSA 喊麦' },
          { text: PALETTES.pastel.name, paletteId: 'pastel', correct: false, why: '少女粉跟读书会调子不对' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.ig_square, correct: true, why: 'IG 方图 + WeChat moments 通用' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅显示差' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope' },
          { text: FORMAT_OPTIONS.poster_a1, correct: false, why: '物理海报学生价不值' },
        ],
      },
    ],
  },
  {
    id: 'brief_p1_dumpling_pop',
    phase: 1,
    client: { name: 'Alice Wong', emoji: '🥟', desc: 'Borough Market 饺子 pop-up · 32 岁' },
    subject: '周末 pop-up 招客',
    reward: 60,
    brief: '"This Saturday I\'m doing a dumpling pop-up at Borough Market. Need something bright that catches eyes across the market square — locals walking past should stop. Budget £70."',
    steps: [
      {
        q: '关键约束?',
        options: [
          { text: '"远处可见 + 鲜亮 + 抓注意力 3 秒内"', correct: true, why: '"catches eyes across square" 直接答案' },
          { text: '"高级灰极简性冷淡"', correct: false, why: '远处看不到' },
          { text: '"复杂手绘细节"', correct: false, why: '3 秒抓不到注意' },
          { text: '"文字密集 menu"', correct: false, why: '不是 menu 卡' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.bright_playful, correct: true, why: '明亮抓眼 + market 周末' },
          { text: MOOD_OPTIONS.moody_editorial, correct: false, why: 'dark 远处看不到' },
          { text: MOOD_OPTIONS.serene_wellness, correct: false, why: 'wellness 没 stopping power' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '极简看不见' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.sunset.name, paletteId: 'sunset', correct: true, why: '夕阳橙 = 食物 + 远处可见' },
          { text: PALETTES.cream.name, paletteId: 'cream', correct: false, why: '柔奶咖远处看不到' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '极简灰远处更看不到' },
          { text: PALETTES.cool.name, paletteId: 'cool', correct: false, why: '冷色 = 不食物' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.poster_a3, correct: true, why: '实体 A3 钉在摊位前最有效' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'IG post 不直接 catch market 路过的人' },
          { text: FORMAT_OPTIONS.ig_story, correct: false, why: 'Story 同上' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope' },
        ],
      },
    ],
  },

  // ════════════════ Phase 2 · W16-30 (5 briefs) ════════════════
  // 客户开始有自相矛盾的需求 / 隐喻 / 行业内黑话
  {
    id: 'brief_p2_startup_pitch',
    phase: 2,
    client: { name: 'David Chen', emoji: '💼', desc: 'AI startup founder · YC W24 校友' },
    subject: 'Series A pitch deck cover',
    reward: 120,
    brief: '"We\'re raising Series A from US VCs. The cover slide needs to feel both technical and human — we\'re B2B SaaS for hospitals but our pitch is humanist. Think Notion but more serious. Definitely not generic SaaS blue."',
    steps: [
      {
        q: '关键矛盾 needle 怎么穿?',
        options: [
          { text: '"温暖人文感 + 内核科技 + 非典型 SaaS"', correct: true, why: '客户说"both"+"not generic SaaS blue"' },
          { text: '"全黑加冷蓝 = generic SaaS"', correct: false, why: '他说 NOT generic SaaS blue' },
          { text: '"纯白 + 大字 abstract"', correct: false, why: '少了 human 这一面' },
          { text: '"医院主题红十字"', correct: false, why: '太直白且 medical 老气' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.minimal_luxe, correct: true, why: 'Notion 引用 = 极简但温度' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: 'B2B 标准 = 他说的 generic' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: '太怀旧不像 startup' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '完全错' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.cream.name, paletteId: 'cream', correct: true, why: '奶咖色 + 黑 = Notion 高级感' },
          { text: PALETTES.navy.name, paletteId: 'navy', correct: false, why: 'NAVY 就是他说的 generic SaaS blue' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色 cheap' },
          { text: PALETTES.pastel.name, paletteId: 'pastel', correct: false, why: '少女粉 VC 没法看' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.banner_wide, correct: true, why: 'Pitch deck cover 是横向 16:9 banner' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'IG 方图 ≠ pitch deck' },
          { text: FORMAT_OPTIONS.poster_a1, correct: false, why: 'A1 物理海报 not for VC' },
          { text: FORMAT_OPTIONS.reel_vertical, correct: false, why: '小红书竖图 ≠ pitch deck' },
        ],
      },
    ],
  },
  {
    id: 'brief_p2_skincare_uk',
    phase: 2,
    client: { name: 'Priya', emoji: '🌿', desc: 'UK indie skincare 创始人 · 35 岁' },
    subject: 'D2C 品牌 launch 主视觉',
    reward: 150,
    brief: '"Our skincare line is plant-based, made in UK, ethically sourced from Indian Ayurvedic traditions. Need a launch visual that doesn\'t feel like another \'clean girl\' wellness brand — we want richness, not blankness. Indian heritage shouldn\'t be reduced to mandala clipart though."',
    steps: [
      {
        q: '客户拒绝的 + 想要的?',
        options: [
          { text: '"丰富有 heritage 不是空白 wellness · 印度根源但不是 mandala 装饰"', correct: true, why: '精准复述客户' },
          { text: '"白底 + 极简 = clean girl"', correct: false, why: '她说 NOT clean girl' },
          { text: '"mandala + 印度 motif 大量装饰"', correct: false, why: '她说 NOT reduced to mandala' },
          { text: '"通用 wellness pastel"', correct: false, why: '错路线' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.raw_authentic, correct: true, why: 'richness + heritage = 粗糙真实而非高光' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '"blankness" 是她拒绝的' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '错路线' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '错路线' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.earth.name, paletteId: 'earth', correct: true, why: '土陶色 = richness + 不空白' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '白灰 = 她说的 blank wellness' },
          { text: PALETTES.mint.name, paletteId: 'mint', correct: false, why: 'mint = generic wellness' },
          { text: PALETTES.pastel.name, paletteId: 'pastel', correct: false, why: '少女粉错' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.brand_kit, correct: true, why: 'launch visual = 整套 kit logo+ 模板' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: '单 post 不够 launch' },
          { text: FORMAT_OPTIONS.poster_a3, correct: false, why: '物理 A3 不是 launch 重点' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '单 banner 不全' },
        ],
      },
    ],
  },
  {
    id: 'brief_p2_fashion_dropshop',
    phase: 2,
    client: { name: 'KK', emoji: '👟', desc: 'Streetwear drop-shop 主理人 · 26 岁' },
    subject: '冬季 capsule drop 主图',
    reward: 110,
    brief: '"Bro/sis, dropping a 6-piece winter capsule next Thurs. Want the visual to feel like a Berlin techno flyer — gritty, unfinished, slightly broken. Definitely NOT \'British heritage\' or \'minimalist Scandi\'. Vibe should make 20-yr-old hypebeasts stop scrolling."',
    steps: [
      {
        q: '客户参考的视觉语言?',
        options: [
          { text: '"Berlin techno flyer = 粗糙 / 错位 / Y2K 后朋克"', correct: true, why: '客户直接说了' },
          { text: '"英国传统 vintage 西装"', correct: false, why: '他明确说 NOT British heritage' },
          { text: '"Scandi minimalism 性冷淡"', correct: false, why: '他明确说 NOT' },
          { text: '"日系 muji 极简"', correct: false, why: '同上' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.bold_punk, correct: true, why: 'Berlin techno = punk 直接对应' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: '温暖怀旧 ≠ techno' },
          { text: MOOD_OPTIONS.serene_wellness, correct: false, why: '完全反' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: '完全反' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.moody.name, paletteId: 'moody', correct: true, why: '深夜黑金 = techno flyer 黑底亮重点' },
          { text: PALETTES.cream.name, paletteId: 'cream', correct: false, why: '柔奶咖 = Scandi(他拒绝的)' },
          { text: PALETTES.mint.name, paletteId: 'mint', correct: false, why: 'mint wellness 反向' },
          { text: PALETTES.pastel.name, paletteId: 'pastel', correct: false, why: '少女粉反向' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.poster_a1, correct: true, why: 'Berlin techno flyer = A1 物理海报感' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'drop 不需要完整 kit' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'IG post fine 但不是 hero asset' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅没 flyer 感' },
        ],
      },
    ],
  },
  {
    id: 'brief_p2_diaspora_podcast',
    phase: 2,
    client: { name: 'Emma Lo', emoji: '🎙️', desc: '亚裔 diaspora 播客主 · 29 岁' },
    subject: '播客第 2 季 cover art',
    reward: 130,
    brief: '"Season 2 of my diaspora podcast — exploring \'home\' for people who grew up between cultures. Don\'t want bamboo + chopstick visual cliché. Don\'t want generic NPR-y vector either. Should feel personal — like flipping through someone\'s photo album from the 90s."',
    steps: [
      {
        q: '参考语言?',
        options: [
          { text: '"90s 私人相册感 / personal / 非通用矢量"', correct: true, why: 'Photo album 90s 直接答案' },
          { text: '"竹子 + 筷子 + 红灯笼"', correct: false, why: '她明确说 NO cliché' },
          { text: '"NPR 经典 vector 风"', correct: false, why: '她明确说 NO NPR-y' },
          { text: '"现代极简性冷淡"', correct: false, why: '"impersonal" 反对' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.warm_nostalgic, correct: true, why: '90s 相册 = 怀旧' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '极简 = 她说的 impersonal' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '太轻浮不像 diaspora 讨论' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: '太 corporate' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.retro.name, paletteId: 'retro', correct: true, why: '复古海报色 = 90s 相册 vibe' },
          { text: PALETTES.cool.name, paletteId: 'cool', correct: false, why: '冷蓝 = NPR 矢量' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色不是 90s 私人' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '极简 = impersonal' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.ig_square, correct: true, why: 'Podcast cover 1:1 是 standard' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: 'Podcast cover 不是横幅' },
          { text: FORMAT_OPTIONS.reel_vertical, correct: false, why: '竖图不是 podcast cover' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope' },
        ],
      },
    ],
  },
  {
    id: 'brief_p2_artist_solo_show',
    phase: 2,
    client: { name: 'Mei Ling', emoji: '🎨', desc: 'Goldsmiths MA Fine Art · 26 岁' },
    subject: '个展开幕 invite',
    reward: 90,
    brief: '"My grad show opens Nov 14 at Hackney Wick. Theme is \'liminal spaces — between two cultures\'. The invite needs to be ambitious aesthetically — gallery people will scan it — but I don\'t have budget for ostentation. Think Wolfgang Tillmans not Stefan Sagmeister."',
    steps: [
      {
        q: 'Tillmans vs Sagmeister 差?',
        options: [
          { text: '"克制虚白 / 偶发摄影感 / 非装饰主义"', correct: true, why: 'Tillmans = 极简虚白对应' },
          { text: '"夸张 typo + 多层装饰"', correct: false, why: 'Sagmeister 风格,她拒绝' },
          { text: '"标准画廊白墙照"', correct: false, why: '太通用' },
          { text: '"商业海报红黄黑"', correct: false, why: '完全反' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.minimal_luxe, correct: true, why: '克制 + 高级 = Tillmans' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: 'Sagmeister 风' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: 'liminal 不是怀旧' },
          { text: MOOD_OPTIONS.energetic_youth, correct: false, why: '艺术展不年轻化' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.ethereal.name, paletteId: 'ethereal', correct: true, why: '清透虚白 = liminal + Tillmans' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色 = Sagmeister' },
          { text: PALETTES.sunset.name, paletteId: 'sunset', correct: false, why: '太餐饮' },
          { text: PALETTES.pop.name, paletteId: 'pop', correct: false, why: 'Y2K Pop 错路线' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.poster_a3, correct: true, why: '画廊 invite = A3 物理 + 邮寄' },
          { text: FORMAT_OPTIONS.ig_story, correct: false, why: 'Story 临时,不是 gallery people 收藏' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅 banner 不是 invite 格式' },
        ],
      },
    ],
  },

  // ════════════════ Phase 3 · W30+ (4 briefs) ════════════════
  // 客户挑剔,wrong options 也看起来 plausible。
  {
    id: 'brief_p3_michelin_bistro',
    phase: 3,
    client: { name: 'Chef Marco', emoji: '🍷', desc: 'Soho Michelin bib 主厨 · 45 岁' },
    subject: '冬季 tasting menu launch',
    reward: 220,
    brief: '"Our new tasting menu launches Dec 1. We need a poster that signals \'this isn\'t fine dining theatre but it\'s precise.\' Don\'t do another \'cozy candlelit\' restaurant cliché. The menu is technical (sous-vide, ferment, dehydration) but the room is unpretentious. Tightrope walk."',
    steps: [
      {
        q: '"Tightrope" 平衡点?',
        options: [
          { text: '"精准技术感 + 反对 fine dining 戏剧 + 不 cozy 套路"', correct: true, why: '客户精准说了' },
          { text: '"烛光暖橙温馨"', correct: false, why: '"don\'t do candlelit cliche"' },
          { text: '"高冷 fine dining 黑白照"', correct: false, why: '"not theatre"' },
          { text: '"街边大众餐厅红黄"', correct: false, why: '太低端' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.raw_authentic, correct: true, why: 'unpretentious + 技术 = 真实粗糙' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '极简 luxe = 他拒绝的 theatre' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: 'cozy candlelit cliché' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: '太 corporate' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.earth.name, paletteId: 'earth', correct: true, why: '土陶 + 真实手工感 + 不戏剧' },
          { text: PALETTES.moody.name, paletteId: 'moody', correct: false, why: '黑金 = fine dining theatre' },
          { text: PALETTES.warm.name, paletteId: 'warm', correct: false, why: '暖橘咖 = 他拒绝的 cozy' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '极简灰 = 他拒绝的另一种 theatre' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.poster_a3, correct: true, why: 'Restaurant poster = A3 实体 + 橱窗' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope · 已有品牌' },
          { text: FORMAT_OPTIONS.reel_vertical, correct: false, why: '小红书不是他客群' },
          { text: FORMAT_OPTIONS.ig_story, correct: false, why: 'Story 24h 不是 launch hero' },
        ],
      },
    ],
  },
  {
    id: 'brief_p3_dao_studio',
    phase: 3,
    client: { name: 'Dr. Lin', emoji: '🍵', desc: '伦敦中医 / 道家工作室 · 50 岁' },
    subject: '新年五行 workshop 系列',
    reward: 180,
    brief: '"我们新年办五行 workshop 系列五场。要 \'sophisticated 但不是 Apple\',\'东方但不是中国餐馆\',\'wellness 但不是 yoga 大妈\'。预算 £200 — 我儿子说这价能找到 designer 懂这层意思的。"',
    steps: [
      {
        q: '三个 "but not" 的精准 needle?',
        options: [
          { text: '"克制东方哲学感 + 高级但不科技 + wellness 但不大众"', correct: true, why: '精准复述' },
          { text: '"科技极简 Apple style"', correct: false, why: '他说 NOT Apple' },
          { text: '"红灯笼 + 龙图腾中餐馆"', correct: false, why: 'NOT 中国餐馆' },
          { text: '"yoga 妈妈 pastel"', correct: false, why: 'NOT yoga 大妈' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.serene_wellness, correct: true, why: 'wellness 主线但避免 yoga 妈妈 = 用 mood 收下半 swing palette' },
          { text: MOOD_OPTIONS.minimal_luxe, correct: false, why: '极简 luxe = Apple,他拒绝' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: '怀旧 = 中餐馆' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '完全反' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.forest.name, paletteId: 'forest', correct: true, why: '森林绿 + 自然 + 非 yoga pastel + 非 Apple grey' },
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: false, why: '灰 = Apple' },
          { text: PALETTES.warm.name, paletteId: 'warm', correct: false, why: '暖橘咖 = 中餐馆温度' },
          { text: PALETTES.mint.name, paletteId: 'mint', correct: false, why: 'mint pastel = yoga 妈妈' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.carousel, correct: true, why: '5 场 = 5 张 carousel · 完整 series 信息' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: '单 post 装不下 5 场' },
          { text: FORMAT_OPTIONS.poster_a1, correct: false, why: '物理海报 over-scope' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: 'over-scope · 已有品牌' },
        ],
      },
    ],
  },
  {
    id: 'brief_p3_west_end_play',
    phase: 3,
    client: { name: 'Sienna', emoji: '🎭', desc: 'West End fringe 制作人 · 38 岁' },
    subject: '原创 monologue 海报',
    reward: 250,
    brief: '"Our play \'Mother Tongue\' is about a second-gen British Chinese woman who can\'t speak Mandarin anymore. Need a poster Wall-to-wall on tube. Past designers gave us \'broken Chinese characters\' visuals — patronising. Want something that feels like the loss, not like a graphic gimmick about it."',
    steps: [
      {
        q: '客户 reject + want 的差?',
        options: [
          { text: '"loss 的诗意 / 不直白 / 非图形小聪明"', correct: true, why: '"feels like the loss, not gimmick"' },
          { text: '"破碎汉字字符直接显示"', correct: false, why: '她说 patronising' },
          { text: '"母女拥抱传统 stock photo"', correct: false, why: '太通俗' },
          { text: '"龙图腾 + 红色"', correct: false, why: 'cliché' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.moody_editorial, correct: true, why: 'loss + 编辑级 + 不夸张' },
          { text: MOOD_OPTIONS.warm_nostalgic, correct: false, why: '怀旧太暖,失去感是冷的' },
          { text: MOOD_OPTIONS.bold_punk, correct: false, why: '强冲突跟 quiet loss 反向' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '完全反' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.ethereal.name, paletteId: 'ethereal', correct: true, why: '清透虚白 + 紫 = 失去 / 渐远 / 不直白' },
          { text: PALETTES.cream.name, paletteId: 'cream', correct: false, why: '柔奶咖太温暖,不是失去' },
          { text: PALETTES.moody.name, paletteId: 'moody', correct: false, why: '黑金太重,有 drama' },
          { text: PALETTES.vivid.name, paletteId: 'vivid', correct: false, why: '撞色 = gimmick' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.poster_a1, correct: true, why: 'Tube wall-to-wall = A1 大海报' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'IG 方图不是 tube 海报' },
          { text: FORMAT_OPTIONS.brand_kit, correct: false, why: '已有 brand · over-scope' },
          { text: FORMAT_OPTIONS.banner_wide, correct: false, why: '横幅 banner ≠ tube 海报' },
        ],
      },
    ],
  },
  {
    id: 'brief_p3_vc_campaign',
    phase: 3,
    client: { name: 'Henrietta', emoji: '💎', desc: 'Mayfair VC firm partner · 52 岁' },
    subject: 'Annual report 封面',
    reward: 300,
    brief: '"Our annual LP letter cover. LPs are mostly sovereign wealth + family offices. We need to signal \'we know what we\'re doing, we don\'t need to shout, we\'re not your bank.\' No Mayfair gold trim cliché. No SVB-style \'we\'re fun.\' Think Wallpaper magazine cover from 2014."',
    steps: [
      {
        q: 'Wallpaper 2014 是什么参考?',
        options: [
          { text: '"克制极简 + 印刷质感 + 单一漂亮元素"', correct: true, why: 'Wallpaper 14 = 极简 luxe edition' },
          { text: '"Mayfair 金边 luxury"', correct: false, why: '她说 NOT Mayfair gold trim' },
          { text: '"SVB \'fun finance\' graphics"', correct: false, why: '她说 NOT SVB style' },
          { text: '"传统银行 navy + crest"', correct: false, why: '"not your bank"' },
        ],
      },
      {
        q: '选 mood',
        options: [
          { text: MOOD_OPTIONS.minimal_luxe, correct: true, why: 'Wallpaper 2014 精准对应' },
          { text: MOOD_OPTIONS.professional_trust, correct: false, why: 'professional 太 standard banking' },
          { text: MOOD_OPTIONS.raw_authentic, correct: false, why: 'raw 跟 LP 不对路' },
          { text: MOOD_OPTIONS.bright_playful, correct: false, why: '完全反' },
        ],
      },
      {
        q: '配色',
        options: [
          { text: PALETTES.monochrome.name, paletteId: 'monochrome', correct: true, why: '极简灰白 = Wallpaper 2014' },
          { text: PALETTES.navy.name, paletteId: 'navy', correct: false, why: 'NAVY = your bank,她拒绝' },
          { text: PALETTES.moody.name, paletteId: 'moody', correct: false, why: 'Mayfair gold trim 反对' },
          { text: PALETTES.cream.name, paletteId: 'cream', correct: false, why: '奶咖太温度,不是 VC 调子' },
        ],
      },
      {
        q: '格式',
        options: [
          { text: FORMAT_OPTIONS.brand_kit, correct: true, why: 'Annual report = 整套 layout system,不止 cover' },
          { text: FORMAT_OPTIONS.ig_square, correct: false, why: 'LP letter 不是 IG 用' },
          { text: FORMAT_OPTIONS.poster_a3, correct: false, why: '物理海报不是 annual report' },
          { text: FORMAT_OPTIONS.reel_vertical, correct: false, why: '小红书 ≠ LP comms' },
        ],
      },
    ],
  },
];

/**
 * 按 phase 抽 brief。pickedIds 避免重复。
 */
export function pickDesignBrief(week, pickedIds = []) {
  const phase = week <= 15 ? 1 : week <= 30 ? 2 : 3;
  const pool = DESIGN_BRIEFS.filter(b => b.phase === phase && !pickedIds.includes(b.id));
  // 如果该 phase 全部撞过,fallback 到全 phase 池
  const final = pool.length > 0 ? pool : DESIGN_BRIEFS.filter(b => b.phase === phase);
  return final[Math.floor(Math.random() * final.length)];
}

/**
 * 评分逻辑:
 * · Phase 1:4 = 5⭐ x1.25, 3 = 4⭐ x1.0, 2 = 3⭐ x0.85, 1 = 2⭐ x0.6, 0 = 1⭐ x0.3
 * · Phase 2:同上但 2/4 直接 2⭐
 * · Phase 3:3/4 = 4⭐ 不再"够好",2/4 = 2⭐
 */
export function scoreDesignBrief(correctCount, phase) {
  const tiers = {
    1: { 4: { stars: 5, mult: 1.25 }, 3: { stars: 4, mult: 1.0 }, 2: { stars: 3, mult: 0.85 }, 1: { stars: 2, mult: 0.6 }, 0: { stars: 1, mult: 0.3 } },
    2: { 4: { stars: 5, mult: 1.25 }, 3: { stars: 4, mult: 1.0 }, 2: { stars: 2, mult: 0.7 }, 1: { stars: 1, mult: 0.4 }, 0: { stars: 1, mult: 0.2 } },
    3: { 4: { stars: 5, mult: 1.25 }, 3: { stars: 4, mult: 0.95 }, 2: { stars: 2, mult: 0.55 }, 1: { stars: 1, mult: 0.3 }, 0: { stars: 1, mult: 0.0 } },
  };
  return tiers[phase][correctCount];
}

// Export palette lookup for component
export const DESIGN_PALETTES = PALETTES;
