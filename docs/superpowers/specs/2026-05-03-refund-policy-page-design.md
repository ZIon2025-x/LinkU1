# Refund Policy Page — Design Spec

- **Date**: 2026-05-03
- **Owner**: zixiong316@gmail.com
- **Status**: Approved by user (brainstorming complete)
- **Scope**: Flutter app (`link2ur/`) + backend SQL migration

---

## 1. Goal

Give users an in-app, version-controlled, multilingual **退款政策 / Refund Policy** that is reachable from every payment screen and from settings. Tapping the link opens a dedicated read-only page rendered from the existing `legal_documents` infrastructure.

Big-picture pattern (Taobao / 美团 / JD reference): pay button + a short consent footer beneath it ("支付即视为已阅读并同意《退款政策》") with the bracketed text linkable.

## 2. Non-goals

- **No checkbox / hard consent gate** — implicit consent via the pay action is enough. (User explicitly chose Approach ① in brainstorming.)
- **No VIP-subscription-specific entry** — VIP is an Apple/Google IAP; refunds go through the store. The refund policy page mentions this but the VIP UI gets no extra link.
- **No backend route changes** — `/api/legal/{type}?lang=` already accepts arbitrary `type` strings.
- **No new `LegalDocument` model fields** — current `content_json` JSON shape is sufficient.

## 3. Background

The codebase already has:

- **Backend**: `legal_documents` table seeded via SQL migrations (`backend/migrations/077`, `078`, `104`); `GET /api/legal/{type}?lang=` returns `{type, lang, version, effective_at, content_json}`. Existing types: `terms`, `privacy`, `cookie`, `community_guidelines`. **Only two languages are seeded: `lang='zh'` and `lang='en'`**.
- **Frontend (model layer)**: `link2ur/lib/data/models/legal_document.dart` parses `content_json` into ordered `LegalSection`s using a fixed `_orderKeys()` switch per `documentType`. `CommonRepository.getLegalDocument(type:, lang:)` calls the API (`common_repository.dart:75`).
- **Frontend (view layer — important caveat)**: `LegalDocumentView` in `info_views.dart:198` is **a simple static Scaffold** that takes `title: String, content: String` — it does NOT fetch from the API and does NOT render `LegalSection`s. Existing `TermsView` / `PrivacyView` / `CookiePolicyView` / `CommunityGuidelinesView` all feed it static `context.l10n.infoTermsContent`-style ARB strings. **No Flutter view currently consumes the `/api/legal` endpoint** (may be used by `frontend/` web only).
- **Refund logic** (`backend/app/routes/refund_routes.py`): supports `refund_type ∈ {full, partial}`, where `partial` accepts either `refund_amount` or `refund_percentage` (0–100). Only callable when `task.status == pending_confirmation`.

**Implication**: this spec establishes the **first** in-app view that consumes the `/api/legal` endpoint via `LegalDocument.fromJson` + `LegalSection` rendering. We are setting a precedent that `Terms` / `Privacy` / `Cookie` / `CommunityGuidelines` views could later migrate to (out of scope here).

## 4. Architecture overview

```
                                                ┌────────────────────────────────┐
SQL migration 214 ──seeds──► legal_documents ◄──┤ GET /api/legal/refund_policy   │
  (refund_policy, zh + en — 2 rows)             │  (existing route, no changes)  │
                                                └──────────┬─────────────────────┘
                                                           │ JSON
                                                           ▼
                                          CommonRepository.getLegalDocument(type:'refund_policy')
                                                           │
                                                           ▼
                                          LegalDocument.fromJson → ordered LegalSection list
                                                           │  (uses new case in _orderKeys)
                                                           ▼
                                          RefundPolicyView (FutureBuilder + ListView of section cards)
                                                           ▲
            ┌──────────────────────────────────────────────┴───────────────────┐
            │                                                                  │
   Tap on RefundPolicyFooter                                          Tap on settings legal row
   (in 4 payment surfaces)                                            (newly added)
```

## 5. Backend changes

### 5.1 New SQL migration

**File**: `backend/migrations/214_seed_refund_policy_legal_document.sql`

