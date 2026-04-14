# Team-Level Consultation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to consult an expert team without choosing a specific service first, with full negotiation workflow where quoting requires selecting a service.

**Architecture:** New endpoint `POST /api/experts/{expert_id}/consult` creates a ServiceApplication(service_id=NULL) + placeholder Task. Existing negotiate/quote endpoints gain optional `service_id` parameter required for team consultations. Flutter team detail page calls the new endpoint, and the negotiation dialog adds a service picker for team consultations.

**Tech Stack:** FastAPI (backend), Flutter/BLoC (frontend), existing ServiceApplication + Task models

---

### Task 1: Backend — Team consultation endpoint

**Files:**
- Modify: `backend/app/expert_consultation_routes.py` (add new endpoint after line 275)
- Modify: `link2ur/lib/core/constants/api_endpoints.dart` (add endpoint constant)

- [ ] **Step 1: Add the team consultation endpoint**

In `backend/app/expert_consultation_routes.py`, add after line 275 (after the existing `create_consultation` function):

```python
@consultation_router.post("/api/experts/{expert_id}/consult")
async def create_team_consultation(
    expert_id: str,
    request: Request,
    body: Optional[dict] = None,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户对达人团队发起咨询（不绑定具体服务）"""
    from app.models_expert import Expert, ExpertMember
    # 校验团队存在且 active
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="达人团队不存在")
    if expert.status != "active":
        raise HTTPException(status_code=400, detail="该团队未在运营中")

    # 不能咨询自己的团队
    member_check = await db.execute(
        select(ExpertMember.id).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
            )
        ).limit(1)
    )
    if member_check.scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="不能咨询自己所在的团队")

    # 幂等：已有进行中的团队咨询直接返回
    existing = await db.execute(
        select(models.ServiceApplication).where(
            and_(
                models.ServiceApplication.new_expert_id == expert_id,
                models.ServiceApplication.applicant_id == current_user.id,
                models.ServiceApplication.service_id.is_(None),
                models.ServiceApplication.status.in_(["consulting", "negotiating", "price_agreed"]),
            )
        )
    )
    existing_app = existing.scalar_one_or_none()
    if existing_app:
        return {
            "task_id": existing_app.task_id,
            "application_id": existing_app.id,
            "status": existing_app.status,
        }

    # 创建占位 task
    team_name = expert.name or "达人团队"
    consulting_task = models.Task(
        title=f"团队咨询: {team_name}",
        description=f"团队咨询: {team_name}",
        reward=0,
        base_reward=0,
        reward_to_be_quoted=True,
        currency="GBP",
        location="",
        task_type="expert_service",
        poster_id=current_user.id,
        status="consulting",
        task_level="expert",
    )
    db.add(consulting_task)
    await db.flush()

    # 创建 application（service_id=NULL 表示团队咨询）
    application = models.ServiceApplication(
        service_id=None,
        applicant_id=current_user.id,
        new_expert_id=expert_id,
        application_message=(body or {}).get("message"),
        status="consulting",
        currency="GBP",
        task_id=consulting_task.id,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)

    # 通知团队 owner+admin
    await _notify_team_admins_new_application(
        db,
        expert_id=expert_id,
        applicant_name=current_user.name or "用户",
        service_name=team_name,
        application_id=application.id,
        notification_type="team_consultation_received",
        title_zh="新团队咨询",
        title_en="New Team Consultation",
    )

    return {
        "task_id": consulting_task.id,
        "application_id": application.id,
        "status": "consulting",
    }
```

- [ ] **Step 2: Add API endpoint constant in Flutter**

In `link2ur/lib/core/constants/api_endpoints.dart`, add near the existing expert team endpoints (around line 317):

```dart
static String consultExpert(String expertId) =>
    '/api/experts/$expertId/consult';
```

- [ ] **Step 3: Verify backend imports**

Run: `cd F:/python_work/LinkU/backend && python -c "from app.expert_consultation_routes import consultation_router; print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add backend/app/expert_consultation_routes.py link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat(consultation): add team-level consultation endpoint POST /api/experts/{expert_id}/consult"
```

