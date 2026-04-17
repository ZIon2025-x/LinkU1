# Expert Independent Activities — Flutter Frontend Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lottery/first_come activity creation flow to the expert dashboard, including activity type selection, prize fields, draw configuration, and a manual draw button for lottery activities.

**Architecture:** Modify the existing `_ActivityFormSheet` in `activities_tab.dart` to show an activity type selector as the first step. When lottery or first_come is selected, show prize/draw fields instead of the service selector (which becomes optional). Add `drawTrigger` and `drawParticipantCount` to the Activity model. Add a manual draw endpoint call and button in the activity detail view. Add l10n strings for all three locales.

**Tech Stack:** Flutter, BLoC, Equatable, GoRouter, ARB localization

**Spec:** `docs/superpowers/specs/2026-04-17-expert-independent-activities-design.md`

**Backend plan:** `docs/superpowers/plans/2026-04-17-expert-independent-activities.md` (already implemented)

---

## File Structure

| Action | File | Responsibility |
|---|---|---|
| Modify | `link2ur/lib/data/models/activity.dart` | Add `drawTrigger`, `drawParticipantCount` fields |
| Modify | `link2ur/lib/core/constants/api_endpoints.dart` | Add expert manual draw endpoint |
| Modify | `link2ur/lib/data/repositories/expert_team_repository.dart` | Add `drawActivity()` method |
| Modify | `link2ur/lib/features/expert_dashboard/views/tabs/activities_tab.dart` | Activity type selector + conditional form fields |
| Modify | `link2ur/lib/features/activity/views/activity_detail_view.dart` | Manual draw button for expert owners |
| Modify | `link2ur/lib/features/activity/bloc/activity_bloc.dart` | Add manual draw event/handler |
| Modify | `link2ur/lib/data/repositories/activity_repository.dart` | Add `drawActivity()` method |
| Modify | `link2ur/lib/l10n/app_en.arb` | English strings |
| Modify | `link2ur/lib/l10n/app_zh.arb` | Simplified Chinese strings |
| Modify | `link2ur/lib/l10n/app_zh_Hant.arb` | Traditional Chinese strings |

---

### Task 1: Add `drawTrigger` and `drawParticipantCount` to Activity model

**Files:**
- Modify: `link2ur/lib/data/models/activity.dart`

- [ ] **Step 1: Add fields to Activity constructor**

In `activity.dart`, find the constructor parameters (around line 60-70). After `this.drawAt,` add:

```dart
    this.drawTrigger,
    this.drawParticipantCount,
```

- [ ] **Step 2: Add field declarations**

After `final DateTime? drawAt;` (around line 135), add:

```dart
  final String? drawTrigger;    // 'by_time' | 'by_count' | 'both'
  final int? drawParticipantCount;
```

- [ ] **Step 3: Add fromJson parsing**

After the `drawAt` parsing line (around line 284), add:

```dart
      drawTrigger: json['draw_trigger'] as String?,
      drawParticipantCount: json['draw_participant_count'] as int?,
```

- [ ] **Step 4: Add toJson serialization**

After `'draw_at': drawAt?.toIso8601String(),` (around line 356), add:

```dart
      'draw_trigger': drawTrigger,
      'draw_participant_count': drawParticipantCount,
```

- [ ] **Step 5: Add to copyWith**

In the `copyWith` method parameters (around line 419), after `DateTime? drawAt,`, add:

```dart
    String? drawTrigger,
    int? drawParticipantCount,
```

In the copyWith body (around line 480), after `drawAt: drawAt ?? this.drawAt,`, add:

```dart
      drawTrigger: drawTrigger ?? this.drawTrigger,
      drawParticipantCount: drawParticipantCount ?? this.drawParticipantCount,
```

- [ ] **Step 6: Add to props list**

In the `props` getter (around line 501), add `drawTrigger, drawParticipantCount,` to the list.

