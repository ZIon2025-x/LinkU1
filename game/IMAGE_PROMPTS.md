# 异乡 · AI 手绘图生成指南

**总数**：80 张图（含 1.A 节后期补充 21 张成就）
**目标尺寸 / 文件名**：见每节
**保存位置**：`game/src/assets/illustrations/{achievements,locations,npcs,scenes,misc}/`

---

## ⭐ 通用 Style Brief（每条 prompt 都拼这一段）

复制下面这段到每个 prompt 前面：

```
风格：手绘水彩 + 钢笔线稿，怀旧温暖略忧郁，像留学日记里夹的速写。
参考画家：米山舞城市感 + 吉卜力日常感 + 久野遥子少女感。
配色：米色背景 #f4ead8 / 深褐 #2a2520，强调色用雾蓝 #6c8aa0、玫瑰灰 #c89090、暖金 #d4b070，高光奶白 #f4ead8。
光：柔光，伦敦阴天为主，偶尔暖色小窗 / 烛光。
质感：纸张颗粒可见，水彩晕染，钢笔线条略颤抖（不完美）。
不要：锐利 anime 风、digital glossy、3D、卡通、文字、字幕、emoji、logo、二维码。
```

---

# 第 1 阶段：成就卡插画（20 张主线 + 21 张 1.A 后期 = 41 张）

**规格**：1080 × 1080 px 正方形，主体居中留 5% 边距，深色背景 + 浅色主体反差。
**文件名**：保存为 `achievement-{id}.png`，放进 `assets/illustrations/achievements/`

---

## Common 灰底（5 张 · 文件名后缀分别是：brp_collected / gp_registered / pret / yellow_label / student_oyster）

### 1. `achievement-brp_collected.png` — BRP 收集者
> 一只亚洲面孔留学生的手掌摊开，握着一张粉红色英国 BRP 居留卡（biometric residence permit），卡上有姓名照片但模糊不可读。背景是邮局深棕木质柜台。手腕处可见羽绒服袖口。光线柔和。

### 2. `achievement-gp_registered.png` — NHS 入门
> 伦敦 GP surgery 玻璃门外，一只手在推门。门玻璃上有 NHS 红十字徽和 "Welcome" 字样模糊化。早晨阴天柔光。

### 3. `achievement-pret.png` — 第一次 Pret
> 一只 Pret a Manger 纸杯外带咖啡，放在 Bloomsbury 街角长椅上。杯壁有白色品牌条纹但不写文字。背景是穿大衣的人路过的剪影。

### 4. `achievement-yellow_label.png` — Tesco 抢黄标
> Tesco Express 冷柜内部视角，4-5 件食物贴着醒目黄色 reduced sticker，灯光惨白。一只亚洲面孔的手刚抓住一盒 sushi。

### 5. `achievement-student_oyster.png` — Student Oyster
> 蓝色 18+ Student Oyster 卡贴在 TFL 闸机感应区上的瞬间，闸机绿光亮起。背景是 Underground 站台模糊行人。

---

## Rare 蓝底（7 张 · 文件名后缀：tom_friend / tom_roast / mei_serving / cotswolds_visited / bicester_daigou / aisha_friend / marcus_solidarity）

### 6. `achievement-tom_friend.png` — Tom 的朋友
> 公寓走廊里凌晨四点，一个金发英国男生穿 Arsenal 红色卫衣 + 拖鞋，跟另一个亚洲面孔留学生交换"无奈一笑"。背景墙上消防警报红光闪烁。

### 7. `achievement-tom_roast.png` — Sunday Roast
> 木制餐桌上一只完整烤鸡，旁边 Yorkshire pudding 像云朵蓬松，烤土豆 + gravy 船 + 蔬菜。窗外英国乡村小镇剪影。柔和黄昏光。