---

### Task 2: Backend — Add service_id to negotiate and quote endpoints

**Files:**
- Modify: `backend/app/expert_consultation_routes.py:280-345` (negotiate_price and quote_price functions)

- [ ] **Step 1: Update negotiate_price to accept optional service_id**

Replace the `negotiate_price` function (lines 280-308) with:

```python
@consultation_router.post("/api/applications/{application_id}/negotiate")
async def negotiate_price(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """用户提出议价"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")
    if application.applicant_id != current_user.id:
        raise HTTPException(status_code=403, detail="无权操作")

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="price 必须为数字")
    if price <= 0:
        raise HTTPException(status_code=400, detail="price 必须大于 0")

    # 团队咨询：议价时必须绑定服务
    service_id = body.get("service_id")
    if application.service_id is None:
        if not service_id:
            raise HTTPException(status_code=400, detail="团队咨询议价必须选择一个服务")
        # 校验服务属于该团队
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                and_(
                    models.TaskExpertService.id == int(service_id),
                    models.TaskExpertService.owner_type == "expert",
                    models.TaskExpertService.owner_id == application.new_expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
        )
        if not svc_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="service_not_found")
        application.service_id = int(service_id)

    application.negotiated_price = price
    application.status = "negotiating"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "negotiating"}
```

- [ ] **Step 2: Update quote_price to accept optional service_id**

Replace the `quote_price` function (lines 311-345) with:

```python
@consultation_router.post("/api/applications/{application_id}/quote")
async def quote_price(
    application_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """达人报价（Owner/Admin）"""
    app_result = await db.execute(
        select(models.ServiceApplication).where(models.ServiceApplication.id == application_id)
    )
    application = app_result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="申请不存在")

    # 检查是否为服务的达人团队成员
    if application.new_expert_id:
        await _get_member_or_403(db, application.new_expert_id, current_user.id, required_roles=["owner", "admin"])
    elif application.service_owner_id == current_user.id:
        pass  # 个人服务 owner
    else:
        raise HTTPException(status_code=403, detail="无权操作")

    try:
        price = float(body.get("price", 0))
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="price 必须为数字")
    if price <= 0:
        raise HTTPException(status_code=400, detail="price 必须大于 0")

    # 团队咨询：报价时必须绑定服务
    service_id = body.get("service_id")
    if application.service_id is None:
        if not service_id:
            raise HTTPException(status_code=400, detail="团队咨询报价必须选择一个服务")
        svc_result = await db.execute(
            select(models.TaskExpertService).where(
                and_(
                    models.TaskExpertService.id == int(service_id),
                    models.TaskExpertService.owner_type == "expert",
                    models.TaskExpertService.owner_id == application.new_expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
        )
        if not svc_result.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="service_not_found")
        application.service_id = int(service_id)

    application.expert_counter_price = price
    application.status = "negotiating"
    application.updated_at = get_utc_time()
    await db.commit()
    return {"status": "negotiating"}
```

- [ ] **Step 3: Also update negotiate-response for counter offers with service_id**

In the `respond_to_negotiation` function (around line 404, the `elif action == "counter":` block), after the price validation and before writing to the application, add service_id handling:

```python
    elif action == "counter":
        # 校验价格
        try:
            price = float(body.get("price", 0))
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="price 必须为数字")
        if price <= 0:
            raise HTTPException(status_code=400, detail="price 必须大于 0")

        # 团队咨询还价时可更换服务
        service_id = body.get("service_id")
        if application.service_id is None and not service_id:
            raise HTTPException(status_code=400, detail="团队咨询还价必须选择一个服务")
        if service_id:
            svc_result = await db.execute(
                select(models.TaskExpertService).where(
                    and_(
                        models.TaskExpertService.id == int(service_id),
                        models.TaskExpertService.owner_type == "expert",
                        models.TaskExpertService.owner_id == application.new_expert_id,
                        models.TaskExpertService.status == "active",
                    )
                )
            )
            if not svc_result.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="service_not_found")
            application.service_id = int(service_id)

        # 按身份区分写哪个字段
        if is_applicant:
            application.negotiated_price = price
        else:
            application.expert_counter_price = price
        application.status = "negotiating"
```

