import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/legal_document.dart';

void main() {
  group('LegalDocument._orderKeys via sections (refund_policy)', () {
    test('renders refund_policy sections in the documented order', () {
      final doc = LegalDocument.fromJson({
        'type': 'refund_policy',
        'lang': 'zh',
        'version': 'v1.0',
        'content_json': {
          'title': '退款政策',
          'lastUpdated': '最后更新：2026-05-03',
          'version': '版本：v1.0',
          'effectiveDate': '生效日期：2026-05-03',
          'intro': 'intro body',
          'eligibility': 'eligibility body',
          'fullRefund': 'full body',
          'partialRefund': 'partial body',
          'nonRefundable': 'non body',
          'refundProcess': 'process body',
          'refundTime': 'time body',
          'walletAndCoupon': 'wallet body',
          'disputeResolution': 'dispute body',
          'vipSubscription': 'vip body',
          'specialCases': 'special body',
          'contactUs': 'contact body',
          'importantNotice': 'notice body',
        },
      });

      final titles = doc.sections.map((s) => s.title).toList();

      // _orderKeys skips 'title'; metadata strings (lastUpdated, version,
      // effectiveDate) become single-paragraph sections with the key as title.
      expect(titles, [
        'lastUpdated',
        'version',
        'effectiveDate',
        'intro',
        'eligibility',
        'fullRefund',
        'partialRefund',
        'nonRefundable',
        'refundProcess',
        'refundTime',
        'walletAndCoupon',
        'disputeResolution',
        'vipSubscription',
        'specialCases',
        'contactUs',
        'importantNotice',
      ]);
    });

    test('omits keys absent from content_json without error', () {
      final doc = LegalDocument.fromJson({
        'type': 'refund_policy',
        'lang': 'en',
        'content_json': {
          'title': 'Refund Policy',
          'intro': 'intro body',
          'fullRefund': 'full body',
        },
      });

      final titles = doc.sections.map((s) => s.title).toList();
      expect(titles, ['intro', 'fullRefund']);
    });
  });
}