- [ ] **Step 7: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/data/models/activity.dart
```

Expected: No analysis issues

- [ ] **Step 8: Commit**

```bash
git add link2ur/lib/data/models/activity.dart
git commit -m "feat(flutter): add drawTrigger and drawParticipantCount to Activity model"
```

---

### Task 2: Add l10n strings for all three locales

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add English strings to `app_en.arb`**

Find the `expertActivitySelectServiceHint` line (around line 4918). After it, add:

```json
  "expertActivityType": "Activity Type",
  "expertActivityTypeStandard": "Standard Activity",
  "expertActivityTypeLottery": "Lottery Activity",
  "expertActivityTypeFirstCome": "First Come, First Served",
  "expertActivityTypeStandardDesc": "Linked to a service, participants pay to join",
  "expertActivityTypeLotteryDesc": "Participants sign up, winners drawn randomly",
  "expertActivityTypeFirstComeDesc": "Limited slots, first come first served",
  "expertActivityPrizeType": "Prize Type",
  "expertActivityPrizePhysical": "Physical Prize",
  "expertActivityPrizeInPerson": "In-Person Event",
  "expertActivityPrizeDescription": "Prize Description",
  "expertActivityPrizeDescriptionHint": "Describe the prize or benefit...",
  "expertActivityPrizeCount": "Number of Prizes/Slots",
  "expertActivityDrawMode": "Draw Method",
  "expertActivityDrawModeAuto": "Auto Draw",
  "expertActivityDrawModeManual": "Manual Draw",
  "expertActivityDrawTrigger": "Draw Trigger",
  "expertActivityDrawTriggerByTime": "By Time",
  "expertActivityDrawTriggerByCount": "By Participant Count",
  "expertActivityDrawTriggerBoth": "Whichever Comes First",
  "expertActivityDrawAt": "Auto Draw Time",
  "expertActivityDrawParticipantCount": "Draw When Reaching",
  "expertActivityDrawParticipantCountSuffix": "participants",
  "expertActivityServiceOptional": "Linked Service (Optional)",
  "expertActivityFree": "Free (no entry fee)",
  "expertActivityManualDraw": "Draw Now",
  "expertActivityManualDrawConfirm": "Are you sure you want to draw winners now? This cannot be undone.",
  "expertActivityDrawSuccess": "Draw completed! {count} winners selected.",
```

- [ ] **Step 2: Add Simplified Chinese strings to `app_zh.arb`**

Find the corresponding location in `app_zh.arb`. Add:

```json
  "expertActivityType": "活动类型",
  "expertActivityTypeStandard": "普通活动",
  "expertActivityTypeLottery": "抽奖活动",
  "expertActivityTypeFirstCome": "抢位活动",
  "expertActivityTypeStandardDesc": "关联服务，参与者付费参加",
  "expertActivityTypeLotteryDesc": "用户报名，截止后随机抽取中奖者",
  "expertActivityTypeFirstComeDesc": "限定名额，先到先得",
  "expertActivityPrizeType": "奖品类型",
  "expertActivityPrizePhysical": "实物奖品",
  "expertActivityPrizeInPerson": "线下到场",
  "expertActivityPrizeDescription": "奖品描述",
  "expertActivityPrizeDescriptionHint": "描述奖品或福利...",
  "expertActivityPrizeCount": "名额数量",
  "expertActivityDrawMode": "开奖方式",
  "expertActivityDrawModeAuto": "自动开奖",
  "expertActivityDrawModeManual": "手动开奖",
  "expertActivityDrawTrigger": "开奖条件",
  "expertActivityDrawTriggerByTime": "按时间",
  "expertActivityDrawTriggerByCount": "按人数",
  "expertActivityDrawTriggerBoth": "时间或人数先到先开",
  "expertActivityDrawAt": "自动开奖时间",
  "expertActivityDrawParticipantCount": "满员开奖人数",
  "expertActivityDrawParticipantCountSuffix": "人",
  "expertActivityServiceOptional": "关联服务（可选）",
  "expertActivityFree": "免费（无参与费）",
  "expertActivityManualDraw": "立即开奖",
  "expertActivityManualDrawConfirm": "确定要立即开奖吗？此操作不可撤销。",
  "expertActivityDrawSuccess": "开奖完成！已抽出 {count} 名中奖者。",