- [ ] **Step 4: Verify backend**

Run: `cd F:/python_work/LinkU/backend && python -c "from app.expert_consultation_routes import consultation_router; print('OK')"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_consultation_routes.py
git commit -m "feat(consultation): add service_id to negotiate/quote/counter for team consultations"
```

---

### Task 3: Flutter — Repository + BLoC for team consultation

**Files:**
- Modify: `link2ur/lib/data/repositories/expert_team_repository.dart` (add method)
- Modify: `link2ur/lib/features/expert_team/bloc/expert_team_bloc.dart` (add event + handler)

- [ ] **Step 1: Add repository method**

In `link2ur/lib/data/repositories/expert_team_repository.dart`, add this method:

```dart
/// 发起团队咨询（不绑定具体服务）
Future<Map<String, dynamic>> createTeamConsultation(String expertId) async {
  final response = await _apiService.post<Map<String, dynamic>>(
    ApiEndpoints.consultExpert(expertId),
    data: {},
  );
  if (!response.isSuccess || response.data == null) {
    throw Exception(response.errorCode ?? response.message ?? 'consultation_failed');
  }
  return response.data!;
}
```

- [ ] **Step 2: Add event and handler in ExpertTeamBloc**

First, check the existing events/state file structure to find where to add the event. Add the event class in the bloc file's events section:

```dart
class ExpertTeamStartConsultation extends ExpertTeamEvent {
  final String expertId;
  const ExpertTeamStartConsultation(this.expertId);
  @override
  List<Object?> get props => [expertId];
}
```

Add to `ExpertTeamState` a field for consultation result:

```dart
final Map<String, dynamic>? consultationData;
```

Add it to the constructor, copyWith, and props.

Register the handler in the bloc constructor:

```dart
on<ExpertTeamStartConsultation>(_onStartConsultation, transformer: droppable());
```

Add the handler:

```dart
Future<void> _onStartConsultation(
  ExpertTeamStartConsultation event,
  Emitter<ExpertTeamState> emit,
) async {
  emit(state.copyWith(isSubmitting: true));
  try {
    final result = await repository.createTeamConsultation(event.expertId);
    emit(state.copyWith(
      isSubmitting: false,
      actionMessage: 'consultation_started',
      consultationData: result,
    ));
  } catch (e) {
    emit(state.copyWith(
      isSubmitting: false,
      errorMessage: e.toString(),
      actionMessage: 'consultation_failed',
    ));
  }
}
```

Note: Check the exact ExpertTeamState structure first. It may use different field names for `isSubmitting` (could be a status enum). Adapt the field names to match existing patterns. If `ExpertTeamState` doesn't have `isSubmitting` or `consultationData`, add them following the existing copyWith pattern.

- [ ] **Step 3: Run Flutter analyze**

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/data/repositories/expert_team_repository.dart lib/features/expert_team/bloc/`
Expected: No new errors

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/data/repositories/expert_team_repository.dart link2ur/lib/features/expert_team/bloc/
git commit -m "feat(consultation): add team consultation repository method and bloc event"
```

---

### Task 4: Flutter — Wire team detail page consultation button

**Files:**
- Modify: `link2ur/lib/features/expert_team/views/expert_team_detail_view.dart:1962-1988` (change chat button)

- [ ] **Step 1: Replace the direct chat navigation with consultation flow**

In `expert_team_detail_view.dart`, find the `_BottomActionBar` widget's chat button section (around lines 1962-1988). The current code is:

```dart
// Chat button
Expanded(
  child: SizedBox(
    height: 44,
    child: OutlinedButton.icon(
      onPressed: owners.isNotEmpty
          ? () {
              AppHaptics.selection();
              context.push('/chat/${owners.first.userId}');
            }
          : null,
      icon: const Icon(Icons.chat_bubble_outline, size: 16),
      label: Text(l10n.consultExpert),
```