### 8. `achievement-mei_serving.png` — Mei 姐徒弟
> 中餐馆厨房，一个亚洲面孔留学生系着红色围裙，端着一份红烧肉。背景模糊是 Mei 姐侧脸（30 年前来伦敦的福建女人，50 多岁，系另一条围裙在炒菜）。

### 9. `achievement-cotswolds_visited.png` — Cotswolds 圣诞
> 英国乡村石墙小屋，从外面窗口往里看：圣诞树 + 三个人围着餐桌 + 一只老金毛趴在地上。屋外飘小雪。

### 10. `achievement-bicester_daigou.png` — Bicester 代购
> 一只手提着 4 个米黄色 Burberry 纸袋（露出格纹一角）站在 Bicester Village outlet 出口。背景有其他亚洲面孔代购阿姨身影。冷天，呼气可见。

### 11. `achievement-aisha_friend.png` — Aisha 的斋月伙伴
> 24h 图书馆桌上，两个人对面坐——一个戴墨绿色 hijab 的女生，一个亚洲面孔，桌中央一颗椰枣 + 一杯热茶 + 翻开的笔记本。台灯昏黄柔光。

### 12. `achievement-marcus_solidarity.png` — "Welcome to the club"
> Pub 角落，一杯 Guinness 黑啤旁边，两双手碰一下杯——一只亚洲一只 Black British 男生，桌上还有薯条和 phone screen 微亮。

---

## Epic 紫底（5 张 · 文件名后缀：parents_visited / linnan_dating / sent_money_home / mei_family / oxford_ref）

### 13. `achievement-parents_visited.png` — 父母来过
> Heathrow T3 出口处，背影构图：一对中年中国父母 + 一个穿冬装的留学生三人拥抱。妈妈手里捧着一袋零食。两个超大行李箱在旁边。

### 14. `achievement-linnan_dating.png` — Trafalgar 跨年告白
> Big Ben 剪影在画面右上，烟花在天空炸开，前景两个穿大衣的人面对面（不需要看清脸，只看见侧面剪影），其中一个伸手碰另一个的手。

### 15. `achievement-sent_money_home.png` — 第一次给妈寄钱
> 一只亚洲面孔的手在手机屏上点 "确认转账"。屏幕显示 "¥2,000" 金额（数字模糊化但能感知）。手背有点累的痕迹。背景是 ensuite 单人间窗外英国阴天。

### 16. `achievement-mei_family.png` — Mei 姐家圣诞夜
> 圆形中式餐桌，桌上 17 道菜（红烧肉、白切鸡、蒸鱼、青菜等），5 个人围坐——Mei 姐 + 她沉默老公 + 两个 ABC 儿子（12 岁 + 8 岁）+ 一个亚洲留学生（背影）。Croydon 小红砖房客厅暖光。

### 17. `achievement-oxford_ref.png` — 牛津录取信
> 一封打开的牛津大学 Oxford DPhil offer letter（不写完整文字，只示意校徽），叠在 Whitmore 写的推荐信草稿上。一滴泪痕在纸上。背景模糊有 Christ Church 学院尖塔剪影。

---

## Legendary 金底（3 张 · 文件名后缀：sarah_double / aditi_double / linnan_forever）

### 18. `achievement-sarah_double.png` — Sarah 一辈子的朋友
> Cotswolds 教堂前 Sarah 的婚礼场景，远景。新娘转头眨眼那一瞬。主角作为伴娘 / 伴郎站在旁边远景。秋天树叶。

### 19. `achievement-aditi_double.png` — 孟买信封
> 一封蓝色 airmail 信封从印度寄来，盖了 5 个国际邮戳。一只手在拆封。背景是伦敦公寓窗外阴天 + 一杯 chai（Aditi 教过的配方）。

### 20. `achievement-linnan_forever.png` — Hackney 二居二人组
> Hackney 公寓阳台地上，两双不同尺码的拖鞋整齐摆着（一双偏大、一双偏小），远景看到伦敦天际线 + 朝霞。

---

