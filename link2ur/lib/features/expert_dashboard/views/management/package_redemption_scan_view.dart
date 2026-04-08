import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../data/repositories/package_purchase_repository.dart';

/// 团队 owner/admin 套餐核销扫码 view (A1)
///
/// 流程:
///   1. 默认打开相机扫描 QR
///   2. 扫到 QR → POST /api/experts/{id}/packages/redeem
///   3. 如果返回 bundle_sub_service_required → 弹子服务选择对话框
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
      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      // 解析 bundle_sub_service_required 错误
      final errStr = e.toString();
      if (errStr.contains('bundle_sub_service_required') &&
          (qrData != null || otp != null)) {
        // 需要选择子服务 — 但不知道子服务列表(因为 redeem 失败没返回 breakdown)
        // 提示用户手动选,这里简化为重新输入 sub_service_id
        await _promptSubServiceId(qrData: qrData, otp: otp);
      } else {
        _showErrorSnack(errStr);
      }
    }
  }

  Future<void> _promptSubServiceId({String? qrData, String? otp}) async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择要核销的子服务'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('该套餐包含多个子服务,请输入要核销的服务 ID:',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '子服务 ID',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final id = int.tryParse(controller.text.trim());
              if (id != null) Navigator.of(ctx).pop(id);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      await _redeem(qrData: qrData, otp: otp, subServiceId: result);
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('核销成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套餐 ID: ${result['id']}'),
            Text('已核销: ${result['used_sessions']} / ${result['total_sessions']} 次'),
            Text('剩余: ${result['remaining_sessions']} 次'),
            if (result['status'] == 'exhausted')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('⚠️ 此套餐已全部核销完毕',
                    style: TextStyle(color: Colors.orange)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续扫码'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnack(String message) {
    final cleaned = message.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleaned),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showManualOtpDialog() async {
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入 OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请让用户提供 6 位 OTP 代码',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
                hintText: '6 位数字',
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
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.length == 6) Navigator.of(ctx).pop(code);
            },
            child: const Text('核销'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('套餐核销扫码'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scanner.toggleTorch(),
            tooltip: '闪光灯',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scanner.switchCamera(),
            tooltip: '切换相机',
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
                const Text(
                  '请将用户出示的二维码对准扫描框',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showManualOtpDialog,
                    icon: const Icon(Icons.dialpad),
                    label: const Text('手动输入 OTP'),
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