Replace the `onPressed` callback. Add a `BlocListener` wrapping the bottom bar (or add a listener within the `_ExpertTeamDetailBody`). The approach: fire `ExpertTeamStartConsultation` event, listen for result, navigate.

In `_ExpertTeamDetailBody` (around line 60), the existing `BlocListener` already listens for `actionMessage`. Extend it to handle `consultation_started`:

```dart
listener: (context, state) {
  final msg = state.actionMessage ?? state.errorMessage;
  if (msg != null && msg != 'consultation_started') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(msg))),
    );
  }
  // Handle consultation navigation
  if (state.actionMessage == 'consultation_started' &&
      state.consultationData != null) {
    final taskId = state.consultationData!['task_id'];
    final appId = state.consultationData!['application_id'];
    if (taskId != null && appId != null) {
      context.push('/tasks/$taskId/applications/$appId/chat?consultation=true');
    }
  }
},
```

Change the chat button onPressed to:

```dart
onPressed: () {
  AppHaptics.selection();
  requireAuth(context, () {
    context.read<ExpertTeamBloc>().add(
      ExpertTeamStartConsultation(expertId),
    );
  });
},
```

Remove the `owners.isNotEmpty` condition since we're consulting the team, not chatting with owner.

- [ ] **Step 2: Run Flutter analyze**

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/expert_team/views/expert_team_detail_view.dart`
Expected: No new errors (existing unused_element_parameter warning is OK)

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/expert_team/views/expert_team_detail_view.dart
git commit -m "feat(consultation): wire team detail consultation button to formal consultation flow"
```

---

### Task 5: Flutter — Add service picker to negotiation dialogs

**Files:**
- Modify: `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart:36-84` (showCounterOfferDialog)
- Modify: `link2ur/lib/features/tasks/views/consultation/service_consultation_actions.dart:175-282` (_showNegotiateDialog, _showQuoteDialog)

- [ ] **Step 1: Add l10n keys for service picker**

In `link2ur/lib/l10n/app_en.arb`, add near the existing consultation keys:

```json
"consultationSelectService": "Select a service",
"consultationSelectServiceHint": "Choose a team service",
"consultationTeamConsultation": "Team Consultation",
```

In `link2ur/lib/l10n/app_zh.arb`:

```json
"consultationSelectService": "选择服务",
"consultationSelectServiceHint": "选择一个团队服务",
"consultationTeamConsultation": "团队咨询",
```

In `link2ur/lib/l10n/app_zh_Hant.arb`:

```json
"consultationSelectService": "選擇服務",
"consultationSelectServiceHint": "選擇一個團隊服務",
"consultationTeamConsultation": "團隊諮詢",
```

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter gen-l10n`

- [ ] **Step 2: Update showCounterOfferDialog to accept team consultation context**

The `showCounterOfferDialog` in `service_consultation_actions.dart` needs to know if this is a team consultation and, if so, show a service picker. Modify its signature and implementation:

```dart
void showCounterOfferDialog(
  BuildContext context, {
  required String Function() getCurrencySymbol,
  String? expertId, // non-null for team consultation (service_id is NULL)
}) {
  final priceController = TextEditingController();
  final bloc = context.read<TaskExpertBloc>();
  String? errorText;
  int? selectedServiceId;
  String? selectedServiceName;
  List<Map<String, dynamic>>? services;
  bool loadingServices = expertId != null;

  // Pre-load services for team consultation
  if (expertId != null) {
    context.read<TaskExpertRepository>().getExpertServices(expertId).then((list) {
      services = list;
      loadingServices = false;
    }).catchError((_) {
      loadingServices = false;
    });
  }

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        // If still loading services, trigger rebuild when loaded
        if (expertId != null && loadingServices) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (dialogContext.mounted) setDialogState(() {});
          });
        }
        return AlertDialog(
          title: Text(context.l10n.counterOffer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Service picker (team consultation only)
              if (expertId != null) ...[
                if (loadingServices)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                else
                  DropdownButtonFormField<int>(
                    value: selectedServiceId,
                    decoration: InputDecoration(
                      labelText: context.l10n.consultationSelectService,
                    ),
                    items: (services ?? []).map((s) {
                      final name = s['service_name'] as String? ?? '';
                      return DropdownMenuItem(
                        value: s['id'] as int,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedServiceId = v;
                      selectedServiceName = services?.firstWhere(
                        (s) => s['id'] == v,
                        orElse: () => {},
                      )['service_name'] as String?;
                    }),
                  ),
                const SizedBox(height: 12),
              ],
              // Price input
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: context.l10n.counterOfferHint,
                  prefixText: getCurrencySymbol(),
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                if (expertId != null && selectedServiceId == null) {
                  setDialogState(() => errorText = context.l10n.consultationSelectServiceHint);
                  return;
                }
                final price = double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() => errorText = context.l10n.counterOfferHint);
                  return;
                }
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskExpertNegotiateResponse(
                    applicationId,
                    action: 'counter',
                    counterPrice: price,
                    serviceId: selectedServiceId,
                  ),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() => priceController.dispose());
}
```

- [ ] **Step 3: Apply the same service picker pattern to _showNegotiateDialog and _showQuoteDialog**

Both `_showNegotiateDialog` (line ~175) and `_showQuoteDialog` (line ~218) need the same treatment:
- Accept `expertId` parameter
- Show service picker when `expertId != null`
- Pass `serviceId` to the bloc event

The bloc events `TaskExpertNegotiate`, `TaskExpertQuote`, and `TaskExpertNegotiateResponse` need an optional `serviceId` parameter. Check the event definitions and add `int? serviceId` to each. In the bloc handler, pass `service_id` in the API request body.

- [ ] **Step 4: Update bloc events and handlers to pass service_id**

In `task_expert_bloc.dart`, find the negotiate/quote event classes and add `int? serviceId`. In the handlers, include `service_id` in the request data when non-null:

```dart
// In the repository method for negotiate:
data: {
  'price': price,
  if (serviceId != null) 'service_id': serviceId,
},
```

- [ ] **Step 5: Run Flutter analyze**

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/tasks/views/consultation/ lib/features/task_expert/bloc/`
Expected: No new errors

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/features/tasks/views/consultation/ link2ur/lib/features/task_expert/bloc/
git commit -m "feat(consultation): add service picker to negotiation dialogs for team consultations"
```

---

### Task 6: Flutter — Fix Dashboard applications tab

**Files:**
- Modify: `link2ur/lib/features/expert_dashboard/views/tabs/applications_tab.dart:148-469` (_ApplicationCard)

- [ ] **Step 1: Make application cards tappable**

In `applications_tab.dart`, wrap the `_ApplicationCard`'s top-level `Container` (around line 215) with `InkWell`:

Find the card's `build` method return. Wrap the outer `Container` with a `GestureDetector` or `InkWell`:

```dart
@override
Widget build(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final l10n = context.l10n;
  // ... existing variables ...

  return GestureDetector(
    onTap: () => _onCardTap(context),
    child: Container(
      // ... existing container code ...
    ),
  );
}

