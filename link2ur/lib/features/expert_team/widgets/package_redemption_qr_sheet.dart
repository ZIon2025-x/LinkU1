import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/repositories/package_purchase_repository.dart';

/// Buyer 端套餐核销 QR 显示 sheet
///
/// 流程:
///   1. 拉 QR + OTP (TTL 60s)
///   2. 显示二维码 + 6 位备用 OTP
///   3. 50 秒自动刷新一次,防止 QR 在用户出示时过期
///   4. 用户也可以手动点刷新
class PackageRedemptionQrSheet extends StatefulWidget {
  final int packageId;
  final String packageTitle;
  final PackagePurchaseRepository repository;

  const PackageRedemptionQrSheet({
    super.key,
    required this.packageId,
    required this.packageTitle,
    required this.repository,
  });

  @override
  State<PackageRedemptionQrSheet> createState() =>
      _PackageRedemptionQrSheetState();
}

class _PackageRedemptionQrSheetState extends State<PackageRedemptionQrSheet> {
  String? _qrData;
  String? _otp;
  bool _loading = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.getRedemptionQr(widget.packageId);
      if (!mounted) return;
      setState(() {
        _qrData = data['qr_data'] as String?;
        _otp = data['otp'] as String?;
        _loading = false;
        _secondsLeft = 60;
      });
      _startTimers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _startTimers() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    // 50 秒后自动重新拉一次,留 10 秒缓冲
    _refreshTimer = Timer(const Duration(seconds: 50), _fetch);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft = (_secondsLeft - 1).clamp(0, 60);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              widget.packageTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '请将此二维码出示给达人扫描',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetch,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_qrData != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: _qrData!,
                  size: 220,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // 倒计时
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: _secondsLeft < 10 ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_secondsLeft 秒后自动刷新',
                    style: TextStyle(
                      color: _secondsLeft < 10 ? Colors.red : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // OTP 备用
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '扫码失败?让达人手动输入',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _otp ?? '------',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: theme.colorScheme.primary,
                        fontFeatures: const [],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh),
                  label: const Text('立即刷新'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 便利方法: 显示套餐核销 QR sheet
Future<void> showPackageRedemptionQrSheet({
  required BuildContext context,
  required int packageId,
  required String packageTitle,
  required PackagePurchaseRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => PackageRedemptionQrSheet(
      packageId: packageId,
      packageTitle: packageTitle,
      repository: repository,
    ),
  );
}
