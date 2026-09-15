import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'app_database.dart';

class SeedData {
  static Future<void> populate(AppDatabase db) async {
    final existingCount = await db.select(db.categories).get();
    if (existingCount.isNotEmpty) return; // Already seeded

    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Categories
    final catStaples = const Uuid().v4();
    final catSnacks = const Uuid().v4();
    final catDairy = const Uuid().v4();
    final catPersonalCare = const Uuid().v4();
    final catVegetables = const Uuid().v4();

    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: catStaples,
        nameEn: 'Staples & Grains',
        nameHi: const Value('अनाज और दालें'),
        createdAt: now,
      ),
    );
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: catSnacks,
        nameEn: 'Biscuits & Snacks',
        nameHi: const Value('बिस्कुट और नमकीन'),
        createdAt: now,
      ),
    );
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: catDairy,
        nameEn: 'Dairy & Beverages',
        nameHi: const Value('दूध और चाय-कॉफ़ी'),
        createdAt: now,
      ),
    );
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: catPersonalCare,
        nameEn: 'Soaps & Cleaners',
        nameHi: const Value('साबुन और सर्फ'),
        createdAt: now,
      ),
    );
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: catVegetables,
        nameEn: 'Fresh Loose Produce',
        nameHi: const Value('सब्जियां और खुला सामान'),
        createdAt: now,
      ),
    );

    // 2. Realistic Indian Kirana Products
    final productsList = [
      // Packed Items with standard barcodes
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000010'),
        nameEn: 'Aashirvaad Shudh Chakki Atta 5kg',
        nameHi: const Value('आशीर्वाद शुध्द चक्की आटा 5 किग्रा'),
        categoryId: Value(catStaples),
        itemType: 'packed',
        unit: 'piece',
        price: 245.0,
        mrp: const Value(260.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('1101'),
        stockQty: const Value(18.0),
        reorderLevel: const Value(5.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000027'),
        nameEn: 'Tata Salt Vacuum Evaporated 1kg',
        nameHi: const Value('टाटा नमक 1 किग्रा'),
        categoryId: Value(catStaples),
        itemType: 'packed',
        unit: 'piece',
        price: 28.0,
        mrp: const Value(30.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('2501'),
        stockQty: const Value(45.0),
        reorderLevel: const Value(10.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000034'),
        nameEn: 'Fortune Premium Kachi Ghani Mustard Oil 1L',
        nameHi: const Value('फॉर्च्यून कच्ची घानी सरसों का तेल 1 लीटर'),
        categoryId: Value(catStaples),
        itemType: 'packed',
        unit: 'piece',
        price: 155.0,
        mrp: const Value(170.0),
        gstRate: const Value(5.0),
        hsnCode: const Value('1514'),
        stockQty: const Value(24.0),
        reorderLevel: const Value(6.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000041'),
        nameEn: 'Maggi 2-Minute Masala Noodles 70g',
        nameHi: const Value('मैगी 2-मिनट मसाला नूडल्स 70 ग्राम'),
        categoryId: Value(catSnacks),
        itemType: 'packed',
        unit: 'piece',
        price: 14.0,
        mrp: const Value(14.0),
        gstRate: const Value(12.0),
        hsnCode: const Value('1902'),
        stockQty: const Value(60.0),
        reorderLevel: const Value(12.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000058'),
        nameEn: 'Parle-G Gold Biscuits 100g',
        nameHi: const Value('पारले-जी गोल्ड बिस्कुट 100 ग्राम'),
        categoryId: Value(catSnacks),
        itemType: 'packed',
        unit: 'piece',
        price: 10.0,
        mrp: const Value(10.0),
        gstRate: const Value(18.0),
        hsnCode: const Value('1905'),
        stockQty: const Value(80.0),
        reorderLevel: const Value(15.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000065'),
        nameEn: 'Dettol Original Germ Protection Soap 75g',
        nameHi: const Value('डेटॉल ओरिजिनल साबुन 75 ग्राम'),
        categoryId: Value(catPersonalCare),
        itemType: 'packed',
        unit: 'piece',
        price: 38.0,
        mrp: const Value(40.0),
        gstRate: const Value(18.0),
        hsnCode: const Value('3401'),
        stockQty: const Value(3.0), // Low stock alert simulation!
        reorderLevel: const Value(8.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value('8901030000072'),
        nameEn: 'Taj Mahal Tea 250g Box',
        nameHi: const Value('ताज महल चाय 250 ग्राम'),
        categoryId: Value(catDairy),
        itemType: 'packed',
        unit: 'piece',
        price: 160.0,
        mrp: const Value(175.0),
        gstRate: const Value(5.0),
        hsnCode: const Value('0902'),
        stockQty: const Value(4.0), // Low stock alert simulation!
        reorderLevel: const Value(6.0),
        createdAt: now,
        updatedAt: now,
      ),

      // Loose Commodities (Weight-based)
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value(null),
        nameEn: 'Sugar (Loose Chini)',
        nameHi: const Value('चीनी (खुली)'),
        categoryId: Value(catStaples),
        itemType: 'loose',
        unit: 'kg',
        price: 44.0,
        mrp: const Value(48.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('1701'),
        stockQty: const Value(85.5),
        reorderLevel: const Value(20.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value(null),
        nameEn: 'Toor Dal Desi (Loose)',
        nameHi: const Value('तूर दाल देसी (खुली)'),
        categoryId: Value(catStaples),
        itemType: 'loose',
        unit: 'kg',
        price: 165.0,
        mrp: const Value(180.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('0713'),
        stockQty: const Value(42.0),
        reorderLevel: const Value(15.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value(null),
        nameEn: 'India Gate Basmati Rice (Loose)',
        nameHi: const Value('बासमती चावल (खुला)'),
        categoryId: Value(catStaples),
        itemType: 'loose',
        unit: 'kg',
        price: 110.0,
        mrp: const Value(125.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('1006'),
        stockQty: const Value(65.0),
        reorderLevel: const Value(20.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value(null),
        nameEn: 'Fresh Potatoes (Aloo)',
        nameHi: const Value('ताज़ा आलू'),
        categoryId: Value(catVegetables),
        itemType: 'loose',
        unit: 'kg',
        price: 30.0,
        mrp: const Value(35.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('0701'),
        stockQty: const Value(120.0),
        reorderLevel: const Value(30.0),
        createdAt: now,
        updatedAt: now,
      ),
      ProductsCompanion.insert(
        id: const Uuid().v4(),
        barcode: const Value(null),
        nameEn: 'Red Onions (Pyaaz)',
        nameHi: const Value('लाल प्याज़'),
        categoryId: Value(catVegetables),
        itemType: 'loose',
        unit: 'kg',
        price: 45.0,
        mrp: const Value(50.0),
        gstRate: const Value(0.0),
        hsnCode: const Value('0703'),
        stockQty: const Value(80.0),
        reorderLevel: const Value(25.0),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    for (final p in productsList) {
      await db.into(db.products).insert(p);
    }

    // 3. Khata Customers with realistic Indian names & contact numbers
    final cust1 = const Uuid().v4();
    final cust2 = const Uuid().v4();
    final cust3 = const Uuid().v4();

    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: cust1,
        name: 'Ramesh Kumar (Sharma Ji)',
        phone: const Value('9810123456'),
        address: const Value('House #42, Lane 3, Subhash Nagar'),
        openingBalance: const Value(850.0),
        createdAt: now,
      ),
    );

    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: cust2,
        name: 'Anita Devi (Masterji)',
        phone: const Value('9876543210'),
        address: const Value('Flat 102, Shanti Enclave'),
        openingBalance: const Value(1420.0),
        createdAt: now,
      ),
    );

    await db.into(db.customers).insert(
      CustomersCompanion.insert(
        id: cust3,
        name: 'Sunil Verma (Electrician)',
        phone: const Value('9911223344'),
        address: const Value('Shop #8, Main Market Road'),
        openingBalance: const Value(0.0),
        createdAt: now,
      ),
    );

    // 4. Default Shop & Printer Settings
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'shop_name', value: 'Gupta Kirana & General Store'),
    );
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'shop_address', value: 'Plot 14, Main Mandi Road, Ghaziabad'),
    );
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'shop_phone', value: '+91 98112 34567'),
    );
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'gstin', value: '07AAAAA0000A1Z5'),
    );
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'paper_width', value: '58mm'),
    );
    await db.into(db.settings).insert(
      SettingsCompanion.insert(key: 'bill_footer', value: 'धन्यवाद! फिर पधारें | No exchange on loose goods'),
    );
  }
}
