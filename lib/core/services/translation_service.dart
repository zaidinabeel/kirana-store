import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static const Duration _timeout = Duration(milliseconds: 2000);

  // High-frequency dictionary of grocery items and popular Indian brands
  static final Map<String, String> _commonDictionary = {
    'fevi kwik': 'फेवी क्विक',
    'fevikwik': 'फेवी क्विक',
    'fevicol': 'फेविकोल',
    'maggi': 'मैगी',
    'noodles': 'नूडल्स',
    'atta': 'आटा',
    'flour': 'आटा',
    'wheat': 'गेहूं',
    'salt': 'नमक',
    'sugar': 'चीनी',
    'tea': 'चाय',
    'coffee': 'कॉफ़ी',
    'oil': 'तेल',
    'mustard oil': 'सरसों का तेल',
    'refined oil': 'रिफाइंड तेल',
    'rice': 'चावल',
    'basmati': 'बासमती चावल',
    'dal': 'दाल',
    'toor dal': 'तूर दाल',
    'moong dal': 'मूंग दाल',
    'chana dal': 'चना दाल',
    'potato': 'आलू',
    'potatoes': 'आलू',
    'onion': 'प्याज़',
    'onions': 'प्याज़',
    'tomato': 'टमाटर',
    'tomatoes': 'टमाटर',
    'biscuit': 'बिस्कुट',
    'biscuits': 'बिस्कुट',
    'cookie': 'कुकीज़',
    'cookies': 'कुकीज़',
    'soap': 'साबुन',
    'detergent': 'डिटर्जेंट',
    'surf': 'सर्फ',
    'shampoo': 'शैम्पू',
    'toothpaste': 'टूथपेस्ट',
    'milk': 'दूध',
    'curd': 'दही',
    'paneer': 'पनीर',
    'butter': 'मक्खन',
    'ghee': 'शुद्ध घी',
    'spices': 'मसाले',
    'turmeric': 'हल्दी',
    'chilli': 'मिर्च',
    'coriander': 'धनिया',
    'cumin': 'जीरा',
    'nutella': 'नूटेला',
    'oreo': 'ओरियो',
    'cadbury': 'कैडबरी',
    'dairy milk': 'डेयरी मिल्क',
    'parle-g': 'पारले-जी',
    'parle g': 'पारले-जी',
    'good day': 'गुड डे',
    'kurkure': 'कुरकुरे',
    'lays': 'लेज़',
    'tata': 'टाटा',
    'amul': 'अमुल',
    'fortune': 'फॉर्च्यून',
    'aashirvaad': 'आशीर्वाद',
    'dettol': 'डेटॉल',
    'colgate': 'कोलगेट',
    'pepsodent': 'पेप्सोडेंट',
    'surf excel': 'सर्फ एक्सेल',
    'rin': 'रिन',
    'vim': 'विम',
  };

  /// Translate or transliterate English grocery name to Hindi Devanagari
  static Future<String?> translateToHindi(String englishName) async {
    final clean = englishName.trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();

    // 1. Direct dictionary match
    if (_commonDictionary.containsKey(lower)) {
      return _commonDictionary[lower];
    }

    // 2. Partial word replacement from dictionary
    String partialTranslated = clean;
    bool foundAnyWord = false;
    _commonDictionary.forEach((key, val) {
      final reg = RegExp(r'\b' + RegExp.escape(key) + r'\b', caseSensitive: false);
      if (reg.hasMatch(partialTranslated)) {
        partialTranslated = partialTranslated.replaceAll(reg, val);
        foundAnyWord = true;
      }
    });

    if (foundAnyWord) {
      return partialTranslated;
    }

    // 3. Online translation API fallback (MyMemory / Google Translation)
    try {
      final encoded = Uri.encodeComponent(clean);
      final uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=$encoded&langpair=en|hi',
      );
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText = data['responseData']?['translatedText'];
        if (translatedText != null &&
            translatedText.toString().trim().isNotEmpty &&
            !translatedText.toString().startsWith('MYMEMORY WARNING')) {
          return translatedText.toString().trim();
        }
      }
    } catch (_) {
      // Ignore network errors or timeouts
    }

    return null;
  }
}