```

- [ ] **Step 3: Add Traditional Chinese strings to `app_zh_Hant.arb`**

Find the corresponding location in `app_zh_Hant.arb`. Add:

```json
  "expertActivityType": "活動類型",
  "expertActivityTypeStandard": "普通活動",
  "expertActivityTypeLottery": "抽獎活動",
  "expertActivityTypeFirstCome": "搶位活動",
  "expertActivityTypeStandardDesc": "關聯服務，參與者付費參加",
  "expertActivityTypeLotteryDesc": "用戶報名，截止後隨機抽取中獎者",
  "expertActivityTypeFirstComeDesc": "限定名額，先到先得",
  "expertActivityPrizeType": "獎品類型",
  "expertActivityPrizePhysical": "實物獎品",
  "expertActivityPrizeInPerson": "線下到場",
  "expertActivityPrizeDescription": "獎品描述",
  "expertActivityPrizeDescriptionHint": "描述獎品或福利...",
  "expertActivityPrizeCount": "名額數量",
  "expertActivityDrawMode": "開獎方式",
  "expertActivityDrawModeAuto": "自動開獎",
  "expertActivityDrawModeManual": "手動開獎",
  "expertActivityDrawTrigger": "開獎條件",
  "expertActivityDrawTriggerByTime": "按時間",
  "expertActivityDrawTriggerByCount": "按人數",
  "expertActivityDrawTriggerBoth": "時間或人數先到先開",
  "expertActivityDrawAt": "自動開獎時間",
  "expertActivityDrawParticipantCount": "滿員開獎人數",
  "expertActivityDrawParticipantCountSuffix": "人",
  "expertActivityServiceOptional": "關聯服務（可選）",
  "expertActivityFree": "免費（無參與費）",
  "expertActivityManualDraw": "立即開獎",
  "expertActivityManualDrawConfirm": "確定要立即開獎嗎？此操作不可撤銷。",
  "expertActivityDrawSuccess": "開獎完成！已抽出 {count} 名中獎者。",
```

- [ ] **Step 4: Generate l10n files**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter gen-l10n
```

Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(flutter): add l10n strings for lottery/first_come activity creation"
```

---

### Task 3: Add API endpoint and repository methods

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:334`
- Modify: `link2ur/lib/data/repositories/expert_team_repository.dart`

- [ ] **Step 1: Add expert manual draw endpoint constant**

In `api_endpoints.dart`, after the `expertTeamActivities` line (line 334), add:

```dart
  static String expertTeamActivityDraw(String expertId, int activityId) =>
      '/api/experts/$expertId/activities/$activityId/draw';
```

- [ ] **Step 2: Add `drawTeamActivity` method to `ExpertTeamRepository`**

In `expert_team_repository.dart`, after the `createTeamActivity` method (around line 425), add:

```dart
  /// 达人手动开奖。
  Future<Map<String, dynamic>> drawTeamActivity(
    String expertId,
    int activityId,
  ) async {
    final response = await _apiService.post(
      ApiEndpoints.expertTeamActivityDraw(expertId, activityId),
      data: {},
    );
    return response.data as Map<String, dynamic>;
  }
```

- [ ] **Step 3: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/core/constants/api_endpoints.dart lib/data/repositories/expert_team_repository.dart
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/expert_team_repository.dart
git commit -m "feat(flutter): add expert manual draw endpoint and repository method"
```

---

### Task 4: Rewrite `_ActivityFormSheet` with activity type selector

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/tabs/activities_tab.dart`

This is the main UI task. The form sheet currently assumes standard activities only. We need to:
1. Add an activity type selector as the first form element
2. Show service selector only for standard (required) or lottery/first_come (optional)
3. Show prize/draw fields for lottery/first_come
4. Conditionally show/hide max_participants based on type
5. Update `_submit()` to send new fields

- [ ] **Step 1: Add new state variables to `_ActivityFormSheetState`**

After the existing state variables (line 144), add:

```dart
  String _activityType = 'standard'; // 'standard' | 'lottery' | 'first_come'
  String _prizeType = 'physical';    // 'physical' | 'in_person'
  String _drawMode = 'auto';         // 'auto' | 'manual'
  String _drawTrigger = 'by_time';   // 'by_time' | 'by_count' | 'both'
  DateTime? _drawAt;
  late final TextEditingController _prizeDescriptionController;
  late final TextEditingController _prizeCountController;
  late final TextEditingController _drawParticipantCountController;
```

- [ ] **Step 2: Initialize and dispose the new controllers**

In `initState()`, after the existing controllers (line 155):

```dart
    _prizeDescriptionController = TextEditingController();
    _prizeCountController = TextEditingController(text: '3');
    _drawParticipantCountController = TextEditingController(text: '30');
```

In `dispose()`, before `super.dispose()`:

```dart
    _prizeDescriptionController.dispose();
    _prizeCountController.dispose();
    _drawParticipantCountController.dispose();
```

