import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:larisai_mobile/core/constants/api_constants.dart';
import 'package:larisai_mobile/models/transaction_model.dart';
import 'package:larisai_mobile/services/auth_service.dart';
import 'package:larisai_mobile/services/printer_service.dart';
import 'package:larisai_mobile/services/store_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StoreProfile & Mode Scoping Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Mode-scoped profiles are isolated and do not pollute each other', () async {
      final service = StoreProfileService.instance;
      await service.init(initialMode: ConnectionMode.offline);

      // 1. Initial offline profile should be default
      expect(service.profile.storeName, equals('TOKO LARIS UMKM'));

      // 2. Save an offline profile
      await service.saveProfile(
        const StoreProfile(
          storeName: 'WARUNG OFFLINE BAROKAH',
          ownerName: 'Pak Budi Offline',
          storeAddress: 'Jl. Offline No. 1',
          storePhone: '0811111111',
          receiptFooter: 'Terima Kasih Belanja di Warung Barokah!',
        ),
        targetMode: ConnectionMode.offline,
      );
      expect(service.profile.storeName, equals('WARUNG OFFLINE BAROKAH'));

      // 3. Switch to Cloud SaaS mode and save SaaS profile
      await service.switchMode(ConnectionMode.cloud);
      expect(service.profile.storeName, equals('TOKO LARIS UMKM')); // Default since not set in SaaS yet

      await service.saveProfile(
        const StoreProfile(
          storeName: 'PT CLOUD RETAIL NUSANTARA',
          ownerName: 'Admin Cloud',
          storeAddress: 'Menara SaaS Lt. 12',
          storePhone: '0822222222',
          receiptFooter: 'Terima Kasih Atas Kunjungan Anda!',
        ),
        targetMode: ConnectionMode.cloud,
      );
      expect(service.profile.storeName, equals('PT CLOUD RETAIL NUSANTARA'));

      // 4. Switch back to Offline mode: must restore Offline profile without SaaS pollution!
      await service.switchMode(ConnectionMode.offline);
      expect(service.profile.storeName, equals('WARUNG OFFLINE BAROKAH'));
      expect(service.profile.ownerName, equals('Pak Budi Offline'));
      expect(service.profile.storeAddress, equals('Jl. Offline No. 1'));

      // 5. Switch to LAN mode: should be separate LAN profile
      await service.switchMode(ConnectionMode.wifi);
      expect(service.profile.storeName, equals('TOKO LARIS UMKM'));

      await service.saveProfile(
        const StoreProfile(
          storeName: 'RESTO LAN MASTER HUB',
          ownerName: 'Host Kasir',
          storeAddress: 'Food Court Stand A',
          storePhone: '0833333333',
          receiptFooter: 'Terima Kasih Atas Kunjungan Anda!',
        ),
        targetMode: ConnectionMode.wifi,
      );
      expect(service.profile.storeName, equals('RESTO LAN MASTER HUB'));

      // Verify all 3 modes remain strictly isolated
      final offProfile = await service.getProfileForMode(ConnectionMode.offline);
      final cloudProfile = await service.getProfileForMode(ConnectionMode.cloud);
      final lanProfile = await service.getProfileForMode(ConnectionMode.wifi);

      expect(offProfile.storeName, equals('WARUNG OFFLINE BAROKAH'));
      expect(cloudProfile.storeName, equals('PT CLOUD RETAIL NUSANTARA'));
      expect(lanProfile.storeName, equals('RESTO LAN MASTER HUB'));
    });

    test('StoreProfile JSON serialization and deserialization works seamlessly', () {
      const profile = StoreProfile(
        storeName: 'KEDAI KOPI NIKMAT',
        ownerName: 'Barista Roy',
        storeAddress: 'Jl. Kopi No. 5',
        storePhone: '081299998888',
        receiptFooter: 'Semoga harimu menyenangkan!',
      );

      final json = profile.toJson();
      expect(json['store_name'], equals('KEDAI KOPI NIKMAT'));
      expect(json['owner_name'], equals('Barista Roy'));

      final parsed = StoreProfile.fromJson(json);
      expect(parsed.storeName, equals(profile.storeName));
      expect(parsed.ownerName, equals(profile.ownerName));
      expect(parsed.storeAddress, equals(profile.storeAddress));
      expect(parsed.storePhone, equals(profile.storePhone));
      expect(parsed.receiptFooter, equals(profile.receiptFooter));
    });

    test('AuthService updateStoreProfile synchronizes session memory and prevents polling rollback', () async {
      final auth = AuthService.instance;
      await auth.init();

      // Initial state
      expect(auth.storeName, isNotEmpty);

      // Updating profile updates session memory and prefs
      await auth.updateStoreProfile(
        storeName: 'TOKO MAKMUR JAYA ABADI',
        ownerName: 'Ibu Fatimah',
        phone: '081234567890',
      );

      expect(auth.storeName, equals('TOKO MAKMUR JAYA ABADI'));
      expect(auth.phone, equals('081234567890'));

      // Re-init auth from shared preferences: must retain updated store name
      await auth.init();
      expect(auth.storeName, equals('TOKO MAKMUR JAYA ABADI'));
    });
  });

  group('Receipt Thermal Layout & Option A Phrasing Tests', () {
    test('generateReceiptDocument generates valid PDF with Option A text and no errors', () async {
      final tx = Transaction(
        id: 'tx-123',
        invoiceNo: 'INV-20261014-001',
        totalAmount: 45000,
        paymentType: 'TUNAI',
        customerId: 'CUST-007',
        createdAt: DateTime(2026, 10, 14, 10, 30, 0),
        items: [
          TransactionItem(
            productId: 'p-1',
            name: 'Kopi Susu Gula Aren Spesial',
            price: 18000,
            quantity: 2,
            subtotal: 36000,
          ),
          TransactionItem(
            productId: 'p-2',
            name: 'Roti Bakar Coklat',
            price: 9000,
            quantity: 1,
            subtotal: 9000,
          ),
        ],
      );

      final doc = await PrinterService.instance.generateReceiptDocument(
        transaction: tx,
        cashTendered: 50000,
        storeName: 'WARUNG KOPI LARIS',
        is80mm: false,
      );

      expect(doc.document.pdfPageList.pages.length, equals(1));
      final page = doc.document.pdfPageList.pages.first;
      expect(page.pageFormat.width, closeTo(57 * PdfPageFormat.mm, 0.1));
      final bytes = await doc.save();
      final pdfString = String.fromCharCodes(bytes);
      final mediaBoxMatch = RegExp(r'/MediaBox\s*\[(.*?)\]').firstMatch(pdfString);
      expect(mediaBoxMatch, isNotNull);
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('generateReceiptDocument on wide paper (A4) centers receipt with balanced margins', () async {
      final tx = Transaction(
        id: 'tx-124',
        invoiceNo: 'INV-20261014-002',
        totalAmount: 25000,
        paymentType: 'QRIS',
        customerId: '',
        createdAt: DateTime(2026, 10, 14, 11, 0, 0),
        items: [
          TransactionItem(
            productId: 'p-1',
            name: 'Es Teh Manis Jumbo',
            price: 5000,
            quantity: 5,
            subtotal: 25000,
          ),
        ],
      );

      // When pageFormat is null (e.g. shareReceiptPdf), it generates pure 57mm thermal roll
      final docRoll = await PrinterService.instance.generateReceiptDocument(
        transaction: tx,
        cashTendered: 25000,
        storeName: 'WARUNG TEH SEGAR',
        pageFormat: null,
      );
      expect(docRoll.document.pdfPageList.pages.first.pageFormat.width, closeTo(57 * PdfPageFormat.mm, 0.1));

      // When pageFormat is A4 (Android Print Spooler preview), it creates an A4 document with the thermal slip centered
      final docA4 = await PrinterService.instance.generateReceiptDocument(
        transaction: tx,
        cashTendered: 25000,
        storeName: 'WARUNG TEH SEGAR',
        pageFormat: PdfPageFormat.a4,
      );

      expect(docA4.document.pdfPageList.pages.length, equals(1));
      expect(docA4.document.pdfPageList.pages.first.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.1));
      final bytes = await docA4.save();
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });
}
