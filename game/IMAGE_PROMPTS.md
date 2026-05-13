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

---

# 🆕 第 7 主线 · Link2Ur AI 广告创业线 (Y 姐线) — 11 张核心 + 11 张可选

> 2026-05-13 新增。Plan/Spec 见 `docs/superpowers/plans/2026-05-12-link2ur-skill-entrepreneurship-line.md`。
> 玩家主营 AI 广告 (Phase 1 留学生服务 → Phase 2 跨境 AI Studio),核心 NPC 陈思敏 / Yvonne Chan / Y 姐。
> 画风沿用前面的 Style Brief (米色 #f4ead8 + 水彩 + 钢笔线稿)。

## 7.1 · NPC 肖像 (1 张必画)

**规格**:1024 × 1024 px,半身像,放 `assets/illustrations/npcs/`

### 100. `npc-yjie.png` — Y 姐 / 陈思敏
> **28 岁广东中山女生**,在伦敦 6 年。半身像构图,坐在 Sketch 餐厅 pink room 的粉色绒面卡座旁。穿米色 trench coat、内搭白衬衫,Mulberry tote 摆在椅背上。短直发齐肩,刘海略斜剪,妆淡。表情:商业理性 + 粤式温情 — 嘴角微抿但眼神带笑。手里端一杯 cappuccino,另一只手摆在打开的 MacBook 旁。背景虚化粉色丝绒墙 + 一束 peony。光线:窗光柔。**不要**戴太多 jewelry,要给人一种"product 姐"而不是"金主"的气质。

---

## 7.2 · 成就卡插画 (6 张必画)

**规格**:1080 × 1080 px,放 `assets/illustrations/achievements/`,沿用现有 rarity 配色 (common 灰 / rare 蓝 / epic 紫 / legendary 金)。

### 101. `achievement-l2u_first_repeat.png` — 记得你 ⭐ (Common 灰底)
> 笔电屏幕上方一个微信通知气泡:"Lily 给了你 5 星 + 留言"。屏幕在 Pret a Manger 木桌上,旁边一杯燕麦拿铁、AirPods、一支笔。光线柔黄。重点突出"被记住"的小确幸感。

### 102. `achievement-l2u_clash_survived.png` — 撞档大王 ⚔️ (Rare 蓝底)
> 笔电屏幕上 3 个 inbox 任务卡片重叠堆叠,每张红色 ⏰ 过期 countdown 闪烁。桌上 3 个 Pret 杯 + 1 个空 Lemsip 包装 + 钢笔。深夜台灯光,玻璃窗外伦敦雨。一个亚洲面孔留学生手撑额头但嘴角倔强。

### 103. `achievement-l2u_y_audience.png` — Sketch Pink Room 🍰 (Rare 蓝底)
> Sketch 餐厅那个标志性的 millennial pink 卵形房间内景。两个杯子 (黑咖 + 燕麦拿铁) 摆在大理石小圆桌上,中间一本印好的 menu booklet,旁边一只 Mulberry tote 露出皮搭扣。两人坐姿,只画到肩部以下 — 一只手 (亚洲面孔留学生的) 端杯子,对面一只手 (Y 姐) 正翻开 booklet 第一页。重点突出空间梦幻感 + 邀请前一秒的 anticipation。

### 104. `achievement-l2u_first_hire.png` — 我招到了第一个人 🤲 (Epic 紫底)
> Pret Tottenham Court Road 周三下午。木桌两侧,一个 23 岁亚洲女生 (小雨,穿米色运动外套,头发整齐,微紧张) 坐对面。前景能看到桌面有两张笔记纸:一张写着 "cut 18%",另一张被笔尖按住。两人手交换递笔的瞬间。背景虚化是 Pret 玻璃门 + 路过的西装人。

### 105. `achievement-l2u_team_5.png` — 小小帝国 👑 (Legendary 金底)
> 自上而下俯视构图。一张 Bloomsbury 共享办公室的会议桌,围坐 5 个人:小雨 (亚洲女,翻译笔记) / Kenji (日本男,看 MacBook 上 Sora 预览) / Aman (印度男,Meta ads 仪表盘) / Chloe (ABC 女,通话耳机+笔记本) / Eric (亚洲男,平板上 Midjourney 出图) + 主位玩家头顶视角。桌中央一张 LinkU brand spec sheet + 多杯 Pret + 一只 succulent 盆栽。窗外是 London 雨景,但室内是暖色台灯。

### 106. `achievement-l2u_ai_anxiety_resolved.png` — 我是匠人 不是工具人 🧠 (Epic 紫底)
> BBC News 录制现场幕后小化妆间。前景:一面圆形化妆镜,镜框灯泡亮起。亚洲留学生坐在镜前,镜中映出自己 + 后面挂着的"AI Times: Immigrant Labor in the Age of Algorithms"演播海报。手里拿着 Paul 给的采访稿 — 但稿子上是手写的、不是 AI 生成的。表情:经过一场艰难采访后的 calm。

---

## 7.3 · 结局场景画 (3 张必画)

**规格**:1920 × 1080 px,放 `assets/illustrations/scenes/`,作为结局 walk-down 文本下方的大图。

### 107. `scene-ending_y_double.png` — Tier 1 《LinkU Bespoke + AI 创始合伙人》
> 媒体专访照构图。亚洲留学生 + Y 姐两人并肩站在 Sketch pink room 门口,Y 姐穿深绿丝绒外套,主角穿白衬衫+米色西装。两人都笑,眼神有 founder-level confidence。门楣上挂"LinkU Bespoke + AI Studio"双联名 brand 牌。底部一行小字:"Two Women / Founders Who Built a Travel Empire on Whatsapp" — 但字模糊到不可读 (按 Style Brief: 不要文字)。

### 108. `scene-ending_team_founded.png` — Tier 2 《我自己的 AI Studio》
> 自家小工作室视角。一面墙挂着团队 6 人的合影 polaroids + 一面是手写的 retention 71% / 4.92 evaluation。前景一张桌子,亚洲留学生坐着写小雨的 PhD 推荐信,旁边放一杯 Mei's 的红烧肉打包盒 + 王凯送的奶茶。窗外晨光。整体调子:**独立但温暖**,不是 LinkedIn glossy 而是 lived-in 的小公司。

### 109. `scene-ending_solo_apex.png` — Tier 2 《伦敦最难约的 AI Pro》
> Pret Tottenham Court Road,黄昏。亚洲留学生独自坐窗边长凳,前面摊开 MacBook,屏幕显示 inbox 18 条未读,最早一条预约日期是 "6 个月后"。手机屏亮:Y 姐 DM "Send me one of your Cotswolds photos sometime"。桌上一杯黑咖、一份没动的 chicken caesar wrap。窗外行人来往。**关键**:孤独 + 自给自足 + dignity intact 的对比。

---

## 7.4 · 关键场景插画 (1 张必画)

### 110. `scene-sketch_pink_room.png` — Sketch 邀请场景
> 比成就 #103 更大景的 Sketch pink room 全景。1920 × 1080 px。卵形空间,粉色丝绒墙 + 金属吊灯 + 几个圆形小桌 + 弧形长卡座。空间梦幻、tea-time 时段、玻璃天窗洒柔光。**不要**画人,只画空间 — Y 姐和玩家会作为人物 overlay 叠加上去。放在 `assets/illustrations/scenes/scene-sketch_pink_room.png`。

---

## 7.5 · 可选轻量插画 (11 张,客户/团员 avatar,优先级低)

> 当前代码用 **emoji + 色块**渲染客户/团员头像 (见 `link2urCustomers.js` / `link2urTeam.js` 的 `avatar` 字段)。如果想替换成手绘 avatar,以下 prompts。**不画也不影响发版** — 这些只是 polish。
> 规格:512 × 512 px,头像方框居中,文件名 `npc-{id}.png`。

### 客户 (6 张可选)
- 111. `npc-lily.png` — 25 岁北京二代,穿 Burberry 风衣,手提 IG 拍照,30万粉网红气质
- 112. `npc-jess_wong.png` — 22 岁香港 ABC,DTC 美妆主理人,妆精致但年轻,IG-first
- 113. `npc-marcus_okafor.png` — 21 岁 Black British (尼日利亚 diaspora),LSE 学生,反诈公益 vibe,工党红色 hoodie
- 114. `npc-carrie_brand_tea.png` — 32 岁中资品牌 marketing director,工业风、Apple Watch、深色西装
- 115. `npc-omar.png` — 25 岁迪拜留学生,巨富但孤独的眼神,白色 thobe / 现代 smart casual
- 116. `npc-paul_hartwell.png` — 35 岁 BBC 记者,左倾工党,Hackney 公寓 vibe,胡须短、戴 NHS 眼镜

### 团员 (5 张可选)
- 117. `npc-xiaoyu.png` — 23 岁北方亚洲女,KCL 应用语言学,运动外套,内敛
- 118. `npc-kenji.png` — 24 岁日本男,Goldsmiths Media,小圆眼镜 + 黑色 turtleneck,东京街拍 vibe
- 119. `npc-aman_singh.png` — 25 岁印度男,Imperial MEng,精瘦,Sikh 头巾 (turban) 黑色,理性目光
- 120. `npc-chloe.png` — 22 岁 ABC,KCL English Lit,Reformation 连衣裙,3 语切换的伶俐感
- 121. `npc-eric.png` — 22 岁中国二代,Brunel Design,中性发型,围裙挂脖上 (奶茶店打工痕迹)

---

## 7.6 · 文件夹结构 (新增)

```
assets/illustrations/
├── achievements/
│   └── ... (49 + 6 新 = 55 张)
├── locations/ (10 张不变)
├── npcs/
│   └── npc-yjie.png ← 新增 1 张 (必画)
│   └── npc-{lily/jess/marcus/carrie/omar/paul}.png ← 可选 6 张
│   └── npc-{xiaoyu/kenji/aman/chloe/eric}.png ← 可选 5 张
├── scenes/
│   ├── scene-ending_y_double.png         ← 新增必画
│   ├── scene-ending_team_founded.png     ← 新增必画
│   ├── scene-ending_solo_apex.png        ← 新增必画
│   └── scene-sketch_pink_room.png        ← 新增必画
└── misc/ (12 张不变)

新增必画:11 张 (1 NPC + 6 成就 + 3 结局 + 1 场景)
新增可选:11 张 (客户/团员 avatar)
画完总数:99 + 11 = 110 张 (基础) / 110 + 11 = 121 张 (含可选 polish)
```

---

# 🆕🆕 第 7 主线 v3 · 锦上添花补充图 — 8 张

> 2026-05-13 第二轮补充。当前 22 张已发版可玩, 这 8 张是"如果有更好"的视觉锚点。
> 分 3 个 Tier, 按需画即可。**全部都画也只 ~10 MB 增量**。
> 画风沿用 Style Brief。

## Tier S · 关键叙事缺图 (3 张, 强烈推荐)

### 122. `scene-rfh_farewell.webp` — Ch 9 W51 · Y 姐毕业前告别 ⭐⭐⭐⭐⭐
> 1920 × 1080 px / scenes/
> **问题**: 当前 Ch 9 W51 yjie_farewell 场景**完全没图**, 但这是 Y 姐线最后一面, 情感重量最大。
>
> 构图: 黄昏时分, **Royal Festival Hall** 旁泰晤士河 South Bank 一家不出名的精品咖啡店户外桌。Y 姐 (28 岁, 短直发) 今天**穿深绿色丝绒外套** (和 ending_y_double 那身一致, 但是侧脸/斜面构图)。桌上一只小巧的礼物盒 (LinkU brand color 米色包装 + 麻绳系蝴蝶结) + 两杯 flat white + 玩家一只手撑着。背景: 泰晤士河水面映 RFH 立面灯光, 远处 London Eye 亮起来。**焦点**: 礼物盒 + Y 姐手指轻碰盒子的瞬间。
>
> 调性: 不是 sad ending — 是 "see you later" 的 dignity。两人都在笑但眼神有重量。

### 123. `scene-paul_bbc_studio.webp` — Ch 7 W38 · BBC 演播室采访 ⭐⭐⭐⭐⭐
> 1920 × 1080 px / scenes/
> **问题**: 当前 `achievement-l2u_ai_anxiety_resolved.png` 是 backstage 化妆镜 (反思后),  缺**采访进行时**这张。
>
> 构图: BBC News 风格小演播室, 圆桌坐两人 — Paul (35 岁短胡须 NHS 黑框眼镜, 工党左倾知识分子 vibe) + 玩家 (亚洲面孔留学生, 微紧张但眼神聚焦)。桌上一支 BBC logo 的 microphone, 玩家手边一杯水。两侧 studio lights 把脸打亮但有阴影。**背景投影屏**模糊显示 "AI Times: Immigrant Labor in the Age of Algorithms" + 一张算法网格示意图。Paul 身体微前倾问问题 + 玩家手势在解释。
>
> 调性: 严肃但温暖。"我没有 prepared 答案 — 但我想清楚一些事了" 的 in-progress 时刻。

### 124. `scene-cotswolds_omar.webp` — Ch 6 W28 · Omar £1500 第一次品牌单 ⭐⭐⭐⭐
> 1920 × 1080 px / scenes/
> **问题**: 当前 Phase 2 第一次"我做的不是 service 而是 narrative" 的高端瞬间没有视觉表达。
>
> 构图: Cotswolds 私人庄园周末。**蜜色 limestone 乡村大别墅** + 修剪整齐的英式花园, 阳光透树叶斑驳。前景: 玩家蹲半地正在用手机 + DSLR 拍摄 — Omar 家族成员们 (3-4 个穿白色 thobe + 黑 abaya) 在草坪上 picnic, 一只 Saluki 猎犬奔跑。Omar 自己站后景看玩家拍, 嘴角有满意。空中浮一句"Phase 2 第一单"的 vibe — 但**画面里没文字**。
>
> 调性: Phase 1 "帮同道" → Phase 2 "做高净值客户" 的视觉跳变。

---

## Tier A · 跨圈联动 banner (3 张, 中等推荐)

### 125. `scene-soho_pub_wangkai_yjie.webp` — cross_yjie_wangkai_pub · 王凯 pub 偶遇 Y 姐 ⭐⭐⭐
> 1920 × 1080 px / scenes/
> 当前 crossover modal 弹出时背景无图, 仅文字。
>
> 构图: **Soho 一家昏暗 pub 角落**, Guinness 和 stout 在吧台, 木质护墙板, 周末喧闹模糊。前景: 王凯 (北方男, 25 岁 PhD Y2, 油滑兄长气) 端杯刚转身, 视线扫到对面桌 — Y 姐 (深色 trench, Mulberry tote, 正和一个中产英国客户 dinner)。Y 姐侧脸礼貌微笑, 没看见王凯。**王凯眼神**: 一种"哥们闻到对家"的探查 + 半 amused。光线: 暖黄灯 + 红色霓虹反光。

### 126. `scene-meis_yjie_dinner.webp` — cross_yjie_mei_dinner · Y 姐带客户来 Mei's ⭐⭐⭐
> 1920 × 1080 px / scenes/
>
> 构图: Mei's Lucky Star 中餐馆里间圆桌, **Y 姐和一对中国高净值夫妇** (40 岁+ 现代 smart casual, 妻子戴翡翠手镯)在用粤语聊天 + 点菜。桌上麻婆豆腐 + 烤鸭 + 一壶老北京花茶。前景虚化: Mei 姐 (50 多岁, 系红围裙) 端着汤站门口看, **眼神是评判性的关怀** (后面跟玩家说 "她跟你王凯不一样—王凯亲, 她精")。装饰: 红灯笼 + 福字。

### 127. `scene-eric_skewer_loyalty_clash.webp` — cross_wangkai_eric_steal · Eric 烤串店忠诚冲突 ⭐⭐⭐
> 1920 × 1080 px / scenes/
>
> 构图: Soho 一家中式烤串店, 油烟 + 红辣椒油 + 啤酒杯。圆桌坐三人: 玩家 + 王凯 (兄长姿态) + Eric (22 岁中国二代, 戴眼镜, 围裙挂脖, 局促)。王凯刚把一支烤串递给 Eric 同时跟玩家说话 "你怎么不让他选?"。Eric 夹在中间, 眼神在两个 employer 之间游移。桌中央: **半空的青岛啤酒 + Eric 的 sketchbook**。

---

## Tier B · 补完整客户 avatar (2 张, 可选)

### 128. `npc-grandma_zhang.webp` — 张奶奶 (cust_grandma) ⭐⭐
> 512 × 512 px / npcs/
> 当前 emoji 👵 兜底, 但她是 Y 姐线最温暖的"陪伴型"客户 — 跨阶段服务玩家整年。
>
> 构图: 67 岁老北京华侨女性, 头发花白整齐扎髻, 穿酱色棉袄外套 (传统但 dignified, 不是廉价"奶奶味")。背景: **伦敦 Hampstead Heath 公园**长椅角, 一只老金毛 (灰色嘴巴) 趴在脚边。她**举手机自拍**(准备发朋友圈给国内孙女), 嘴角细微的笑。眼神里有点孤独 (老伴去年走了), 但被那只狗治愈。光: 阴天柔光, 秋日落叶飘。

### 129. `npc-chen_yifan.webp` — 陈一帆 (cust_chen) ⭐⭐
> 512 × 512 px / npcs/
> 当前 emoji 📚 兜底, 她是 Whitmore 跨圈介绍的关键钩子 (Ch 7 W33)。
>
> 构图: 26 岁亚洲女学者, UCL 历史系 PhD Y3。长发简单扎起, **wireframe 圆眼镜**, 嘴角微抿。背景: **Senate House 7 楼图书馆**深夜, 桌上 4 杯空 Pret 杯 + 一摞 Foucault 的书 + 翻开的 MacBook (屏幕上是 Word 论文)。表情: 长期 thesis 写作的"麻木中带韧" — 不是崩溃, 是 grinding through。穿米色毛衣 + 灰色厚围巾 (图书馆冷)。

---

## 已 wired 的事件 ID (画完直接接入, 我已经预映射)

我会在你画完后用一次 commit 把下面 5 个映射加进 `imageRegistry.js`:

```javascript
// 当前 (已 mapped):
y_double / link2ur_team_founded / link2ur_solo_apex          → ending banner
yjie_sketch_invitation / yjie_merger_offer                    → sketch_pink_room

// 你画完这 8 张后我加 (event id → scene key):
yjie_farewell                  → rfh_farewell
ch7_paul_bbc_interview         → paul_bbc_studio
cross_yjie_paul_bbc            → paul_bbc_studio
ch6_omar_first                 → cotswolds_omar
cross_yjie_wangkai_pub         → soho_pub_wangkai_yjie
cross_yjie_mei_dinner          → meis_yjie_dinner
cross_wangkai_eric_steal       → eric_skewer_loyalty_clash

// 客户 avatar:
cust_grandma.avatarImage = 'grandma_zhang'
cust_chen.avatarImage    = 'chen_yifan'
```

总增量: **8 张图 + 5 行 imageRegistry 映射 + 2 行 customer avatarImage**。

---

## Tier C · UI 背景 / 道具图 (3 张, 可选 polish)

### 130. `bg-phase1_indicator.webp` — Phase 1 留学生 vibe 背景 ⭐⭐
> 800 × 200 px (横长条) / misc/
> 当前 PhaseIndicator 用 CSS 绿色渐变, 换成插画会有"个人 brand"感。
>
> 构图: 横长条插画。从左到右拼贴4 个微缩元素 — Pret 杯 / 翻开的笔记本 + AirPods / 手机屏 IG / Westminster 远景 — 半透明叠加在淡绿色水彩底上, 米色背景。整体不要太抢眼, 是 indicator 条的底图, 让 emoji 🌱 + "Phase 1 · 留学生 AI 服务" 文字浮在上面仍清晰可读。

### 131. `bg-phase2_indicator.webp` — Phase 2 跨境 AI Studio 背景 ⭐⭐
> 800 × 200 px (横长条) / misc/
>
> 构图: 横长条插画。从左到右 — MacBook + Meta ads dashboard / 小红书 app UI / 中英双语 brand book / The Shard 摩天大楼远景 — 半透明叠加在淡蓝色水彩底上, 米色背景。同上, 让 emoji 🚀 + "Phase 2 · 跨境 AI Studio" 浮在上面清晰。**和 Phase 1 形成 "成长" 视觉对照** (元素从校园 → 商业)。

### 132. `prop-yjie_napkin.webp` — Y 姐 W47 餐巾纸 cross-sell 模型 ⭐⭐⭐
> 800 × 600 px (略横) / misc/
> 当前 W47 merger modal 里 Y 姐 "推一张 napkin 过来" 的文字描述, 加图能让那一刻有冲击力。
>
> 构图: **皱巴巴 Sketch 餐厅米白色亚麻 napkin 摊在大理石桌上**, 上面是 Y 姐**钢笔手写**的简陋数字模型:
>
> ```
> LinkU Bespoke 客户 = 220 个/年 · 客单 £4500 平均
> + Player AI Studio = 全部客户 +£1500 行后 IG/小红书内容包
> = ARR 增量 £33万
> ```
>
> 字迹: 粤式商人风的快速笔画 (不工整, 实际 dealmaker 的 napkin 草稿感)。napkin 边缘有 cappuccino 杯底圆形咖啡渍。一个圆珠笔放旁边。**整张图自带"deal 现场"的紧张感**。

---

## 7.8 · 完整清单总结

| Tier | 数量 | 状态 |
|---|---|---|
| 原 11 必画 (Y 姐 + 6 成就 + 3 结局 + Sketch room) | 11 | ✅ 已画 |
| 原 11 可选 avatar (6 客户 + 5 团员) | 11 | ✅ 已画 |
| **Tier S · 关键叙事缺图 (RFH / BBC / Cotswolds)** | **3** | ⏳ 待画 |
| **Tier A · 跨圈联动 banner (3 crossover)** | **3** | ⏳ 待画 |
| **Tier B · 补完 8/8 客户 avatar (奶奶 + 陈)** | **2** | ⏳ 待画 |
| **Tier C · UI 背景 / 道具 (Phase 1/2 + napkin)** | **3** | ⏳ 待画 |
| **新增可画总数** | **11** | |
| **总图量 (画完后)** | **33** | |