- [ ] **Step 3: Add activity type selector widget method**

Add this method to `_ActivityFormSheetState`:

```dart
  Widget _buildActivityTypeSelector() {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final types = [
      ('standard', l10n.expertActivityTypeStandard, l10n.expertActivityTypeStandardDesc, Icons.event_outlined),
      ('lottery', l10n.expertActivityTypeLottery, l10n.expertActivityTypeLotteryDesc, Icons.casino_outlined),
      ('first_come', l10n.expertActivityTypeFirstCome, l10n.expertActivityTypeFirstComeDesc, Icons.bolt_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.expertActivityType, isRequired: true),
        const SizedBox(height: 8),
        ...types.map((t) {
          final (value, label, desc, icon) = t;
          final selected = _activityType == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _activityType = value),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE0E0E0),
                    width: selected ? 2 : 1.5,
                  ),
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: selected ? AppColors.primary : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.primary : null,
                          )),
                          Text(desc, style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          )),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
```

- [ ] **Step 4: Add prize/draw configuration widget methods**

Add these methods:

```dart
  Widget _buildPrizeFields() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prize type
        _SectionLabel(label: l10n.expertActivityPrizeType, isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityPrizePhysical),
                selected: _prizeType == 'physical',
                onSelected: (_) => setState(() => _prizeType = 'physical'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityPrizeInPerson),
                selected: _prizeType == 'in_person',
                onSelected: (_) => setState(() => _prizeType = 'in_person'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Prize description
        _SectionLabel(label: l10n.expertActivityPrizeDescription, isRequired: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _prizeDescriptionController,
          decoration: _inputDecoration(
            hintText: l10n.expertActivityPrizeDescriptionHint,
            alignLabelWithHint: true,
          ),
          maxLines: 2,
          style: const TextStyle(fontSize: 15),
          validator: (value) {
            if (_activityType != 'standard' &&
                (value == null || value.trim().isEmpty)) {
              return l10n.validatorFieldRequired(l10n.expertActivityPrizeDescription);
            }
            return null;
          },
        ),
        const SizedBox(height: 20),

        // Prize count
        _SectionLabel(label: l10n.expertActivityPrizeCount, isRequired: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _prizeCountController,
          decoration: _inputDecoration(hintText: '3'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (_activityType != 'standard') {
              final n = int.tryParse(value ?? '');
              if (n == null || n < 1) {
                return l10n.validatorFieldRequired(l10n.expertActivityPrizeCount);
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDrawConfig() {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Draw mode
        _SectionLabel(label: l10n.expertActivityDrawMode, isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityDrawModeAuto),
                selected: _drawMode == 'auto',
                onSelected: (_) => setState(() => _drawMode = 'auto'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityDrawModeManual),
                selected: _drawMode == 'manual',
                onSelected: (_) => setState(() => _drawMode = 'manual'),
              ),
            ),
          ],
        ),

        if (_drawMode == 'auto') ...[
          const SizedBox(height: 20),

          // Draw trigger
          _SectionLabel(label: l10n.expertActivityDrawTrigger, isRequired: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerByTime),
                selected: _drawTrigger == 'by_time',
                onSelected: (_) => setState(() => _drawTrigger = 'by_time'),
              ),
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerByCount),
                selected: _drawTrigger == 'by_count',
                onSelected: (_) => setState(() => _drawTrigger = 'by_count'),
              ),
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerBoth),
                selected: _drawTrigger == 'both',
                onSelected: (_) => setState(() => _drawTrigger = 'both'),
              ),
            ],
          ),

          // Draw at (for by_time / both)
          if (_drawTrigger == 'by_time' || _drawTrigger == 'both') ...[
            const SizedBox(height: 20),
            _SectionLabel(label: l10n.expertActivityDrawAt, isRequired: true),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDrawAt,
              borderRadius: AppRadius.allSmall,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _drawAt == null
                            ? l10n.expertActivityDrawAt
                            : '${_drawAt!.year}-${_drawAt!.month.toString().padLeft(2, '0')}-${_drawAt!.day.toString().padLeft(2, '0')} ${_drawAt!.hour.toString().padLeft(2, '0')}:${_drawAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _drawAt == null
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : null,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ],
                ),
              ),
            ),
          ],

          // Draw participant count (for by_count / both)
          if (_drawTrigger == 'by_count' || _drawTrigger == 'both') ...[
            const SizedBox(height: 20),
            _SectionLabel(
              label: l10n.expertActivityDrawParticipantCount,
              isRequired: true,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _drawParticipantCountController,
              decoration: _inputDecoration(hintText: '30'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (_activityType == 'lottery' &&
                    _drawMode == 'auto' &&
                    (_drawTrigger == 'by_count' || _drawTrigger == 'both')) {
                  final n = int.tryParse(value ?? '');
                  final prizeCount = int.tryParse(_prizeCountController.text) ?? 0;
                  if (n == null || n <= prizeCount) {
                    return '${l10n.expertActivityDrawParticipantCount} > ${l10n.expertActivityPrizeCount}';
                  }
                }
                return null;
              },
            ),
          ],
        ],
      ],
    );
  }
```