## 1.A 后期补充成就卡（21 张 · 反诈 / 节日 / freelance / 政治参与扩展线）

**规格 / 风格**：跟前 20 张一致 —— 1080 × 1080 px，主体居中，深色背景 + 浅色主体，水彩 + 钢笔。

### 21. `achievement-mooncake_received.png` — 中秋节收到月饼
> 一块切开的莲蓉双黄月饼放在白瓷小碟上，旁边一杯桂花茶冒着热气。背景模糊一扇 ensuite 窗外伦敦阴天月亮。月饼包装纸 "Loon Fung" 字样模糊化。

### 22. `achievement-pdf_resisted.png` — 拒绝代写论文
> 一台 MacBook 屏幕一半显示微信代写中介对话框（"包过 distinction £600"），右边一只亚洲面孔的手按下黑色 BLOCK 按钮。屏幕外是 SOAS 图书馆 4 楼一角 + 一杯凉了的 Pret latte。

### 23. `achievement-pride_ally.png` — Pride London ally
> Soho Old Compton Street 街景剪影，前景一只手举着小彩虹旗，旗子边缘有水彩晕染。地面湿润反光（刚下完雨）。背景人潮 silhouette。彩虹只在旗子上，其余画面保持暖色水彩怀旧调。

### 24. `achievement-mei_soho_witnessed.png` — Mei 姐 1995 故事
> 中餐馆打烊后的小桌，两杯热茶摆着（已凉），一只 1995 年款的旧 Nokia 手机放在桌角。墙上挂日历是 1996 年。窗外是 Gerrard Street 老照片质感（70% 怀旧 30% 现实）。Mei 姐人不在画面中，只有她的围裙搭在椅背上。

### 25. `achievement-scam_consul_resisted.png` — 抗住假大使馆电话
> 一只亚洲面孔的手挂断 iPhone 电话的瞬间，屏幕显示 "+44 020 79..." 红色 END。手指悬在 BLOCK 按钮上方。背景模糊 ensuite 桌面，桌上散落写着"假冒大使馆话术"的便签纸。

### 26. `achievement-scam_courier_resisted.png` — 抗住假快递骗局
> 一台 iPhone 屏幕显示 SMS："Royal Mail 包裹滞留..."，后面带 ".cn/verify" 假域名（链接画红圈圈出）。一只手按删除按钮。桌上 Royal Mail 真红色信件作为参照对比。

### 27. `achievement-scam_recruiter_resisted.png` — 抗住假 Goldman recruiter
> LinkedIn 界面截图风格 — Olivia Chen 假头像（Goldman Sachs Asset Management 标签），右边浮一个 Action Fraud report number reference。一只手在屏幕上按 Report / Block 按钮。整体 desaturated 灰蓝调。

### 28. `achievement-scam_pig_resisted.png` — 抗住杀猪盘
> Hinge app 界面 unmatch 那一秒，屏幕显示 "Daniel" / "Diana" 头像缩成一个红色叉。前景一杯没动过的 oat latte（凉了起膜）+ 一本摊开在桌上的 Murakami 签名版书（5 周前对方寄来装情侣的"礼物"）。墙上挂年历显示过去 5 周被划掉。

### 29. `achievement-scam_pig_therapy.png` — NHS Talking Therapies CBT
> 一张 NHS 蓝色 talking therapies 引导卡片摆在咨询室桌上，旁边有一杯咨询师递过来的玻璃杯水（杯边有水珠），桌角放一盒 Kleenex。柔黄落日光从百叶窗缝隙穿过。

### 30. `achievement-scam_cosmetic_resisted.png` — 抗住美妆 MLM
> Notting Hill 公寓门外街景，一只穿着米色大衣的背影正离开门口（脚步剪影），手里握着一支没拆封的 Charlotte Tilbury 唇膏 — 似乎要扔进路边垃圾桶。门口残留的"Wellness Partner"招牌虚化在背景里。

