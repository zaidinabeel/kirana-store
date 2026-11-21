/// Offline Hindi help: step-by-step guides plus a simple question matcher.
///
/// No internet or AI needed. Keywords include Hindi, Hinglish (Roman Hindi)
/// and English so a question typed any of these ways finds the right guide.
class HelpTopic {
  final String id;
  final String title;
  final String icon; // emoji, shown large for easy recognition
  final List<String> steps;
  final List<String> keywords;
  final String? tip;

  const HelpTopic({
    required this.id,
    required this.title,
    required this.icon,
    required this.steps,
    required this.keywords,
    this.tip,
  });
}

const List<HelpTopic> helpTopics = [
  HelpTopic(
    id: 'first_bill',
    icon: '🧾',
    title: 'नया बिल कैसे बनाएं',
    steps: [
      'नीचे "बिल" बटन दबाएं, या होम पर "नया बिल" दबाएं।',
      'सामान का बारकोड स्कैन करें (📷 बटन), या ऊपर खोज में सामान का नाम लिखें।',
      'मात्रा बदलनी हो तो सामान पर + या − दबाएं।',
      'नीचे पीला बटन "बिल पक्का करें" दबाएं।',
      'नकद, UPI या उधार चुनें और पक्का करें।',
      'बिल अपने आप सेव हो जाता है। प्रिंट या WhatsApp पर भेज सकते हैं।',
    ],
    keywords: ['बिल', 'बिक्री', 'बेचना', 'बेचें', 'नया बिल', 'bill', 'bil', 'naya bill', 'sale', 'bechna', 'becho', 'invoice', 'grahak', 'ग्राहक'],
  ),
  HelpTopic(
    id: 'loose_item',
    icon: '⚖️',
    title: 'खुला सामान (₹50 की चीनी) कैसे बेचें',
    steps: [
      'बिल स्क्रीन पर "खुला सामान" बटन दबाएं।',
      'चीनी, चावल जैसा सामान चुनें।',
      'ग्राहक ने जितने रुपये का माँगा, वो रकम लिखें (जैसे ₹50)।',
      'ऐप अपने आप वजन निकाल देगा (जैसे 1.136 किलो)।',
      'या सीधा वजन लिखें — दाम अपने आप बन जाएगा।',
    ],
    keywords: ['खुला', 'तौल', 'वजन', 'किलो', 'ग्राम', 'loose', 'khula', 'wajan', 'vajan', 'kilo', 'kg', 'gram', 'chini', 'चीनी', 'चावल', 'dal', 'दाल', 'rupees ka'],
  ),
  HelpTopic(
    id: 'add_product',
    icon: '📦',
    title: 'नया सामान कैसे जोड़ें',
    steps: [
      'होम पर "सामान स्कैन करें" दबाएं।',
      'सामान के पैकेट का बारकोड कैमरे के सामने रखें।',
      'अगर सामान नया है तो एक छोटा फॉर्म खुलेगा। नाम अक्सर इंटरनेट से अपने आप भर जाता है।',
      'बेचने का दाम और कितने पीस आए, लिखें।',
      '"सेव करें" दबाएं — बस! अगला सामान स्कैन करें।',
      'बिना बारकोड वाला सामान: स्कैन स्क्रीन पर "बिना बारकोड वाला" बटन दबाएं।',
    ],
    tip: 'एक साथ कई सामान जोड़ने हों तो स्कैन स्क्रीन खुली रखें, एक-एक करके स्कैन करते जाएं।',
    keywords: ['नया सामान', 'जोड़', 'जोड़ें', 'प्रोडक्ट', 'आइटम', 'add', 'jodna', 'jode', 'jodo', 'naya saman', 'saman', 'samaan', 'product', 'item', 'barcode', 'बारकोड', 'स्कैन', 'scan'],
  ),
  HelpTopic(
    id: 'stock_in',
    icon: '📥',
    title: 'माल आया — स्टॉक कैसे बढ़ाएं',
    steps: [
      'होम पर "सामान स्कैन करें" दबाएं।',
      'हर पैकेट को स्कैन करें — हर स्कैन पर स्टॉक 1 बढ़ जाता है।',
      'एक जैसे बहुत पैकेट हों तो एक बार स्कैन करके सूची में + दबाते जाएं, या संख्या लिखें।',
      'गलती हो जाए तो सूची में − दबाएं।',
      '"हो गया" दबाकर बंद करें।',
    ],
    keywords: ['स्टॉक', 'माल', 'माल आया', 'खरीद', 'stock', 'maal', 'mal aaya', 'purchase', 'kharid', 'badhana', 'बढ़ाना', 'inventory'],
  ),
  HelpTopic(
    id: 'low_stock',
    icon: '⚠️',
    title: 'कौन सा सामान खत्म होने वाला है',
    steps: [
      'होम स्क्रीन पर लाल पट्टी में "कम स्टॉक" दिखता है।',
      'उस पर दबाएं — खत्म होने वाले सारे सामान की सूची खुल जाएगी।',
      'हर सामान के लिए "कम स्टॉक की सीमा" सामान के फॉर्म में बदल सकते हैं।',
    ],
    keywords: ['कम स्टॉक', 'खत्म', 'मंगवाना', 'low', 'khatam', 'kam stock', 'reorder', 'mangwana'],
  ),
  HelpTopic(
    id: 'khata_credit',
    icon: '📒',
    title: 'उधार (खाता) कैसे लिखें',
    steps: [
      'नीचे "खाता" दबाएं।',
      'ग्राहक चुनें, या नया ग्राहक जोड़ें (नाम + मोबाइल नंबर)।',
      'लाल बटन "आपने दिया ₹" दबाकर उधार की रकम लिखें।',
      'बिल बनाते समय भुगतान में "उधार" चुनने पर भी रकम अपने आप खाते में जुड़ जाती है।',
    ],
    keywords: ['उधार', 'खाता', 'बाकी', 'udhar', 'udhaar', 'khata', 'credit', 'baki', 'baaki', 'ledger', 'customer'],
  ),
  HelpTopic(
    id: 'khata_payment',
    icon: '💰',
    title: 'ग्राहक ने उधार चुकाया — कैसे लिखें',
    steps: [
      '"खाता" में ग्राहक का नाम दबाएं।',
      'हरा बटन "आपको मिला ₹" दबाएं।',
      'जितने पैसे मिले वो लिखें और नकद/UPI चुनें।',
      'बाकी रकम अपने आप कम हो जाएगी।',
    ],
    keywords: ['चुकाया', 'जमा', 'पैसे मिले', 'भुगतान', 'payment', 'jama', 'chukaya', 'paise mile', 'wapas', 'वापस', 'collect'],
  ),
  HelpTopic(
    id: 'khata_whatsapp',
    icon: '💬',
    title: 'ग्राहक को WhatsApp पर हिसाब भेजें',
    steps: [
      '"खाता" में ग्राहक खोलें।',
      'ऊपर शेयर बटन दबाएं।',
      'WhatsApp चुनें — पूरा हिसाब और बाकी रकम चली जाएगी।',
      'सेटिंग में अपना UPI ID डालें तो ग्राहक सीधे UPI से चुका सकता है।',
    ],
    keywords: ['whatsapp', 'वॉट्सऐप', 'व्हाट्सएप', 'भेजना', 'हिसाब', 'statement', 'bhejna', 'hisab', 'hisaab', 'share', 'शेयर', 'reminder', 'yaad'],
  ),
  HelpTopic(
    id: 'bill_share',
    icon: '📲',
    title: 'बिल WhatsApp पर भेजें',
    steps: [
      'बिल पक्का करने के बाद रसीद खुलती है।',
      'शेयर बटन दबाएं और WhatsApp चुनें।',
      'पुराना बिल: होम पर "हाल के बिल" में बिल दबाएं, फिर शेयर करें।',
    ],
    keywords: ['बिल भेजना', 'रसीद', 'bill bhejna', 'receipt', 'raseed', 'rasid', 'share bill', 'purana bill', 'पुराना बिल'],
  ),
  HelpTopic(
    id: 'printer_connect',
    icon: '🖨️',
    title: 'ब्लूटूथ प्रिंटर कैसे जोड़ें',
    steps: [
      'प्रिंटर चालू करें और उसमें कागज़ डालें।',
      'फ़ोन की सेटिंग → ब्लूटूथ में जाएं। प्रिंटर का नाम दबाकर "पेयर" करें (PIN अक्सर 0000 या 1234 होता है)।',
      'अब ऐप में "सेटिंग" → "प्रिंटर" में "प्रिंटर खोजें" दबाएं।',
      'सूची में अपना प्रिंटर दबाएं — "जुड़ गया" लिखा आएगा।',
      '"टेस्ट प्रिंट" दबाकर जाँच लें।',
      'कागज़ 58mm (छोटा) है या 80mm (बड़ा), वो सेटिंग में चुनें।',
    ],
    tip: 'प्रिंटर नहीं दिख रहा? पहले फ़ोन की ब्लूटूथ सेटिंग में पेयर करना ज़रूरी है।',
    keywords: ['प्रिंटर', 'प्रिंट', 'ब्लूटूथ', 'printer', 'print', 'bluetooth', 'jodna', 'connect', 'pair', 'पेयर', 'thermal', 'मशीन', 'machine'],
  ),
  HelpTopic(
    id: 'receipt_options',
    icon: '✂️',
    title: 'रसीद पर क्या छपे — चालू/बंद करें',
    steps: [
      '"सेटिंग" → "रसीद पर क्या छपे" में जाएं।',
      'पता, फ़ोन, GST नंबर, ग्राहक का नाम, टैक्स, बारकोड — हर एक को चालू/बंद करें।',
      'नीचे बदलाव तुरंत दिखता है।',
      '"बिल बनते ही प्रिंट" चालू करें तो हर बिल अपने आप छपेगा।',
    ],
    keywords: ['रसीद', 'छपे', 'छपाई', 'बंद', 'चालू', 'receipt', 'chhape', 'chapai', 'band', 'chalu', 'toggle', 'option', 'gst number', 'barcode', 'auto print'],
  ),
  HelpTopic(
    id: 'printer_problem',
    icon: '🔧',
    title: 'प्रिंट नहीं हो रहा',
    steps: [
      'प्रिंटर चालू है और उसमें कागज़ है — जाँचें।',
      'फ़ोन का ब्लूटूथ चालू करें।',
      'सेटिंग → प्रिंटर में दोबारा प्रिंटर चुनें।',
      'प्रिंटर बंद करके 10 सेकंड बाद फिर चालू करें।',
      'अक्षर बहुत छोटे/बड़े हों तो कागज़ का साइज़ (58mm/80mm) सही चुनें।',
    ],
    keywords: ['प्रिंट नहीं', 'खराब', 'नहीं हो रहा', 'not printing', 'print nahi', 'problem', 'samasya', 'समस्या', 'error', 'kharab', 'blank', 'खाली'],
  ),
  HelpTopic(
    id: 'backup',
    icon: '💾',
    title: 'बैकअप — डेटा सुरक्षित कैसे रखें',
    steps: [
      'ऐप हर दिन अपने आप बैकअप बना लेता है।',
      'बैकअप फ़ोन में "Documents → KiranaStore → Backups" फ़ोल्डर में रहता है।',
      'ऐप डिलीट होने पर भी यह फ़ोल्डर फ़ोन में बचा रहता है।',
      'ज़्यादा सुरक्षा के लिए: सेटिंग → बैकअप → "बैकअप बनाकर भेजें" दबाएं और WhatsApp या Google Drive पर भेज दें।',
    ],
    tip: 'हफ़्ते में एक बार बैकअप WhatsApp पर खुद को भेज दें — फ़ोन खो जाए तब भी हिसाब बचा रहेगा।',
    keywords: ['बैकअप', 'सुरक्षित', 'डेटा', 'backup', 'data', 'surakshit', 'safe', 'save', 'drive', 'google drive', 'khona', 'खोना', 'delete'],
  ),
  HelpTopic(
    id: 'restore',
    icon: '♻️',
    title: 'नया फ़ोन — पुराना हिसाब वापस लाएं',
    steps: [
      'नए फ़ोन में यह ऐप डालें।',
      'पुरानी बैकअप फ़ाइल नए फ़ोन में लाएं (WhatsApp से डाउनलोड करें या Drive से)।',
      'सेटिंग → बैकअप → "बैकअप से वापस लाएं" दबाएं।',
      'बैकअप फ़ाइल चुनें और "हाँ" दबाएं।',
      'सारा सामान, बिल और खाता वापस आ जाएगा।',
    ],
    tip: 'वापस लाने से पहले ऐप अभी वाले डेटा का भी बैकअप बना लेता है, इसलिए कुछ नहीं खोता।',
    keywords: ['वापस', 'नया फ़ोन', 'restore', 'wapas', 'naya phone', 'new phone', 'phone badla', 'फ़ोन बदला', 'recover', 'purana data', 'पुराना डेटा'],
  ),
  HelpTopic(
    id: 'shop_name',
    icon: '🏪',
    title: 'दुकान का नाम, पता, GST नंबर बदलें',
    steps: [
      'नीचे "सेटिंग" दबाएं।',
      '"दुकान की जानकारी" में नाम, पता, फ़ोन और GST नंबर लिखें।',
      '"सेव करें" दबाएं। अब हर रसीद पर यही छपेगा।',
    ],
    keywords: ['दुकान', 'नाम', 'पता', 'जीएसटी', 'shop', 'dukan', 'naam', 'name', 'address', 'pata', 'gst', 'gstin', 'upi'],
  ),
  HelpTopic(
    id: 'language',
    icon: '🌐',
    title: 'भाषा बदलें (हिंदी / English)',
    steps: [
      'ऊपर दाईं तरफ़ "EN / हिंदी" बटन दबाएं।',
      'या सेटिंग → भाषा में चुनें। ऐप आपकी पसंद याद रखता है।',
    ],
    keywords: ['भाषा', 'हिंदी', 'अंग्रेज़ी', 'language', 'bhasha', 'hindi', 'english', 'angrezi'],
  ),
  HelpTopic(
    id: 'void_bill',
    icon: '❌',
    title: 'गलत बिल रद्द करें',
    steps: [
      'होम पर "हाल के बिल" में वो बिल दबाएं।',
      'ऊपर ❌ (रद्द करें) बटन दबाएं और पक्का करें।',
      'स्टॉक और उधार अपने आप वापस ठीक हो जाते हैं।',
    ],
    keywords: ['रद्द', 'गलत बिल', 'कैंसल', 'cancel', 'void', 'galat', 'radd', 'delete bill', 'mitana', 'मिटाना'],
  ),
  HelpTopic(
    id: 'gst_bill',
    icon: '🏷️',
    title: 'GST बिल या सादा बिल',
    steps: [
      'बिल स्क्रीन पर "जीएसटी बिल / साधारण बिल" वाला बटन चालू/बंद करें।',
      'चालू करने पर हर सामान का GST अलग से जुड़ता है (CGST + SGST)।',
      'GST नहीं लेते तो इसे बंद रखें — साधारण बिल (कैश मेमो) बनेगा।',
      'सामान का GST % नया सामान जोड़ते समय "और जानकारी" में भरें।',
    ],
    keywords: ['जीएसटी', 'टैक्स', 'कर', 'gst', 'tax', 'cgst', 'sgst', 'hsn', 'sada bill', 'सादा'],
  ),
  HelpTopic(
    id: 'reports',
    icon: '📊',
    title: 'हिसाब और मुनाफ़ा कैसे देखें',
    steps: [
      'होम पर "हिसाब / मुनाफ़ा" दबाएं।',
      'ऊपर आज, कल, इस हफ़्ते, इस महीने या पिछला महीना चुनें।',
      'कुल बिक्री, बिल की गिनती और शुद्ध मुनाफ़ा (खर्च घटाकर) दिखेगा।',
      'नीचे: पैसे कैसे आए (नकद/UPI/उधार), किसका कितना उधार बाकी है, और सबसे ज़्यादा बिकने वाला सामान।',
    ],
    tip: 'मुनाफ़ा सही दिखे इसके लिए सामान जोड़ते समय "खरीद का दाम" भरें, और खर्च लिखते रहें।',
    keywords: ['हिसाब', 'मुनाफ़ा', 'मुनाफा', 'फायदा', 'रिपोर्ट', 'कमाई', 'hisab', 'hisaab', 'munafa', 'fayda', 'profit', 'report', 'kamai', 'kitna kamaya'],
  ),
  HelpTopic(
    id: 'expenses',
    icon: '🧾',
    title: 'दुकान का खर्च कैसे लिखें',
    steps: [
      'होम पर "खर्च लिखें" दबाएं।',
      'नीचे पीला बटन "खर्च जोड़ें" दबाएं।',
      'किराया, बिजली, मज़दूरी जैसा खर्च चुनें, रकम लिखें और "सेव करें" दबाएं।',
      'गलत लिखा हो तो उस खर्च को देर तक दबाकर हटाएं।',
    ],
    keywords: ['खर्च', 'किराया', 'बिजली', 'मज़दूरी', 'तनख्वाह', 'kharch', 'kharcha', 'kiraya', 'bijli', 'expense', 'rent', 'salary', 'majduri'],
  ),
  HelpTopic(
    id: 'pin_lock',
    icon: '🔒',
    title: 'PIN लॉक लगाएं / PIN भूल गए',
    steps: [
      'सेटिंग → "PIN लॉक" खोलें।',
      '"ऐप खोलने पर PIN माँगे" चालू करें और 4 अंक का PIN दो बार डालें।',
      'अब ऐप खोलने पर (या 1 मिनट से ज़्यादा बाहर रहने पर) PIN माँगा जाएगा।',
      'PIN भूल गए: ऐप हटाकर फिर डालें, फिर सेटिंग → बैकअप → "बैकअप से वापस लाएं"। सारा डेटा आ जाएगा, पुराना PIN नहीं।',
    ],
    keywords: ['पिन', 'लॉक', 'पासवर्ड', 'भूल', 'pin', 'lock', 'password', 'bhool', 'bhul gaya', 'tala', 'ताला', 'suraksha'],
  ),
  HelpTopic(
    id: 'todays_sale',
    icon: '📊',
    title: 'आज की बिक्री कितनी हुई',
    steps: [
      'होम स्क्रीन पर सबसे ऊपर "आज की कुल बिक्री" दिखती है।',
      'नीचे आज के बिल की गिनती और हाल के बिल भी दिखते हैं।',
    ],
    keywords: ['बिक्री', 'कमाई', 'आज', 'हिसाब', 'sale', 'aaj', 'kamai', 'today', 'total', 'kitna', 'कितना', 'report'],
  ),
];