- [ ] **Step 5: Add `_pickDrawAt` method**

After `_pickDeadline()`:

```dart
  Future<void> _pickDrawAt() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _drawAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_drawAt ?? now),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _drawAt = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    });
  }
```

- [ ] **Step 6: Update `build()` method — insert activity type selector and conditional sections**

In the `build()` method's Column children, replace the current form body. The order should be:

1. Sheet header (keep existing)
2. Error message (keep existing)
3. **Activity type selector** (NEW — `_buildActivityTypeSelector()`)
4. **Service selector** — show as required for standard, optional for lottery/first_come, hidden label changes
5. Title (keep existing)
6. Description (keep existing)
7. **Prize fields** (NEW — only for lottery/first_come: `if (_activityType != 'standard') _buildPrizeFields()`)
8. **Draw config** (NEW — only for lottery: `if (_activityType == 'lottery') _buildDrawConfig()`)
9. Task type (keep existing)
10. Deadline (keep existing)
11. **Participants** — only show for standard or lottery by_time/manual
12. Price per participant (keep existing, add hint about free for lottery/first_come)
13. Location (keep existing)
14. Service radius (keep existing)
15. Submit button (keep existing)

For the service selector section (step 4 above), wrap the existing code:

```dart
// ── Linked service ──
if (_activityType == 'standard') ...[
  _SectionLabel(
    label: context.l10n.expertActivitySelectService,
    isRequired: true,
  ),
  // ... existing service dropdown code ...
] else ...[
  _SectionLabel(
    label: context.l10n.expertActivityServiceOptional,
  ),
  // same dropdown but without validator (optional)
],
```

For the participants section, wrap:

```dart
if (_activityType == 'standard' ||
    (_activityType == 'lottery' &&
     (_drawMode == 'manual' || _drawTrigger == 'by_time'))) ...[
  // existing participants Row
],
```

- [ ] **Step 7: Update `_submit()` to send new fields**

Replace the `_submit()` method's validation and data building. Key changes:

```dart
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivityDeadline));
      return;
    }
    // Service required only for standard
    if (_activityType == 'standard' && _selectedService == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivitySelectService));
      return;
    }
    if (_location == null || _location!.isEmpty) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.activityLocation));
      return;
    }
    // Draw-at required for auto by_time/both
    if (_activityType == 'lottery' && _drawMode == 'auto' &&
        (_drawTrigger == 'by_time' || _drawTrigger == 'both') &&
        _drawAt == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivityDrawAt));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final priceText = _priceController.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _location!,
      'task_type': _taskType,
      'deadline': _deadline!.toIso8601String(),
      'activity_type': _activityType,
      if (_selectedService != null) 'expert_service_id': _selectedService!['id'],
      if (price != null) 'original_price_per_participant': price,
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      if (_serviceRadiusKm != null) 'service_radius_km': _serviceRadiusKm,
    };

    // Standard-specific fields
    if (_activityType == 'standard') {
      data['max_participants'] =
          int.tryParse(_maxParticipantsController.text.trim()) ?? 10;
      data['min_participants'] =
          int.tryParse(_minParticipantsController.text.trim()) ?? 1;
    }

    // Lottery / first_come fields
    if (_activityType != 'standard') {
      data['prize_type'] = _prizeType;
      data['prize_description'] = _prizeDescriptionController.text.trim();
      data['prize_count'] = int.tryParse(_prizeCountController.text.trim()) ?? 1;
    }

    // Lottery-specific
    if (_activityType == 'lottery') {
      data['draw_mode'] = _drawMode;
      if (_drawMode == 'auto') {
        data['draw_trigger'] = _drawTrigger;
        if (_drawTrigger == 'by_time' || _drawTrigger == 'both') {
          data['draw_at'] = _drawAt!.toUtc().toIso8601String();
        }
        if (_drawTrigger == 'by_count' || _drawTrigger == 'both') {
          data['draw_participant_count'] =
              int.tryParse(_drawParticipantCountController.text.trim()) ?? 30;
        }
      }
    }

    try {
      await widget.repository.createTeamActivity(widget.expertId, data);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
```