void _onCardTap(BuildContext context) {
  final status = application['status'] as String?;
  final taskId = application['task_id'];
  final appId = application['id'];
  final applicantId = application['applicant_id'] as String?;

  if ((status == 'consulting' || status == 'negotiating' || status == 'price_agreed') &&
      taskId != null) {
    context.push('/tasks/$taskId/applications/$appId/chat?consultation=true');
  } else if (status == 'approved' && taskId != null) {
    final id = taskId is int ? taskId : int.tryParse(taskId.toString());
    if (id != null) context.goToTaskDetail(id);
  } else if ((status == 'consulting' || status == 'negotiating') &&
      taskId == null && applicantId != null) {
    // 历史数据降级：跳到跟用户的私聊
    context.push('/chat/$applicantId');
  }
}
```

- [ ] **Step 2: Add team consultation label**

In the header section of `_ApplicationCard` (around line 225 where service name is shown), add a fallback for team consultation:

```dart
// Service name (or team consultation label)
Text(
  (application['service_name'] as String?)?.isNotEmpty == true
      ? application['service_name'] as String
      : l10n.consultationTeamConsultation,
  style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
```

- [ ] **Step 3: Fix action buttons for consulting status**

The current code (around line 364-465) only shows "counter offer" for `pending`/`negotiating` and a chat button for consulting states. Update the button section to show appropriate actions per status:

For `consulting` and `negotiating` status: show both "沟通"(chat) and "报价"(quote) buttons side by side.

Replace the else block (lines 411-464) with:

```dart
] else if (application['status'] == 'consulting' ||
    application['status'] == 'negotiating' ||
    application['status'] == 'price_agreed') ...[
  const SizedBox(height: AppSpacing.xs),
  const Divider(height: 1),
  Padding(
    padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 沟通 button
        if (application['task_id'] != null)
          TextButton.icon(
            onPressed: () {
              final taskId = application['task_id'];
              final appId = application['id'];
              context.push('/tasks/$taskId/applications/$appId/chat?consultation=true');
            },
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: Text(l10n.expertApplicationChat),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.info,
              visualDensity: VisualDensity.compact,
            ),
          )
        else if (application['applicant_id'] != null)
          // 历史数据降级
          TextButton.icon(
            onPressed: () => context.push('/chat/${application['applicant_id']}'),
            icon: const Icon(Icons.chat_outlined, size: 16),
            label: Text(l10n.expertApplicationChat),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.info,
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(width: 8),
        // 报价 button (consulting/negotiating only)
        if (application['status'] != 'price_agreed')
          TextButton.icon(
            onPressed: () => _showCounterOfferDialog(context),
            icon: const Icon(Icons.request_quote, size: 16),
            label: Text(l10n.quotePrice),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        // 同意 button (price_agreed only)
        if (application['status'] == 'price_agreed')
          TextButton.icon(
            onPressed: () => _showApproveConfirmation(context),
            icon: const Icon(Icons.check, size: 16),
            label: Text(l10n.expertApplicationApprove),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  ),
] else if (application['status'] == 'approved' &&
    application['task_id'] != null) ...[
```

- [ ] **Step 4: Run Flutter analyze**

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze lib/features/expert_dashboard/views/tabs/applications_tab.dart`
Expected: No new errors

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/expert_dashboard/views/tabs/applications_tab.dart
git commit -m "fix(dashboard): make application cards tappable, fix action buttons, add team consultation label"
```

---

### Task 7: Integration verification

**Files:** None (verification only)

- [ ] **Step 1: Run full Flutter analyze**

Run: `cd F:/python_work/LinkU/link2ur && PATH="F:/flutter/bin:$PATH" PUB_CACHE="F:/DevCache/.pub-cache" flutter analyze`
Expected: No new errors

- [ ] **Step 2: Verify backend startup**

Run: `cd F:/python_work/LinkU/backend && python -c "from app.main import app; print('OK')"`
Expected: `OK` (with Redis/Firebase warnings, which are expected locally)

- [ ] **Step 3: Verify the full consultation flow mentally**

Walk through the flow:
1. User opens team detail page → sees "咨询达人" button
2. Taps button → `ExpertTeamStartConsultation` fired → `POST /api/experts/{id}/consult`
3. Backend creates Task + ServiceApplication(service_id=NULL) → returns task_id + application_id
4. Flutter navigates to `/tasks/{taskId}/applications/{appId}/chat?consultation=true`
5. In chat, user or provider taps "报价" → dialog shows service picker + price input
6. Submit → `POST /api/applications/{id}/negotiate` (or `/quote`) with `service_id` + `price`
7. Counterparty can accept (price_agreed) or counter (also with service_id + price)
8. When price_agreed → user can formal apply → provider approves → payment

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: integration fixes for team consultation"
```
