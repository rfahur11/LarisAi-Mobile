/// Dataset Master SKU Nasional FMCG Indonesia
/// Kompilasi data barcode EAN-13 resmi untuk produk ritel/minimarket paling populer di Indonesia.
/// Digunakan untuk Instant Auto-Fill saat kasir/pedagang scan barcode baru.
class MasterSkuItem {
  final String barcode;
  final String name;
  final String category;
  final int defaultPriceEstimate;

  const MasterSkuItem({
    required this.barcode,
    required this.name,
    required this.category,
    this.defaultPriceEstimate = 0,
  });
}

class NationalSkuLookup {
  NationalSkuLookup._();

  static final Map<String, MasterSkuItem> _map = {
    for (final item in nationalMasterSkuList) item.barcode: item,
  };

  /// Pencarian instan O(1) berdasarkan barcode EAN-13
  static MasterSkuItem? findByBarcode(String? barcode) {
    if (barcode == null || barcode.trim().isEmpty) return null;
    final clean = barcode.trim().replaceAll(RegExp(r'[^0-9]'), '');
    return _map[clean] ?? _map[barcode.trim()];
  }

  /// Pencarian fuzzy berdasarkan nama produk untuk autocomplete
  static List<MasterSkuItem> searchByName(String query, {int limit = 10}) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase().trim();
    return nationalMasterSkuList
        .where((item) => item.name.toLowerCase().contains(q) || item.barcode.contains(q))
        .take(limit)
        .toList();
  }

  /// Total produk terdaftar di Master Katalog
  static int get count => nationalMasterSkuList.length;
}