### 31. `achievement-scam_mlm_resisted.png` — 抗住 networking MLM
> Mayfair Charles Street 一栋公寓门，画面前景是一只手推开（不接受）一份装订漂亮的 starter kit 文件夹。文件夹封面"Women in Business London"字样模糊处理。背景 Cartier-style 金链摆在 marble 桌面对比讽刺感。

### 32. `achievement-scam_trading_helper.png` — 帮新生抗 Forex 骗
> 一台 MacBook 屏幕显示视频通话画面 — 远端是另一个亚洲男生留学生剪影，共享屏幕展示 Action Fraud 报案 step-by-step。前景 sticky note 写"FCA register 30 秒查 broker 真伪"。台灯暖光，凌晨感。

### 33. `achievement-scam_educator.png` — CSSA 群反诈帖置顶 156 赞
> 微信群聊截图风格 — 一条置顶帖（绿色 PINNED 标记），下方 "156 ❤" 数字 + 几条群成员回复气泡（"建议群主置顶"、"宝宝太勇 ✨"）。整张画在水彩纸感的"截图"上面，边缘有手撕纸效果。

### 34. `achievement-freelance_curious.png` — 第一次想"我能不能靠这个活"
> Bloomsbury 街角 Pret 长椅上，一台 MacBook 屏幕显示 Notion 文档"毕业后 freelance 路线"。旁边一份吃了一半的 Pret meal deal 三明治 + Quavers。落日斜光打在屏幕上反光。

### 35. `achievement-freelance_sole_trader.png` — 注册 GOV.UK sole trader
> GOV.UK Personal Tax Account 界面截图风格，绿色 "✓ Self-Assessment registered" 字样模糊化。旁边一份装订好的小本子 "Freelance accounting · 2024" + 一支钢笔。桌角一杯姜茶。

### 36. `achievement-freelance_premium.png` — 第一次 quote £600/day
> Zoom video call 界面 — 远端 founder 头像模糊，下方 chat panel 显示一行字 "Fair. Let's do £2,400 retainer × 6 months"。前景画面外一只亚洲手放在嘴前（震惊静止），桌上 mug 里的茶静止不动。整体屋内黄光。

### 37. `achievement-freelance_career.png` — ILR via self-employed 路线
> 一张深紫色 BRP 卡 "Indefinite Leave to Remain" 醒目，卡上 "Remarks" 字段写 "No public funds · Work permitted"（暗示 self-employed 路线拿到，而非通过 sponsor）。背景虚化伦敦 Old Street 屋顶。光线日落金色。

### 38. `achievement-climate_strike.png` — 气候罢工出席
> Trafalgar Square 角落 Extinction Rebellion 集会的远景剪影 — 几面 "Tell the Truth" 黑底白字旗帜飘动，人群剪影拥挤但不细致。前景一双 Doc Martens 鞋 + 沥青地反光。整体灰蓝湿润。

### 39. `achievement-ucu_solidarity.png` — UCU 罢工声援
> SOAS 主楼门外 picket line 木牌：UCU 紫色横幅 + 一个写"Education not for Profit"的手写纸板（钢笔字）。前景一杯热咖啡放在地上一封 Solidarity 信旁。冬日早晨白雾感。

### 40. `achievement-daixie_refused.png` — 拒绝代写报酬
> 微信对话框 — 代写中介报价"distinction package £600"，右下方 BLOCK 按钮高亮（手指悬空）。背景虚化 SOAS 图书馆 4 楼夜景 + 一份正在写的 essay 草稿（手写痕迹）。

### 41. `achievement-daixie_reported.png` — 举报代写中介
> 一封打印出来的学校 academic integrity 举报回执 + 上面 Whitmore 教授的红笔批注 "Right thing to do — RW"。回执旁放着一支用旧的 Pilot 钢笔（笔身有划痕、墨水痕迹）。木桌质感。

---

# 第 2 阶段：Location 背景（10 张）