- [ ] **Step 8: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/expert_dashboard/views/tabs/activities_tab.dart
```

- [ ] **Step 9: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/views/tabs/activities_tab.dart
git commit -m "feat(flutter): add activity type selector and lottery/first_come form fields"
```

---

### Task 5: Add manual draw button to activity detail view

**Files:**
- Modify: `link2ur/lib/features/activity/views/activity_detail_view.dart`
- Modify: `link2ur/lib/features/activity/bloc/activity_bloc.dart`
- Modify: `link2ur/lib/data/repositories/activity_repository.dart`

This task adds a "Draw Now" button visible to the expert team owner on lottery activities that haven't been drawn yet.

- [ ] **Step 1: Add `ActivityManualDraw` event and handler to the BLoC**

In `activity_bloc.dart`, add a new event class (in the events section):

```dart
class ActivityManualDraw extends ActivityEvent {
  final String expertId;
  final int activityId;

  const ActivityManualDraw({required this.expertId, required this.activityId});

  @override
  List<Object?> get props => [expertId, activityId];
}
```

Register the handler in the bloc constructor:

```dart
on<ActivityManualDraw>(_onManualDraw);
```

Add the handler:

```dart
  Future<void> _onManualDraw(
    ActivityManualDraw event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final result = await _expertTeamRepository.drawTeamActivity(
        event.expertId,
        event.activityId,
      );
      final winnerCount = result['winner_count'] as int? ?? 0;
      emit(state.copyWith(
        actionMessage: 'expert_activity_draw_success:$winnerCount',
      ));
      // Reload detail to reflect drawn state
      add(ActivityLoadDetail(event.activityId));
    } on Exception catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
```

The BLoC constructor needs `ExpertTeamRepository` injected. Check if it's already there; if not, add it as a constructor parameter and store it as `_expertTeamRepository`.

- [ ] **Step 2: Add draw button to activity detail view**

In `activity_detail_view.dart`, find the `_OfficialPrizeInfoCard` widget or the action bar area. Add a "Draw Now" button that appears when:
- `activity.isLottery && !activity.isDrawn`
- The current user is the expert team owner (check `activity.ownerType == 'expert'` and current user has owner/admin role)

Since determining expert team membership from the detail view may be complex, a simpler approach: show the button if `activity.ownerType == 'expert'` and the activity owner_id matches one of the user's expert teams. But for MVP, we can show it when `activity.expertId == currentUser.id` (the legacy field mirrors the team owner's user_id).

Add a method in the detail view:

```dart
Widget _buildManualDrawButton(BuildContext context, Activity activity) {
  if (!activity.isLottery || activity.isDrawn) return const SizedBox.shrink();

  final l10n = context.l10n;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ElevatedButton.icon(
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.expertActivityManualDraw),
            content: Text(l10n.expertActivityManualDrawConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.commonConfirm),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          context.read<ActivityBloc>().add(ActivityManualDraw(
            expertId: activity.ownerId ?? '',
            activityId: activity.id,
          ));
        }
      },
      icon: const Icon(Icons.casino_outlined),
      label: Text(l10n.expertActivityManualDraw),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
  );
}
```

Place this button in the detail view layout, below the prize info card, visible only when the current user is the activity's expert owner.

- [ ] **Step 3: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/activity/
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/activity/ link2ur/lib/data/repositories/
git commit -m "feat(flutter): add manual draw button and BLoC event for expert lottery activities"
```

---

### Task 6: Verify full compilation and visual check

- [ ] **Step 1: Run flutter analyze on the full project**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze
```

Expected: No errors (warnings are OK)

- [ ] **Step 2: Fix any analysis issues found**

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix(flutter): resolve analysis issues in expert activity feature"
```