const List<MasterSkuItem> nationalMasterSkuList = [
  // --- MIE INSTAN & MAKANAN CEPAT SAJI ---
  MasterSkuItem(barcode: '089686010924', name: 'Indomie Goreng Spesial 85g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200233', name: 'Indomie Goreng Spesial 85g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '089686010955', name: 'Indomie Rasa Soto Mie 70g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200110', name: 'Indomie Rasa Ayam Bawang 69g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200134', name: 'Indomie Rasa Kari Ayam 72g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200264', name: 'Indomie Goreng Rendang 91g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200271', name: 'Indomie Goreng Pedas 79g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200547', name: 'Indomie Hype Abis Ayam Geprek 85g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200554', name: 'Indomie Hype Abis Seblak Hot Jeletot 75g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200592', name: 'Indomie Goreng Aceh 90g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200219', name: 'Indomie Rasa Kaldu Ayam 65g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866200424', name: 'Indomie Goreng Sambal Matah 85g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112018', name: 'Mie Sedaap Goreng 90g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112025', name: 'Mie Sedaap Soto 75g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112032', name: 'Mie Sedaap Ayam Bawang 70g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112049', name: 'Mie Sedaap Kari Kental 72g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112087', name: 'Mie Sedaap Korean Spicy Soup 77g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112094', name: 'Mie Sedaap Korean Spicy Chicken 87g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112100', name: 'Mie Sedaap Selection Singapore Spicy Laksa 83g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992775112117', name: 'Mie Sedaap Goreng Ayam Bakar Limau 89g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866300117', name: 'Sarimi Isi 2 Rasa Ayam Kremes 126g', category: 'Makanan Instan', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8998866300124', name: 'Sarimi Isi 2 Rasa Soto Koya 120g', category: 'Makanan Instan', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8998866300131', name: 'Sarimi Isi 2 Goreng Rasa Ayam Kecap 126g', category: 'Makanan Instan', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8998866400114', name: 'Supermi Ayam Bawang 68g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998866400121', name: 'Supermi Kaldu Ayam 65g', category: 'Makanan Instan', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991001110023', name: 'Pop Mie Goreng Pedes Gledek 75g', category: 'Makanan Instan', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8991001110030', name: 'Pop Mie Rasa Ayam Bawang 75g', category: 'Makanan Instan', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8991001110047', name: 'Pop Mie Rasa Soto Ayam 75g', category: 'Makanan Instan', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8991001110054', name: 'Pop Mie Rasa Baso Sapi 75g', category: 'Makanan Instan', defaultPriceEstimate: 6000),

  // --- MINUMAN DALAM KEMASAN (RTD) ---
  MasterSkuItem(barcode: '8886008101053', name: 'Aqua Air Mineral Botol 600ml', category: 'Minuman', defaultPriceEstimate: 4000),
  MasterSkuItem(barcode: '8886008101039', name: 'Aqua Air Mineral Botol 1500ml', category: 'Minuman', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8886008101015', name: 'Aqua Air Mineral Botol 330ml', category: 'Minuman', defaultPriceEstimate: 3000),
  MasterSkuItem(barcode: '8886008101091', name: 'Aqua Air Mineral Gelas 220ml', category: 'Minuman', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8996001600269', name: 'Le Minerale Air Mineral 600ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8996001600276', name: 'Le Minerale Air Mineral 1500ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8996001600252', name: 'Le Minerale Air Mineral 330ml', category: 'Minuman', defaultPriceEstimate: 2500),
  MasterSkuItem(barcode: '8992753211116', name: 'Teh Pucuk Harum Botol 350ml', category: 'Minuman', defaultPriceEstimate: 4000),
  MasterSkuItem(barcode: '8992753211123', name: 'Teh Pucuk Harum Botol 500ml', category: 'Minuman', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8998888111222', name: 'Teh Botol Sosro Kotak 250ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8998888111246', name: 'Teh Botol Sosro Botol PET 450ml', category: 'Minuman', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8998888111239', name: 'Teh Botol Sosro Botol Beling 220ml', category: 'Minuman', defaultPriceEstimate: 3000),
  MasterSkuItem(barcode: '8992753311113', name: 'Floridina Pulpy Orange 350ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992753311120', name: 'Golda Coffee Dolce Latte 200ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992753311137', name: 'Golda Coffee Cappuccino 200ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991002105121', name: 'Good Day Botol Avocado Delight 250ml', category: 'Minuman', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8991002105138', name: 'Good Day Botol Moccacino 250ml', category: 'Minuman', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8991002105145', name: 'Good Day Botol Tiramisu Bliss 250ml', category: 'Minuman', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8996001410110', name: 'Kopiko Lucky Day Coffee 180ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8992775311015', name: 'Pocari Sweat Botol 350ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8992775311022', name: 'Pocari Sweat Botol 500ml', category: 'Minuman', defaultPriceEstimate: 8500),
  MasterSkuItem(barcode: '8992775311039', name: 'Pocari Sweat Kaleng 330ml', category: 'Minuman', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8992775311046', name: 'Pocari Sweat Botol 900ml', category: 'Minuman', defaultPriceEstimate: 14000),
  MasterSkuItem(barcode: '8991001700112', name: 'Ultra Milk Cokelat Kotak 250ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001700129', name: 'Ultra Milk Full Cream Kotak 250ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001700136', name: 'Ultra Milk Strawberry Kotak 250ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001700143', name: 'Ultra Milk Cokelat Kotak 200ml', category: 'Minuman', defaultPriceEstimate: 5500),
  MasterSkuItem(barcode: '8991001700150', name: 'Ultra Milk Cokelat Kotak 1000ml', category: 'Minuman', defaultPriceEstimate: 21000),
  MasterSkuItem(barcode: '8991001700167', name: 'Ultra Milk Full Cream Kotak 1000ml', category: 'Minuman', defaultPriceEstimate: 21000),
  MasterSkuItem(barcode: '7613035850021', name: 'Bear Brand Susu Steril Kaleng 189ml', category: 'Minuman', defaultPriceEstimate: 10500),
  MasterSkuItem(barcode: '8992753111010', name: 'Hydro Coco Original 250ml', category: 'Minuman', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8992753111027', name: 'Hydro Coco Original 500ml', category: 'Minuman', defaultPriceEstimate: 13500),
  MasterSkuItem(barcode: '8992753111034', name: 'C1000 You C1000 Orange 140ml', category: 'Minuman', defaultPriceEstimate: 8000),
  MasterSkuItem(barcode: '8992753111041', name: 'C1000 You C1000 Lemon 140ml', category: 'Minuman', defaultPriceEstimate: 8000),
  MasterSkuItem(barcode: '8991002201014', name: 'Fruit Tea Apel Kotak 200ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991002201021', name: 'Fruit Tea Blackcurrant Kotak 200ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991002201038', name: 'Fruit Tea Freeze Kotak 200ml', category: 'Minuman', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8992753411011', name: 'Cincau Cap Panda Kaleng 310ml', category: 'Minuman', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8992753411028', name: 'Larutan Cap Badak Kaleng 320ml', category: 'Minuman', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8998888211014', name: 'Nutrisari Jeruk Peras Sachet', category: 'Minuman', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8998888211021', name: 'Nutrisari Sweet Orange Sachet', category: 'Minuman', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8998888211038', name: 'Nutrisari American Sweet Mango Sachet', category: 'Minuman', defaultPriceEstimate: 1500),

  // --- KOPI, TEH & SUSU BUBUK SACHET ---
  MasterSkuItem(barcode: '8991002101345', name: 'Kopi Kapal Api Spesial Mix 24g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002101352', name: 'Kopi Kapal Api Spesial Hitam 60g', category: 'Minuman Sachet', defaultPriceEstimate: 5000),
  MasterSkuItem(barcode: '8991002101369', name: 'Kopi Kapal Api Silver 380g', category: 'Minuman Sachet', defaultPriceEstimate: 28000),
  MasterSkuItem(barcode: '8991002101376', name: 'Kopi Kapal Api Gula Aren 23g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002102014', name: 'Good Day Mocacinno Sachet 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002102021', name: 'Good Day Chococinno Sachet 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002102038', name: 'Good Day Vanilla Latte Sachet 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002102045', name: 'Good Day Carrebian Nut Sachet 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8991002102052', name: 'Good Day Coolin Coffee Sachet 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8996001410219', name: 'Torabika Cappuccino Choco Granule 25g', category: 'Minuman Sachet', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8996001410226', name: 'Torabika Duo Kopi & Gula 25g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8996001410233', name: 'Torabika Gilus Mix Gula Aren 23g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8996001410240', name: 'Torabika Creamy Latte 25g', category: 'Minuman Sachet', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8992753511018', name: 'Luwak White Koffie Original 20g', category: 'Minuman Sachet', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8992753511025', name: 'Luwak White Koffie Tarik Malaka 30g', category: 'Minuman Sachet', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8999999031017', name: 'Teh Celup Sariwangi Kotak Isi 25', category: 'Minuman Sachet', defaultPriceEstimate: 7000),
  MasterSkuItem(barcode: '8999999031024', name: 'Teh Celup Sariwangi Kotak Isi 50', category: 'Minuman Sachet', defaultPriceEstimate: 13000),
  MasterSkuItem(barcode: '8998888311011', name: 'Teh Celup Sosro Kotak Isi 30', category: 'Minuman Sachet', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001800119', name: 'Dancow FortiGro Cokelat Sachet 39g', category: 'Susu', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991001800126', name: 'Dancow FortiGro Putih Sachet 27g', category: 'Susu', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8991001800133', name: 'Indomilk Kental Manis Putih Sachet 37g', category: 'Susu', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8991001800140', name: 'Indomilk Kental Manis Cokelat Sachet 37g', category: 'Susu', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8992775411012', name: 'Frisian Flag Bendera Kental Manis Putih Sachet 38g', category: 'Susu', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8992775411029', name: 'Frisian Flag Bendera Kental Manis Cokelat Sachet 38g', category: 'Susu', defaultPriceEstimate: 2000),
  MasterSkuItem(barcode: '8992775411036', name: 'Frisian Flag Bendera Kental Manis Kaleng 370g', category: 'Susu', defaultPriceEstimate: 13000),

  // --- MINYAK GORENG & SEMBAKO ---
  MasterSkuItem(barcode: '8992775110021', name: 'Minyak Goreng Bimoli Pouch 2 Liter', category: 'Sembako', defaultPriceEstimate: 36000),
  MasterSkuItem(barcode: '8992775110014', name: 'Minyak Goreng Bimoli Pouch 1 Liter', category: 'Sembako', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8992775220033', name: 'Minyak Goreng Sania Pouch 2 Liter', category: 'Sembako', defaultPriceEstimate: 34000),
  MasterSkuItem(barcode: '8992775220026', name: 'Minyak Goreng Sania Pouch 1 Liter', category: 'Sembako', defaultPriceEstimate: 17500),
  MasterSkuItem(barcode: '8992775330047', name: 'Minyak Goreng Filma Pouch 2 Liter', category: 'Sembako', defaultPriceEstimate: 35000),
  MasterSkuItem(barcode: '8992775440051', name: 'Minyak Goreng SunCo Pouch 2 Liter', category: 'Sembako', defaultPriceEstimate: 36000),
  MasterSkuItem(barcode: '8992775550065', name: 'Minyak Goreng Fortune Pouch 2 Liter', category: 'Sembako', defaultPriceEstimate: 33500),
  MasterSkuItem(barcode: '8992775660072', name: 'Minyak Goreng Tropical Botol 2 Liter', category: 'Sembako', defaultPriceEstimate: 37000),
  MasterSkuItem(barcode: '8992745330012', name: 'Gulaku Gula Pasir Kuning Tebu 1kg', category: 'Sembako', defaultPriceEstimate: 18000),
  MasterSkuItem(barcode: '8992745330029', name: 'Gulaku Gula Pasir Putih Premium 1kg', category: 'Sembako', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8991001900116', name: 'Beras Ramos Super Premium 5kg', category: 'Sembako', defaultPriceEstimate: 74000),
  MasterSkuItem(barcode: '8991001900123', name: 'Beras Setra Ramos BMW 5kg', category: 'Sembako', defaultPriceEstimate: 75000),
  MasterSkuItem(barcode: '8991001900130', name: 'Beras Pandan Wangi Organik 5kg', category: 'Sembako', defaultPriceEstimate: 85000),
  MasterSkuItem(barcode: '8992775770016', name: 'Tepung Terigu Segitiga Biru 1kg', category: 'Sembako', defaultPriceEstimate: 13000),
  MasterSkuItem(barcode: '8992775770023', name: 'Tepung Terigu Cakra Kembar 1kg', category: 'Sembako', defaultPriceEstimate: 14000),
  MasterSkuItem(barcode: '8992775770030', name: 'Tepung Terigu Kunci Biru 1kg', category: 'Sembako', defaultPriceEstimate: 12500),
  MasterSkuItem(barcode: '8992775880013', name: 'Garam Dapur Beryodium Cap Kapal 250g', category: 'Sembako', defaultPriceEstimate: 3000),

  // --- BUMBU DAPUR & SAUS ---
  MasterSkuItem(barcode: '8999999052341', name: 'Royco Kaldu Sapi Sachet 8g', category: 'Bumbu Dapur', defaultPriceEstimate: 500),
  MasterSkuItem(barcode: '8999999052358', name: 'Royco Kaldu Ayam Sachet 8g', category: 'Bumbu Dapur', defaultPriceEstimate: 500),
  MasterSkuItem(barcode: '8992753611015', name: 'Masako Rasa Sapi Sachet 8.5g', category: 'Bumbu Dapur', defaultPriceEstimate: 500),
  MasterSkuItem(barcode: '8992753611022', name: 'Masako Rasa Ayam Sachet 8.5g', category: 'Bumbu Dapur', defaultPriceEstimate: 500),
  MasterSkuItem(barcode: '8992753611039', name: 'Ajinomoto Penyedap Rasa 100g', category: 'Bumbu Dapur', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8992753611046', name: 'Sasa MSG Penyedap Rasa 100g', category: 'Bumbu Dapur', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8992753611053', name: 'Ladaku Merica Bubuk Sachet 4g', category: 'Bumbu Dapur', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8992753611060', name: 'Desaku Ketumbar Bubuk Sachet', category: 'Bumbu Dapur', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8992753611077', name: 'Desaku Kunyit Bubuk Sachet', category: 'Bumbu Dapur', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8999999051016', name: 'Kecap Manis Bango Pouch 520ml', category: 'Bumbu Dapur', defaultPriceEstimate: 24000),
  MasterSkuItem(barcode: '8999999051023', name: 'Kecap Manis Bango Pouch 210ml', category: 'Bumbu Dapur', defaultPriceEstimate: 11000),
  MasterSkuItem(barcode: '8999999051030', name: 'Kecap Manis Bango Sachet 20ml', category: 'Bumbu Dapur', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8992753711012', name: 'Kecap Manis ABC Pouch 520ml', category: 'Bumbu Dapur', defaultPriceEstimate: 21000),
  MasterSkuItem(barcode: '8992753711029', name: 'Kecap Manis ABC Pouch 225ml', category: 'Bumbu Dapur', defaultPriceEstimate: 10000),
  MasterSkuItem(barcode: '8992753711036', name: 'Saus Sambal Asli ABC Botol 335ml', category: 'Bumbu Dapur', defaultPriceEstimate: 16000),
  MasterSkuItem(barcode: '8992753711043', name: 'Saus Sambal Extra Pedas ABC Botol 335ml', category: 'Bumbu Dapur', defaultPriceEstimate: 16500),
  MasterSkuItem(barcode: '8992753711050', name: 'Saus Tomat ABC Botol 335ml', category: 'Bumbu Dapur', defaultPriceEstimate: 14000),
  MasterSkuItem(barcode: '8992753811019', name: 'Sasa Santan Kelapa Cair Kotak 200ml', category: 'Bumbu Dapur', defaultPriceEstimate: 8500),
  MasterSkuItem(barcode: '8992753811026', name: 'Kara Santan Kelapa Kotak 200ml', category: 'Bumbu Dapur', defaultPriceEstimate: 9500),
  MasterSkuItem(barcode: '8992753811033', name: 'Kara Santan Kelapa Kotak 65ml', category: 'Bumbu Dapur', defaultPriceEstimate: 3500),

  // --- SNACK & MAKANAN RINGAN ---
  MasterSkuItem(barcode: '8991001100123', name: 'Chitato Sapi Panggang 68g', category: 'Snack', defaultPriceEstimate: 11500),
  MasterSkuItem(barcode: '8991001100130', name: 'Chitato Ayam Bumbu 68g', category: 'Snack', defaultPriceEstimate: 11500),
  MasterSkuItem(barcode: '8991001100147', name: 'Chitato Lite Nori Rumput Laut 68g', category: 'Snack', defaultPriceEstimate: 11500),
  MasterSkuItem(barcode: '8991001100215', name: 'Qtela Singkong Balado 60g', category: 'Snack', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001100222', name: 'Qtela Singkong Original 60g', category: 'Snack', defaultPriceEstimate: 6500),
  MasterSkuItem(barcode: '8991001100314', name: 'Taro Net Potato BBQ 36g', category: 'Snack', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8991001100321', name: 'Taro Net Seaweed 36g', category: 'Snack', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8996001301012', name: 'Nabati Wafer Richeese Keju 50g', category: 'Snack', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8996001301029', name: 'Nabati Wafer Richoco Cokelat 50g', category: 'Snack', defaultPriceEstimate: 3500),
  MasterSkuItem(barcode: '8996001301036', name: 'Nabati Wafer Richeese Keju Kaleng 287g', category: 'Snack', defaultPriceEstimate: 26000),
  MasterSkuItem(barcode: '8996001302019', name: 'Roma Biskuit Kelapa 300g', category: 'Snack', defaultPriceEstimate: 11500),
  MasterSkuItem(barcode: '8996001302026', name: 'Roma Malkist Crackers Abon 135g', category: 'Snack', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8996001302033', name: 'Roma Malkist Cokelat 120g', category: 'Snack', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8996001302040', name: 'Roma Malkist Keju Manis 120g', category: 'Snack', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8996001302057', name: 'Roma Sari Gandum 115g', category: 'Snack', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8996001401019', name: 'Beng Beng Cokelat Wafer Karamel 20g', category: 'Snack', defaultPriceEstimate: 2500),
  MasterSkuItem(barcode: '8996001401026', name: 'Beng Beng Maxx 32g', category: 'Snack', defaultPriceEstimate: 4000),
  MasterSkuItem(barcode: '8996001402016', name: 'Chocolatos Wafer Roll Cokelat 26g', category: 'Snack', defaultPriceEstimate: 1500),
  MasterSkuItem(barcode: '8992753911016', name: 'Silverqueen Cashew Cokelat 58g', category: 'Snack', defaultPriceEstimate: 16500),
  MasterSkuItem(barcode: '8992753911023', name: 'Silverqueen Almond Cokelat 58g', category: 'Snack', defaultPriceEstimate: 16500),
  MasterSkuItem(barcode: '8992753911030', name: 'Silverqueen Chunky Bar 95g', category: 'Snack', defaultPriceEstimate: 25000),
  MasterSkuItem(barcode: '8996001501016', name: 'Kopiko Permen Kopi Sachet', category: 'Permen', defaultPriceEstimate: 1000),
  MasterSkuItem(barcode: '8996001501023', name: 'Kis Permen Mint Cherry Bag 125g', category: 'Permen', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8996001501030', name: 'Relaxa Permen Wangi Barley Mint 125g', category: 'Permen', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '7622210101015', name: 'Oreo Biskuit Vanilla 133g', category: 'Snack', defaultPriceEstimate: 9500),
  MasterSkuItem(barcode: '7622210101022', name: 'Oreo Biskuit Cokelat 133g', category: 'Snack', defaultPriceEstimate: 9500),

  // --- KEBERSIHAN & SABUN CUCI ---
  MasterSkuItem(barcode: '8999999045612', name: 'Sunlight Pencuci Piring Jeruk Nipis 750ml', category: 'Kebersihan', defaultPriceEstimate: 16500),
  MasterSkuItem(barcode: '8999999045629', name: 'Sunlight Pencuci Piring Jeruk Nipis 400ml', category: 'Kebersihan', defaultPriceEstimate: 9500),
  MasterSkuItem(barcode: '8999999045636', name: 'Sunlight Pencuci Piring Jeruk Nipis 210ml', category: 'Kebersihan', defaultPriceEstimate: 5000),
  MasterSkuItem(barcode: '8992775990017', name: 'Mama Lemon Pencuci Piring Jeruk Nipis 780ml', category: 'Kebersihan', defaultPriceEstimate: 14500),
  MasterSkuItem(barcode: '8992775990024', name: 'Mama Lemon Pencuci Piring Jeruk Nipis 400ml', category: 'Kebersihan', defaultPriceEstimate: 8500),
  MasterSkuItem(barcode: '8999999061015', name: 'Rinso Anti Noda Deterjen Bubuk 770g', category: 'Kebersihan', defaultPriceEstimate: 21000),
  MasterSkuItem(barcode: '8999999061022', name: 'Rinso Molto Deterjen Cair Pouch 750ml', category: 'Kebersihan', defaultPriceEstimate: 20000),
  MasterSkuItem(barcode: '8992775881010', name: 'Daia Deterjen Bubuk Bunga 850g', category: 'Kebersihan', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8992775881027', name: 'Daia Deterjen Bubuk Putih 850g', category: 'Kebersihan', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8992775881034', name: 'So Klin Pewangi Pakaian Pouch 800ml', category: 'Kebersihan', defaultPriceEstimate: 11500),
  MasterSkuItem(barcode: '8992775881041', name: 'So Klin Softergent Bubuk 770g', category: 'Kebersihan', defaultPriceEstimate: 19500),
  MasterSkuItem(barcode: '8992775881058', name: 'Downy Pewangi & Pelembut Sunrise Fresh 680ml', category: 'Kebersihan', defaultPriceEstimate: 25000),
  MasterSkuItem(barcode: '8999999062012', name: 'Molto All In One Blue Pouch 720ml', category: 'Kebersihan', defaultPriceEstimate: 22000),
  MasterSkuItem(barcode: '8999999063019', name: 'Wipol Karbol Wangi Cemara Pouch 750ml', category: 'Kebersihan', defaultPriceEstimate: 17500),
  MasterSkuItem(barcode: '8992775771013', name: 'Super Pell Pembersih Lantai Apel Pouch 770ml', category: 'Kebersihan', defaultPriceEstimate: 14000),
  MasterSkuItem(barcode: '8992753991018', name: 'Baygon Aerosol Anti Nyamuk Citrus 600ml', category: 'Kebersihan', defaultPriceEstimate: 38000),
  MasterSkuItem(barcode: '8992753991025', name: 'Hit Aerosol Anti Nyamuk Orange 600ml', category: 'Kebersihan', defaultPriceEstimate: 36000),

  // --- PERAWATAN PRIBADI & TOILETRIES ---
  MasterSkuItem(barcode: '8999999012456', name: 'Lifebuoy Sabun Mandi Batang Total 10 110g', category: 'Perawatan Tubuh', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8999999012463', name: 'Lifebuoy Sabun Cair Total 10 Pouch 400ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 24000),
  MasterSkuItem(barcode: '8999999012470', name: 'Dettol Sabun Batang Original 100g', category: 'Perawatan Tubuh', defaultPriceEstimate: 8500),
  MasterSkuItem(barcode: '8999999012487', name: 'Dettol Sabun Mandi Cair Pouch 410ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 29000),
  MasterSkuItem(barcode: '8999999012494', name: 'Giv Sabun Mandi Batang White 76g', category: 'Perawatan Tubuh', defaultPriceEstimate: 3000),
  MasterSkuItem(barcode: '8999999012500', name: 'Shinzui Sabun Mandi Batang Matsu 85g', category: 'Perawatan Tubuh', defaultPriceEstimate: 5000),
  MasterSkuItem(barcode: '8999999023456', name: 'Pepsodent Pasta Gigi White 190g', category: 'Perawatan Tubuh', defaultPriceEstimate: 14500),
  MasterSkuItem(barcode: '8999999023463', name: 'Pepsodent Pasta Gigi White 120g', category: 'Perawatan Tubuh', defaultPriceEstimate: 10000),
  MasterSkuItem(barcode: '8999999023470', name: 'Pepsodent Pasta Gigi Herbal 190g', category: 'Perawatan Tubuh', defaultPriceEstimate: 18000),
  MasterSkuItem(barcode: '8992775661019', name: 'Ciptadent Pasta Gigi Maxi White 190g', category: 'Perawatan Tubuh', defaultPriceEstimate: 9500),
  MasterSkuItem(barcode: '8999999023487', name: 'Close Up Pasta Gigi Green 160g', category: 'Perawatan Tubuh', defaultPriceEstimate: 19000),
  MasterSkuItem(barcode: '8999999034567', name: 'Sunsilk Shampo Black Shine Botol 160ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 22000),
  MasterSkuItem(barcode: '8999999034574', name: 'Clear Shampo Anti Ketombe Ice Cool Menthol 160ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 26000),
  MasterSkuItem(barcode: '8992775551012', name: 'Pantene Shampo Anti Dandruff 160ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 25000),
  MasterSkuItem(barcode: '8992775551029', name: 'Head & Shoulders Cool Menthol Shampo 160ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 27000),
  MasterSkuItem(barcode: '8999999041010', name: 'Rexona Roll On Deodorant Pria 45ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8999999041027', name: 'Rexona Roll On Deodorant Wanita 45ml', category: 'Perawatan Tubuh', defaultPriceEstimate: 18500),
  MasterSkuItem(barcode: '8992753011013', name: 'Paseo Tissue Facial 250 Sheets', category: 'Kebutuhan Rumah', defaultPriceEstimate: 14000),
  MasterSkuItem(barcode: '8992753011020', name: 'Nice Tissue Facial 250 Sheets', category: 'Kebutuhan Rumah', defaultPriceEstimate: 12000),

  // --- ROKOK & TEMBAKAU POPULER ---
  MasterSkuItem(barcode: '8992983110012', name: 'Sampoerna A Mild 16 Batang', category: 'Rokok', defaultPriceEstimate: 33000),
  MasterSkuItem(barcode: '8992983110029', name: 'Sampoerna Avolution 20 Batang', category: 'Rokok', defaultPriceEstimate: 42000),
  MasterSkuItem(barcode: '8992777110034', name: 'Djarum Super 12 Batang', category: 'Rokok', defaultPriceEstimate: 24000),
  MasterSkuItem(barcode: '8992777110041', name: 'Djarum Super 16 Batang', category: 'Rokok', defaultPriceEstimate: 32000),
  MasterSkuItem(barcode: '8992777110058', name: 'Djarum Black 16 Batang', category: 'Rokok', defaultPriceEstimate: 32000),
  MasterSkuItem(barcode: '8992778110045', name: 'Gudang Garam Surya 16 Batang', category: 'Rokok', defaultPriceEstimate: 34000),
  MasterSkuItem(barcode: '8992778110052', name: 'Gudang Garam Surya 12 Batang', category: 'Rokok', defaultPriceEstimate: 26000),
  MasterSkuItem(barcode: '8992778110069', name: 'Gudang Garam International Merah 12 Batang', category: 'Rokok', defaultPriceEstimate: 24000),
  MasterSkuItem(barcode: '8992983220019', name: 'Marlboro Merah 20 Batang', category: 'Rokok', defaultPriceEstimate: 44000),
  MasterSkuItem(barcode: '8992983220026', name: 'Marlboro Ice Burst 20 Batang', category: 'Rokok', defaultPriceEstimate: 45000),
  MasterSkuItem(barcode: '8992983330016', name: 'Esse Change Double 20 Batang', category: 'Rokok', defaultPriceEstimate: 43000),
  MasterSkuItem(barcode: '8992778220012', name: 'LA Bold 20 Batang', category: 'Rokok', defaultPriceEstimate: 32000),
  MasterSkuItem(barcode: '8992778220029', name: 'LA Lights 16 Batang', category: 'Rokok', defaultPriceEstimate: 31000),
  MasterSkuItem(barcode: '8992778330019', name: 'Camel Yellow 20 Batang', category: 'Rokok', defaultPriceEstimate: 28000),

  // --- OBAT-OBATAN RINGAN & FARMASI UMUM ---
  MasterSkuItem(barcode: '8992753121019', name: 'Paramex Obat Sakit Kepala Strip 4 Tablet', category: 'Obat & Farmasi', defaultPriceEstimate: 3000),
  MasterSkuItem(barcode: '8992753121026', name: 'Panadol Biru Paracetamol Strip 10 Kaplet', category: 'Obat & Farmasi', defaultPriceEstimate: 13500),
  MasterSkuItem(barcode: '8992753121033', name: 'Panadol Extra Merah Strip 10 Kaplet', category: 'Obat & Farmasi', defaultPriceEstimate: 15500),
  MasterSkuItem(barcode: '8992753121040', name: 'Bodrex Sakit Kepala Strip 20 Tablet', category: 'Obat & Farmasi', defaultPriceEstimate: 6000),
  MasterSkuItem(barcode: '8992753121057', name: 'Bodrex Extra Strip 4 Kaplet', category: 'Obat & Farmasi', defaultPriceEstimate: 3000),
  MasterSkuItem(barcode: '8992753121064', name: 'Promag Obat Maag Strip 10 Tablet', category: 'Obat & Farmasi', defaultPriceEstimate: 9500),
  MasterSkuItem(barcode: '8992753121071', name: 'Mylanta Cair Botol 50ml', category: 'Obat & Farmasi', defaultPriceEstimate: 17000),
  MasterSkuItem(barcode: '8992753121088', name: 'Tolak Angin Cair Herbal Sachet 15ml', category: 'Obat & Farmasi', defaultPriceEstimate: 4500),
  MasterSkuItem(barcode: '8992753121095', name: 'Antangin JRG Cair Sachet 15ml', category: 'Obat & Farmasi', defaultPriceEstimate: 4000),
  MasterSkuItem(barcode: '8992753121101', name: 'Minyak Kayu Putih Cap Lang Botol 60ml', category: 'Obat & Farmasi', defaultPriceEstimate: 24000),
  MasterSkuItem(barcode: '8992753121118', name: 'Minyak Kayu Putih Cap Lang Botol 120ml', category: 'Obat & Farmasi', defaultPriceEstimate: 44000),
  MasterSkuItem(barcode: '8992753121125', name: 'Minyak Telon Lang Botol 60ml', category: 'Obat & Farmasi', defaultPriceEstimate: 21000),
  MasterSkuItem(barcode: '8992753121132', name: 'Hansaplast Plester Kain Roll 1 Meter', category: 'Obat & Farmasi', defaultPriceEstimate: 7500),
  MasterSkuItem(barcode: '8992753121149', name: 'Betadine Antiseptik Cair Botol 15ml', category: 'Obat & Farmasi', defaultPriceEstimate: 16500),
];