**规格**：1600 × 600 px 横幅
**文件名**：`location-{id}.png`，放进 `assets/illustrations/locations/`

| # | 文件名 | 描述 |
|---|---|---|
| 21 | `location-flat.png` | 11 平米 ensuite 卧室视角，单人床 + 书桌 + 朝砖墙的小窗，凌晨 3 点台灯亮，桌上放着白象方便面 + 笔记本电脑 |
| 22 | `location-uni.png` | Bloomsbury 维多利亚红砖大学主楼正面广角，雨后湿地面，3 个学生背包路过模糊 |
| 23 | `location-library.png` | 24h 图书馆 4 楼一排，绿色台灯 + 木桌，一个学生趴桌睡，旁边咖啡杯。窗外凌晨蓝紫色天空 |
| 24 | `location-tesco.png` | Tesco Express 内部，meal deal 冷柜 + 黄标 sticker + 收银员制服身影模糊。荧光灯白光 |
| 25 | `location-mei.png` | Chinatown Lucky Star 餐馆门口外景，红灯笼 + 玻璃窗水雾 + 招牌"Lucky Star · 福建菜"模糊化字样。傍晚暖光 |
| 26 | `location-pub.png` | The Crown 木头吧台，3 杯 cider + 1 杯 Guinness 黑啤 + 暖黄灯，墙上挂英国国旗。背景模糊一两个客人 |
| 27 | `location-park.png` | Hyde Park 雾天，光秃树 + 一只远处跑步的金毛 + 远处长椅 + 主角第一视角脚边落叶 |
| 28 | `location-tate.png` | Tate Modern 馆内 Rothko 厅，巨大纯红色块挂墙上，一个观众背影站着仰望。地板反光 |
| 29 | `location-soho.png` | Soho 夜晚街景，霓虹招牌（中餐馆、酒吧）+ 雨后地面反光 + Chinatown 牌坊远景 |
| 30 | `location-station.png` | King's Cross 站台 9¾ 柱子旁，一列火车进站，蒸汽与人群剪影 |

---

# 第 3 阶段：NPC 头像（11 张）

**规格**：512 × 512 px 正方形（圆形裁切）
**风格**：half-body 半身肖像 sketch + 水彩淡上色，眼神清晰但表情中性温和
**文件名**：`npc-{id}.png`，放进 `assets/illustrations/npcs/`

| # | 文件名 | 描述 |
|---|---|---|
| 31 | `npc-sarah.png` | 25 岁英国白人女生，金色卷发自然下垂，穿 Cotswolds 风羊毛针织 + 米色围巾，温和微笑，淡蓝眼睛 |
| 32 | `npc-wangkai.png` | 28 岁中国男生，黑框眼镜，黑色 PhD 风冲锋衣，露出一点疲惫的精明，短发 |
| 33 | `npc-aditi.png` | 25 岁印度女生，黑长发束起，穿浅蓝衬衫，戴小金耳环，眼睛大有点忧郁 |
| 34 | `npc-whitmore.png` | 65 岁英国白人男教授，灰白头发 + 花呢西装外套 + 眼镜，威严但温和，胡须短 |
| 35 | `npc-mei.png` | 50 岁福建女人，齐耳短发染过淡棕色，系餐馆围裙，眼神犀利但藏着 warmth，鱼尾纹 |
| 36 | `npc-tom.png` | 22 岁英国白人男生，金发蓬松凌乱，穿 Arsenal 红色卫衣，咧嘴笑 |
| 37 | `npc-mark.png` | 22 岁英国白人男生，棕色卷发凌乱，未刮胡茬，T 恤上有培根油痕，无辜表情 |
| 38 | `npc-linnan-female.png` | 23 岁中国女生（林可儿），戴白色一次性口罩，长黑发束马尾，戴黑框眼镜，文气安静 |
| 39 | `npc-linnan-male.png` | 23 岁中国男生（林楠），戴黑框眼镜，黑色卫衣，安静 nerdy，短发 |
| 40 | `npc-aisha.png` | 23 岁巴基斯坦女生，戴墨绿色 hijab，温暖笑容，眼线细，深棕色眼睛 |
| 41 | `npc-marcus.png` | 28 岁 Black British 男生，cropped 短发 + 牛津大学深蓝 hoodie，眼神 confident，淡淡微笑 |