**Two** inserts into `legal_documents` — one for `lang='zh'`, one for `lang='en'`. (Confirmed: existing seeds use only `'zh'` and `'en'`; there is no `zh-Hant` row, and the Flutter app's zh-Hant locale will fall back to `lang='zh'` via the same `lang.startsWith('zh') ? 'zh' : 'en'` pattern that `FAQView` already uses.)

Pattern mirrors existing migrations `077` / `078` / `104`. Migration is idempotent: use `INSERT … ON CONFLICT (type, lang) DO UPDATE SET content_json = EXCLUDED.content_json, updated_at = NOW()`. Confirm the actual conflict-key column composition by reading 077 before authoring (077 uses `UPDATE … WHERE type=… AND lang=…` rather than `INSERT … ON CONFLICT`; copy whichever pattern works with the table's actual unique constraint).

Fields per row:

| column | value |
|---|---|
| `type` | `'refund_policy'` |
| `lang` | `'zh'` or `'en'` |
| `version` | `'1.0'` |
| `effective_at` | `'2026-05-03'` |
| `content_json` | JSONB — schema in §7 |

### 5.2 No code changes required

`/api/legal/{type}` accepts `type` as a free-form string and looks up the row by `(type, lang)`. No router / model / schema edit needed.

### 5.3 Migration runbook

Per `MEMORY.md` "Migration before deploy" rule: **run migration 214 on the DB before pushing the Flutter / docs commit.** Sequence:

1. `psql $LINKTEST_DB < backend/migrations/214_seed_refund_policy_legal_document.sql`
2. Verify: `SELECT type, lang, version FROM legal_documents WHERE type='refund_policy';` → 3 rows
3. Smoke-test endpoint: `curl https://linktest.up.railway.app/api/legal/refund_policy?lang=zh`
4. Then `git push` (Railway autodeploys — code can be pushed safely once data is in place)
5. Repeat 1–3 against prod DB before promoting to prod

## 6. Frontend changes

### 6.1 New files

| Path | Purpose |
|---|---|
| `link2ur/lib/features/info/views/refund_policy_view.dart` | New page that **fetches** the doc from `/api/legal/refund_policy` and renders ordered `LegalSection`s (cannot reuse the existing static `LegalDocumentView`) |
| `link2ur/lib/features/payment/views/widgets/refund_policy_footer.dart` | Reusable consent footer widget |

### 6.2 Edited files

| Path | Edit |
|---|---|
| `link2ur/lib/data/models/legal_document.dart` | Add `case 'refund_policy': return [...]` in `_orderKeys()` (§7 lists the keys in order) |
| `link2ur/lib/core/router/app_routes.dart` | Add `static const String refundPolicy = '/info/refund-policy';` in the "信息" block |
| `link2ur/lib/core/router/routes/info_routes.dart` | Register `GoRoute(path: AppRoutes.refundPolicy, name: 'refundPolicy', builder: (_, __) => const RefundPolicyView())` |
| `link2ur/lib/features/payment/views/payment_view.dart` | In `_buildPayButton` `SafeArea`, place `const RefundPolicyFooter()` directly under the `PrimaryButton` |
| `link2ur/lib/features/tasks/views/approval_payment_page.dart` | Same: under the bottom pay button |
| `link2ur/lib/features/wallet/views/wallet_view.dart` | Same: under the top-up confirm button (locate the actual top-up confirmation widget during planning) |
| `link2ur/lib/features/settings/views/settings_view.dart` | In the "法律条款" `_SettingsSection` (`settings_view.dart:304`), add a `_SettingsNavRow` with `Icons.account_balance_outlined` + `context.l10n.refundPolicyTitle`, `onTap: () => context.push(AppRoutes.refundPolicy)`. Use in-app navigation, NOT the `_openInAppWebView` pattern used by sibling rows — refund policy is the first true in-app legal doc here, and we want best-experience rendering via `LegalDocumentView`. |
| `link2ur/lib/l10n/app_zh.arb` + `app_en.arb` + `app_zh_Hant.arb` | Add 3 new keys (§6.4) |
| `link2ur/lib/l10n/app_localizations*.dart` | Regenerated via `flutter gen-l10n` (no manual edit) |

### 6.3 RefundPolicyView (sketch)

`RefundPolicyView` is a fetching page (FutureBuilder + repository call). It renders `LegalDocument.sections` as `title + paragraphs` cards, plus a "v{version} · {effectiveAt}" footnote in the AppBar subtitle.

```dart
class RefundPolicyView extends StatelessWidget {
  const RefundPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final apiLang = lang.startsWith('zh') ? 'zh' : 'en';
    final future = context.read<CommonRepository>().getLegalDocument(
          type: 'refund_policy',
          lang: apiLang,
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.refundPolicyTitle), centerTitle: true),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(child: Text(context.l10n.errorLoadFailedMessage));
          }
          final doc = LegalDocument.fromJson(snapshot.data!);
          final sections = doc.sections;
          return ListView.builder(
            padding: AppSpacing.allMd,
            itemCount: sections.length + 1, // +1 for version footer
            itemBuilder: (context, i) {
              if (i == sections.length) {
                return _VersionFooter(version: doc.version, effectiveAt: doc.effectiveAt);
              }
              return _SectionCard(section: sections[i]);
            },
          );
        },
      ),
    );
  }
}
```

`_SectionCard` renders `section.title` (semibold) + each paragraph (body). `_VersionFooter` renders muted small text "v1.0 · 生效日期 2026-05-03". Both are private widgets in the same file. Pattern mirrors `FAQView` in `info_views.dart` (already follows the FutureBuilder + repository pattern for an API-fed list page).

**Required imports** (none of these are unusual): `package:flutter/material.dart`, `package:flutter_bloc/flutter_bloc.dart`, plus the existing app paths for `LegalDocument`, `CommonRepository`, `AppSpacing`, `l10n_extension`.

**Why not reuse `LegalDocumentView`**: that widget takes a fully-formed `String content` and renders it as a single `Text` block; it doesn't fetch and doesn't know about `LegalSection`s. Refactoring it to do both would change its API and affect 4 existing call sites (out of scope).

### 6.4 RefundPolicyFooter (sketch)

```dart
class RefundPolicyFooter extends StatelessWidget {
  const RefundPolicyFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, color: textColor),
          children: [
            TextSpan(text: context.l10n.refundPolicyFooterPrefix),
            TextSpan(
              text: context.l10n.refundPolicyLinkText, // includes the 《》 brackets
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () => context.push(AppRoutes.refundPolicy),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
```

Implementation notes:
- Must be a `StatefulWidget` (or use a top-level `TapGestureRecognizer` lifecycle pattern) because `TapGestureRecognizer` needs `dispose()`. Convert to `StatefulWidget` during implementation; the sketch above leaks the recognizer.
- Tap target must satisfy 44×44 minimum. If the underline-only target is < 44pt tall, wrap the linkable span in a `WidgetSpan` containing an `InkWell` or expand padding.

### 6.5 New l10n keys

Each key gets a value in **all three** Flutter locales (zh, en, zh-Hant) — the Flutter app supports all three even though the API has only 2 langs.

| Key | zh | en | zh-Hant |
|---|---|---|---|
| `refundPolicyTitle` | 退款政策 | Refund Policy | 退款政策 |
| `refundPolicyFooterPrefix` | 支付即视为已阅读并同意 | By tapping Pay, you agree to our  | 支付即視為已閱讀並同意 |
| `refundPolicyLinkText` | 《退款政策》 | Refund Policy | 《退款政策》 |

ARB-compliant — no parameters, no plural forms.

## 7. Refund policy content (seed JSON)

Each language row's `content_json` follows this shape (key order matches the new `_orderKeys('refund_policy')` case). All key names are camelCase to match existing `terms` / `privacy` conventions. **Two languages only — `zh` and `en`.** Flutter zh-Hant locale falls back to `lang='zh'` via `apiLang` mapping in §6.3.

**Section keys (in order)**:

```
title, lastUpdated, version, effectiveDate,
intro, eligibility, fullRefund, partialRefund, nonRefundable,
refundProcess, refundTime, walletAndCoupon, disputeResolution,
vipSubscription, specialCases, contactUs, importantNotice
```

**Per-section content (zh authoritative; en is a 1:1 faithful translation)**:

| key | zh |
|---|---|
| `title` | 退款政策 |
| `lastUpdated` | 2026-05-03 |
| `version` | 1.0 |
| `effectiveDate` | 2026-05-03 |
| `intro` | 本政策适用于 Link²Ur 平台所有付费场景,包括但不限于:任务委托、套餐购买、活动报名、跳蚤市场租赁。VIP 订阅通过 Apple App Store / Google Play 购买,退款须按对应商店规则办理(详见第 12 节)。 |
| `eligibility` | 退款申请须满足以下条件之一:任务尚未确认完成(状态为「待确认」之前);双方协商一致取消;服务方违反平台规则被处理;平台原因导致服务无法继续。一旦任务双方确认完成,原则上不可申请退款。 |
| `fullRefund` | 以下情形可申请全额退款:① 服务方未开始履约;② 双方协商一致取消任务;③ 服务方逾期未响应或单方放弃;④ 服务方违反平台规则被处理(如封号、禁言);⑤ 平台原因(系统故障、不可抗力、运营调整)导致服务无法继续。 |
| `partialRefund` | 以下情形可申请按比例退款:① 服务方已部分交付,任务部分完成;② 双方就部分履约达成协议;③ 因发布方原因中止但服务方已投入工作。退款比例(0%–100%)由双方协商或平台审核裁定,通常按已完成工作量、已发生成本、约定服务标准等因素综合判定。 |
| `nonRefundable` | 以下情形不予退款:① 任务已确认完成且双方均已评价;② 服务方按约履约后,因发布方个人原因取消;③ 提供虚假证据或恶意申请退款;④ 申请超出本政策规定的有效期或任务状态窗口。 |
| `refundProcess` | 退款流程:① 任务发布方在任务详情页选择「申请退款」;② 选择退款类型(全额/按比例)、退款原因、退款金额;③ 服务方在 48 小时内回应(同意/异议);④ 双方达成一致后退款进入处理;⑤ 双方未达成一致时申请平台介入,客服在 3-5 个工作日内裁定;⑥ 审核通过后按原支付路径退款。 |
| `refundTime` | 退款到账时效(以渠道实际为准):钱包/平台余额——即时;银行卡 / Apple Pay——5-10 个工作日;微信支付——3-7 个工作日;支付宝——3-7 个工作日。退款失败的(如卡片已注销),平台将联系您协商替代方案。 |
| `walletAndCoupon` | 钱包与优惠券处理:① 使用钱包余额抵扣的部分,退款时退回钱包;Stripe 渠道支付的部分,退回原卡。② 全额退款时,使用过的优惠券将返还到您的账户(可在有效期内重复使用);按比例退款时,优惠券视为已使用,不予返还。③ 积分抵扣的处理同优惠券规则。 |
| `disputeResolution` | 争议处理:双方协商不成时,任意一方可申请平台介入。客服将在 3-5 个工作日内基于聊天记录、任务进度证据、双方陈述等综合裁定。平台裁定为最终结果,双方应予执行。涉及金额较大或复杂争议的,平台可延长审核期并要求补充证据。 |
| `vipSubscription` | VIP 订阅退款:Link²Ur VIP 通过 Apple App Store / Google Play 的应用内购买进行,退款须直接联系 Apple 支持或 Google Play 客服办理。平台无法直接处理通过应用商店购买的 VIP 订阅退款。已取消的订阅在当前付费周期结束前仍可享受 VIP 权益。 |
| `specialCases` | 特殊场景:① 不可抗力(自然灾害、政府管制、突发公共事件)导致任务无法继续的,按平台公告处理;② 平台原因(系统故障、运营调整)导致的损失,平台将主动全额退款并视情况提供补偿;③ 账号违规处置:被处置账号涉及的待结算资金按平台规则与法律要求处理。 |
| `contactUs` | 如有疑问或需要协助,请通过应用内「我的 → 帮助中心 → 联系客服」联系我们,客服工作时间为周一至周五 09:00-18:00(英国时间)。也可发送邮件至 info@link2ur.com。 |
| `importantNotice` | 本政策的最终解释权归 Link²Ur 平台所有。本政策可能因业务调整或法律法规变化而更新,更新后将在应用内公示并以最新版本为准。继续使用本平台付费功能视为接受最新版本的退款政策。 |

**en**: 1:1 faithful business-English translation of the zh content above. Lives in the same migration 214 file. (Translation drafting happens during migration authoring; the spec doesn't enumerate the en text to keep length manageable, but migration 214 must contain both `zh` and `en` complete payloads.)

## 8. Integration points (where the footer appears)

| Surface | File | Anchor |
|---|---|---|
| Task initial payment | `payment_view.dart:1142` (`_buildPayButton` `SafeArea`) | Below `PrimaryButton`, inside the same `SafeArea` |
| Approval-style payments (task approval / activity / flea market) | `approval_payment_page.dart` (around the bottom pay button) | Below the pay button, inside `SafeArea` |
| Wallet top-up | `wallet_view.dart` (locate the top-up confirm button during planning — could be a sheet or a page) | Below the confirm button |
| Settings → 法律条款 | `settings_view.dart:304-344` | Add as a new `_SettingsNavRow` in the `_SettingsSection` |

For the top-three payment surfaces, **a single shared `RefundPolicyFooter` widget** keeps copy + style + behavior identical. Future style or copy tweaks happen in one file.

## 9. Testing

Scope is small; testing matches it.

**Unit (model)**:
- `legal_document_test.dart` — extend the existing test (or add one) verifying `_orderKeys('refund_policy')` returns the expected ordered key list and that `sections` for a sample `refund_policy` JSON yields the right `LegalSection` titles + paragraphs in order. (Mirror whatever exists for `terms`/`privacy` if there is one; add a fresh test if not.)

**Widget**:
- `refund_policy_footer_test.dart` — pumping the widget renders the prefix + linked text; tapping the linked span calls `GoRouter.push` with `/info/refund-policy`. Use `mocktail` (already in dev deps).

**Smoke (manual)**:
- After running migration 214 on linktest, hit `GET /api/legal/refund_policy?lang=zh` and `?lang=en` and verify both return `200` with `content_json` populated.
- In Flutter, open each of the 4 entry points (task payment / approval / wallet top-up / settings) and confirm:
  - footer appears below pay button
  - tapping the link opens a page titled "退款政策"
  - all content sections (intro through importantNotice) render in correct order
  - switching app language: zh → renders zh content; en → en content; zh-Hant → falls back to zh content (intentional, matches FAQ pattern)

No backend tests required — there's no new code path; only data was inserted.

## 10. Rollout

1. Author + run migration 214 on **linktest** DB
2. Smoke-test the API endpoint (curl)
3. Push Flutter changes to `main`
4. Wait for `linktest.up.railway.app` autodeploy to settle
5. Manual verification on the staging app (test 4 entry points + 3 languages)
6. Author + run migration 214 on **prod** DB
7. Promote build via the standard channel

## 11. Risks & open questions

| Item | Status |
|---|---|
| `lang` code convention | **Resolved**: existing seeds use `'zh'` and `'en'` only (no `zh-Hant`). Use the same. |
| `LegalDocumentView` reuse | **Resolved**: cannot reuse — see §6.3. We're authoring a new fetching view. |
| `RefundPolicyFooter` `TapGestureRecognizer` lifecycle | Implement as `StatefulWidget` to dispose recognizer cleanly |
| Wallet top-up button location — UI is unfamiliar | Locate during planning step; if top-up uses a confirmation sheet, embed footer in the sheet |
| Translation quality (en) | Drafted by implementer; user reviews before merging the migration |
| Appeasing in-app review systems (Apple/Google) | Refund policy mentions IAP/store correctly — should pass review without issue |
| Establishing a new in-app legal-doc rendering pattern | Acceptable — was the user's choice (Approach A). Existing static `TermsView` etc. can migrate later. |

## 12. Out of scope (for this spec)

- Adding a refund **request** flow improvement — covered separately
- Showing refund status / history — already exists via `RefundRequest` model
- Versioned consent tracking (storing "user X agreed to refund_policy v1.0 at timestamp Y") — not required since consent is implicit; can be added later if legal pushes for it
- A/B testing different footer copy — premature