/// Matches a free-text question (Hindi, Hinglish or English) to help topics.
class HelpSearch {
  static final _splitter = RegExp(r'[\s,.?!।/\-]+');

  static String normalize(String s) => s
      .toLowerCase()
      .replaceAll('ज़', 'ज')
      .replaceAll('फ़', 'फ')
      .replaceAll('ड़', 'ड')
      .replaceAll('़', '')
      .trim();

  /// Best matches first. Empty list when nothing matches.
  static List<HelpTopic> search(String query, {int limit = 3}) {
    final q = normalize(query);
    if (q.isEmpty) return const [];
    final words = q.split(_splitter).where((w) => w.length >= 2).toList();

    final scored = <MapEntry<HelpTopic, int>>[];
    for (final topic in helpTopics) {
      var score = 0;
      final title = normalize(topic.title);
      for (final raw in topic.keywords) {
        final k = normalize(raw);
        if (k.contains(' ')) {
          if (q.contains(k)) score += 4; // multi-word phrase match
        } else {
          for (final w in words) {
            if (w == k) {
              score += 3;
            } else if (w.length >= 3 && k.length >= 3 && (w.startsWith(k) || k.startsWith(w))) {
              score += 2;
            }
          }
        }
      }
      for (final w in words) {
        if (w.length >= 3 && title.contains(w)) score += 1;
      }
      if (score > 0) scored.add(MapEntry(topic, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(limit).map((e) => e.key).toList();
  }
}