---

# 第 4 阶段：关键场景插画（12 张）

**规格**：1600 × 900 px 横幅 16:9（modal 顶部 banner）
**文件名**：`scene-{key}.png`，放进 `assets/illustrations/scenes/`

| # | 文件名 | 描述 |
|---|---|---|
| 42 | `scene-plane.png` | 波音 777 经济舱第 41 排夜航视角，凌晨 4 点，舷窗外有点点城市灯光，主角轮廓背影看窗外。机舱昏暗暖光 |
| 43 | `scene-heathrow_arrival.png` | T3 Arrivals 出口外景，一个亚洲面孔留学生推两个 28 寸箱子，刚从滑动门走出。雨蒙蒙 |
| 44 | `scene-apartment_keys.png` | 公寓客厅，一个 30 岁英国白人男中介从手提包里递出一个牛皮纸文件袋给主角，背景厨房水槽 + 6 个 housemate 名签 |
| 45 | `scene-fire_alarm.png` | 公寓楼下停车场，60 个 housemate 裹着睡袍 / 拖鞋站在小雨中，远处有人打哈欠，远处保安拿手电 |
| 46 | `scene-bonfire_night.png` | Hyde Park 夜晚，烟花在天空炸开，地上人群仰望，主角和一对英国老夫妇分享一杯热可可 |
| 47 | `scene-boxing_day.png` | Oxford Street Selfridges 门口排 800 人长队从右边消失到画面外，雪在下，门刚开员工拉开金色绳栏 |
| 48 | `scene-sunday_roast.png` | 公寓客厅一桌 Sunday roast，5 个英国 / 中国年轻人围坐，电视播 Premier League，墙上贴海报 |
| 49 | `scene-parents_arrival.png` | T3 Arrivals 出口，一个 50 岁中国母亲推一个超大箱子小跑过来抱主角，父亲跟在后面拿帽子。Heathrow 标志模糊 |
| 50 | `scene-mei_christmas.png` | Croydon 红砖二层小房子的客厅，圆桌 17 道菜 + 4 个人 + 圣诞树 + 红包堆。Mei 姐儿子在玩 Mario Kart |
| 51 | `scene-crisis_4am.png` | 单人床头柜特写，手机屏幕亮着 "订机票" 页面，时钟显示 04:38，旁边有眼镜 + 半杯水 + 揉皱的纸巾 |
| 52 | `scene-linnan_confession.png` | South Bank 泰晤士河栏杆边夜景，烟花在天空炸开，两人面对面剪影，一个伸手 |
| 53 | `scene-graduation.png` | Royal Festival Hall 礼堂内大景，主角穿黑色学袍 + 紫金 hood 走过台子，远景观众席 + 灯光 |

---

# 第 5 阶段：Year-End Wrapped 海报（1 张）

**规格**：1080 × 1920 px 9:16 朋友圈竖版
**文件名**：`wrapped-bg.png`，放进 `assets/illustrations/misc/`

### 54. `wrapped-bg.png` — 留学一年回顾主视觉
> 一面深褐色 #2a2520 木质墙，上面像照片墙一样钉了 8-10 张未填充的 polaroid 框（位置预留空白，等代码填充用户成就照片）。墙上还散落手写便签："BRP done"、"4:38 AM 撑过来了"、"妈妈来了"。墙角挂一件黑色学袍 hood、一袋老干妈、一个 Pret 纸杯、一个 28 寸箱子。整体复古怀旧水彩 + 钢笔，留出顶部 30% + 底部 15% 空白区域以便嵌文字。

