import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/package_purchase_repository.dart';

/// 团队 owner/admin 套餐核销扫码 view (A1)
///
/// 流程:
///   1. 默认打开相机扫描 QR
///   2. 扫到 QR → POST /api/experts/{id}/packages/redeem
///   3. bundle 套餐若未指定子服务 → 后端返回 200 OK + requires_sub_service_selection,
///      弹选择对话框 (旧实现曾依赖从 HTTPException 消息里解析 JSON,但后端全局异常
///      handler 会吞掉 detail 里的额外字段,导致 bundle 流程完全坏掉,见 package_purchase_routes.redeem_package)
///   4. 失败显示错误,可重新扫
///   5. "手动输入 OTP" 按钮 fallback,显示 6 位数字输入
class PackageRedemptionScanView extends StatefulWidget {
  final String expertId;
  final PackagePurchaseRepository repository;

  const PackageRedemptionScanView({
    super.key,
    required this.expertId,
    required this.repository,
  });

  @override
  State<PackageRedemptionScanView> createState() =>
      _PackageRedemptionScanViewState();
}

class _PackageRedemptionScanViewState extends State<PackageRedemptionScanView> {
  final MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processing = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    setState(() => _processing = true);
    await _redeem(qrData: code);
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _redeem({String? qrData, String? otp, int? subServiceId}) async {
    try {
      final result = await widget.repository.redeemPackage(
        expertId: widget.expertId,
        qrData: qrData,
        otp: otp,
        subServiceId: subServiceId,
      );
      if (!mounted) return;
      // 后端用 200 OK + requires_sub_service_selection 表达 "bundle 套餐需要先选子服务"
      if (result['requires_sub_service_selection'] == true) {
        final rawList = result['sub_services'];
        final subServices = rawList is List
            ? rawList.whereType<Map<String, dynamic>>().toList(growable: false)
            : const <Map<String, dynamic>>[];
        final picked = await _pickSubService(subServices);
        if (picked != null && mounted) {
          await _redeem(
            qrData: qrData,
            otp: otp,
            subServiceId: picked,
          );
        }
        return;
      }
      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(e.toString());
    }
  }

  Future<int?> _pickSubService(
    List<Map<String, dynamic>> subServices,
  ) async {
    final l10n = context.l10n;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.packageRedemptionPickSubServiceTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.packageRedemptionPickSubServiceHint,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: subServices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = subServices[i];
                    final id = (s['id'] as num?)?.toInt();
                    final name = (s['service_name'] as String?) ??
                        (s['service_name_en'] as String?) ??
                        (s['service_name_zh'] as String?) ??
                        '#$id';
                    final remaining = (s['remaining'] as num?)?.toInt() ?? 0;
                    final exhausted = remaining <= 0;
                    return ListTile(
                      dense: true,
                      enabled: !exhausted,
                      title: Text(name),
                      subtitle: Text(
                        l10n.packageRedemptionSubServiceRemaining(remaining),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: exhausted
                          ? const Icon(Icons.block, color: Colors.grey)
                          : const Icon(Icons.chevron_right),
                      onTap: exhausted || id == null
                          ? null
                          : () => Navigator.of(ctx).pop(id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.packageRedemptionCancel),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    final l10n = context.l10n;
    final total = (result['total_sessions'] as num?)?.toInt() ?? 0;
    final used = (result['used_sessions'] as num?)?.toInt() ?? 0;
    final remaining = (result['remaining_sessions'] as num?)?.toInt() ?? 0;
    final exhausted = result['status'] == 'exhausted';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: Text(l10n.packageRedemptionSuccessTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.packageRedemptionSuccessPackageId(result['id'] ?? '')),
            Text(l10n.packageRedemptionSuccessUsage(used, total)),
            Text(l10n.packageRedemptionSuccessRemaining(remaining)),
            if (exhausted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.packageRedemptionSuccessExhausted,
                  style: const TextStyle(color: Colors.orange),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.packageRedemptionContinueScan),
          ),
        ],
      ),
    );
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.localizeError(message)),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showManualOtpDialog() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.packageRedemptionManualOtpTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.packageRedemptionManualOtpHint,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: l10n.packageRedemptionOtpLabel,
                border: const OutlineInputBorder(),
                hintText: l10n.packageRedemptionOtpPlaceholder,
              ),
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.packageRedemptionCancel),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.length == 6) Navigator.of(ctx).pop(code);
            },
            child: Text(l10n.packageRedemptionConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (otp != null && mounted) {
      await _redeem(otp: otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.packageRedemptionScanTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scanner.toggleTorch(),
            tooltip: l10n.packageRedemptionTorchTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scanner.switchCamera(),
            tooltip: l10n.packageRedemptionCameraSwitchTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                ),
                // 扫描框 overlay
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  l10n.packageRedemptionAimHint,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showManualOtpDialog,
                    icon: const Icon(Icons.dialpad),
                    label: Text(l10n.packageRedemptionManualOtpButton),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