---

# 第 6 阶段：装饰素材（5 张）

**文件名**：放进 `assets/illustrations/misc/`

### 55. `loading-plane.png` (300×300) — 飞机 loading
> 一架小飞机起飞背影剪影，背景是水彩云朵 + 暖色夕阳。

### 56. `loading-rain.png` (300×300) — 雨 loading
> 伦敦窗户外密密的雨，小水滴顺玻璃滑下，玻璃上模糊几个红绿信号灯。

### 57. `loading-pret.png` (300×300) — Pret loading
> 一个 Pret 纸杯特写，蒸汽从杯口飘出。

### 58. `logo.png` (1024×512) — 异乡 + Link2Ur 双 brand mark
> 中文"異鄉"两个字大字（书法手写感），下方一行小字"A Study Abroad RPG · Powered by Link2Ur"。整体水彩晕染深褐色背景。

### 59. `diary-cover.png` (800×400) — 日记封面装饰
> 一本米色硬皮笔记本斜放，封面用钢笔写"我的留学日记 · 2026"，旁边有几张 polaroid 照片散落 + 一支钢笔 + 一个 BRP 卡。

---

# 工作流建议

1. **先做 Phase 1 + 1.A**（20 张成就卡）—— 这是分享物，最关键。**先 brp_collected / parents_visited / linnan_forever 三张试出风格**，对比满意再批量做。
2. 接着 Phase 1.C（11 NPC 头像）—— 一批做完。
3. 然后 Phase 1.B（10 location）+ Phase 2（12 scenes）—— 这两批可以一起。
4. 最后 Phase 3（Wrapped + 装饰 5 张）。

---

# 接入工程改动估时

图全部就位后我一次性接进去，预估 7-8 小时：
- 成就卡：1h（替换 emoji → drawImage）
- Location banner：1h（LocationView 加顶部 banner）
- NPC 头像：1h（NpcDialogModal + Story tab + 群聊头像）
- Scene banner：1.5h（modal 顶部加可选 banner）
- Wrapped 海报：3h（Year-End Wrapped 系统从 0 做）
- 测试 + Logo + 加载动画：1h

---

# 文件命名约定（再总结一遍）

```
src/assets/illustrations/
├── achievements/
│   ├── achievement-brp_collected.png
│   ├── achievement-tom_friend.png
│   └── ... (20 张)
├── locations/
│   ├── location-flat.png
│   ├── location-uni.png
│   └── ... (10 张)
├── npcs/
│   ├── npc-sarah.png
│   ├── npc-wangkai.png
│   ├── npc-linnan-female.png    ← 林可儿
│   ├── npc-linnan-male.png      ← 林楠
│   └── ... (11 张)
├── scenes/
│   ├── scene-plane.png
│   ├── scene-heathrow_arrival.png
│   └── ... (12 张)
└── misc/
    ├── wrapped-bg.png
    ├── logo.png
    ├── diary-cover.png
    ├── loading-plane.png
    ├── loading-rain.png
    └── loading-pret.png

合计 99 张已画（49 ach + 10 loc + 11 npc + 17 scene + 12 misc）
还差 21 张：1.A 节后期补充成就（见上）—— 画完总数 100 张
```

**当前缺图清单（21 张 · 1.A 节）**：
- 节日 / 学术 / 文化 4 张：mooncake_received / pdf_resisted / pride_ally / mei_soho_witnessed
- 反诈系列 9 张：consul / courier / recruiter / pig / pig_therapy / cosmetic / mlm / trading_helper / educator
- Freelance 系列 4 张：curious / sole_trader / premium / career
- 政治 + 学术诚信 4 张：climate_strike / ucu_solidarity / daixie_refused / daixie_reported

文件名用我列的那个 ID 严格对应（我代码会按这套 ID 引用）。生成完一批扔进对应文件夹，告诉我"成就 20 张做完了"，我接一批。
