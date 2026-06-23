import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:hive/hive.dart';
import '../../core/constants/constants.dart';
import '../models/category_model.dart';

// ==========================================
// 1. MODEL DỮ LIỆU SAU KHI AI PARSE
// ==========================================
class ScannedTransactionModel {
  final int amount;
  final String category;
  final String note;
  final String date; // Trả về "TODAY" hoặc định dạng "YYYY-MM-DD"

  ScannedTransactionModel({
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
  });

  factory ScannedTransactionModel.fromJson(Map<String, dynamic> json) {
    return ScannedTransactionModel(
      amount: json['amount'] ?? 0,
      category: json['category'] ?? 'Khác',
      note: json['note'] ?? '',
      date: json['date'] ?? 'TODAY',
    );
  }

  @override
  String toString() {
    return 'ScannedTransactionModel(amount: $amount, category: $category, note: $note, date: $date)';
  }
}

// ==========================================
// 2. TỔNG HỢP SERVICE XỬ LÝ SCAN & AI
// ==========================================
class SheepifyScanAIService {
  // Đọc API Key của bạn lấy từ biến môi trường (Ví dụ: thông qua --dart-define-from-file=.env)
  static const String _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static String _getUserCategoriesString() {
    String categoryChoices = '"Ăn uống", "Di chuyển", "Mua sắm", "Hóa đơn", "Giải trí", "Khác"';
    try {
      if (Hive.isBoxOpen(kCatBox)) {
        final catBox = Hive.box<CategoryModel>(kCatBox);
        if (catBox.values.isNotEmpty) {
          categoryChoices = catBox.values.map((c) => '"${c.name}"').join(', ');
        }
      }
    } catch (e) {
      debugPrint("=== [Sheepify AI] Lỗi lấy danh mục người dùng: $e ===");
    }
    return categoryChoices;
  }

  /// Hàm tổng hợp: Đầu vào là file ảnh (XFile) -> Đầu ra là Data Model sạch để Pre-fill
  static Future<ScannedTransactionModel?> processInvoiceScan(XFile image) async {
    if (_geminiApiKey.isEmpty) {
      debugPrint("=== [Sheepify AI] Lỗi: GEMINI_API_KEY chưa được cấu hình. ===");
      debugPrint("Vui lòng tạo file .env hoặc chạy ứng dụng với `--dart-define-from-file=.env` ===");
      return null;
    }

    try {
      // Bước 1: Chạy Local OCR trích xuất chữ thô từ ảnh (Miễn phí hoàn toàn)
      debugPrint("=== [Sheepify AI] Đang chạy Local OCR... ===");
      final String rawText = await _extractTextFromImage(image);
      
      if (rawText.trim().isEmpty) {
        debugPrint("=== [Sheepify AI] Thất bại: Không tìm thấy chữ nào trong ảnh ===");
        return null;
      }
      debugPrint("=== [Sheepify AI] Text thô nhận diện được: \n$rawText\n ===");

      // Bước 2: Gửi Text thô lên Gemini API bóc tách thành JSON (Free Tier)
      debugPrint("=== [Sheepify AI] Đang gửi dữ liệu lên Gemini phân tích... ===");
      final ScannedTransactionModel? result = await _parseRawTextWithGemini(rawText);
      
      return result;
    } catch (e) {
      debugPrint("=== [Sheepify AI] Lỗi hệ thống trong quá trình xử lý: $e ===");
      return null;
    }
  }

  /// Private Method: Xử lý OCR cục bộ bằng Google ML Kit
  static Future<String> _extractTextFromImage(XFile image) async {
    final InputImage inputImage = InputImage.fromFilePath(image.path);
    // Sử dụng script Latin cho chữ tiếng Việt
    final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      await textRecognizer.close(); // Đảm bảo giải phóng bộ nhớ trên thiết bị
    }
  }

  /// Private Method: Gọi Gemini API với cấu trúc Prompt ép định dạng JSON
  static Future<ScannedTransactionModel?> _parseRawTextWithGemini(String rawText) async {
    final String categoryChoices = _getUserCategoriesString();
    final prompt = '''
Bạn là một trợ lý ảo phân tích hóa đơn tài chính chuyên nghiệp cho ứng dụng Sheepify.
Nhiệm vụ của bạn là đọc đoạn văn bản thô (OCR) thu được từ hóa đơn, biên lai, hoặc ảnh chụp màn hình giao dịch ngân hàng dưới đây, sau đó bóc tách thông tin thành cấu trúc cấu trúc JSON chính xác.

Yêu cầu nghiêm ngặt:
1. Chỉ trả về một chuỗi định dạng JSON duy nhất, KHÔNG sử dụng khối markdown (không bọc trong dấu ```json ... 
```), không có bất kỳ lời giải thích nào khác ngoài JSON.
2. Giá trị trường "category" chọn DUY NHẤT một trong các phân loại sau: $categoryChoices. Hãy dựa vào tên cửa hàng hoặc sản phẩm để phân loại một cách thông minh nhất. Nếu không trùng khớp, chọn phân loại gần nhất trong danh sách.
3. Giá trị trường "date" định dạng chuỗi "YYYY-MM-DD". Nếu hóa đơn không hiển thị rõ ngày tháng hoặc bạn không chắc chắn, hãy trả về chuỗi "TODAY".
4. Trường "amount" là số tiền tổng cuối cùng (int). Nếu không tìm thấy, để giá trị mặc định là 0.

Đoạn văn bản thô cần phân tích:
---------------------------------
$rawText
---------------------------------
''';

    final content = [Content.text(prompt)];

    // Danh sách các model để tự động fallback khi xảy ra lỗi 503 (quá tải) hoặc 429 (vượt hạn mức)
    final modelNames = [
      'gemini-2.5-flash',
      'gemini-flash-latest',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
    ];

    for (final modelName in modelNames) {
      try {
        debugPrint("=== [Sheepify AI] Thử phân tích bằng model: $modelName ===");
        final model = GenerativeModel(
          model: modelName,
          apiKey: _geminiApiKey,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'), // Ép kết quả trả về là JSON
        );
        final response = await model.generateContent(content);
        final String? jsonResponseText = response.text;

        if (jsonResponseText != null && jsonResponseText.trim().isNotEmpty) {
          debugPrint("=== [Sheepify AI] Thành công với model $modelName! JSON nhận từ Gemini: $jsonResponseText ===");
          final Map<String, dynamic> decodedJson = jsonDecode(jsonResponseText.trim());
          return ScannedTransactionModel.fromJson(decodedJson);
        }
      } catch (e) {
        debugPrint("=== [Sheepify AI] Model $modelName gặp lỗi: $e. Thử model tiếp theo... ===");
      }
    }

    debugPrint("=== [Sheepify AI] Lỗi: Tất cả các model trong danh sách fallback đều thất bại ===");
    return null;
  }

  /// Hàm phân tích câu nói/văn bản mô tả tự nhiên từ giọng nói thành dữ liệu sạch
  static Future<ScannedTransactionModel?> processVoiceDescription(String text) async {
    if (_geminiApiKey.isEmpty) {
      debugPrint("=== [Sheepify AI] Lỗi: GEMINI_API_KEY chưa được cấu hình. ===");
      return null;
    }

    try {
      debugPrint("=== [Sheepify AI] Bắt đầu gửi giọng nói lên Gemini phân tích... ===");
      return await _parseVoiceTextWithGemini(text);
    } catch (e) {
      debugPrint("=== [Sheepify AI] Lỗi hệ thống trong quá trình xử lý giọng nói: $e ===");
      return null;
    }
  }

  /// Private Method: Gửi mô tả giọng nói lên Gemini
  static Future<ScannedTransactionModel?> _parseVoiceTextWithGemini(String voiceText) async {
    final String categoryChoices = _getUserCategoriesString();
    final prompt = '''
Bạn là một trợ lý ảo phân tích giao dịch tài chính bằng giọng nói chuyên nghiệp cho ứng dụng Sheepify.
Nhiệm vụ của bạn là đọc đoạn mô tả giao dịch bằng giọng nói (hoặc văn bản tự nhiên) dưới đây, sau đó bóc tách thông tin thành cấu trúc JSON chính xác.

Yêu cầu nghiêm ngặt:
1. Chỉ trả về một chuỗi định dạng JSON duy nhất, KHÔNG sử dụng khối markdown (không bọc trong dấu ```json ... 
```), không có bất kỳ lời giải thích nào khác ngoài JSON.
2. Giá trị trường "category" chọn DUY NHẤT một trong các phân loại sau: $categoryChoices. Hãy dựa vào ngữ cảnh câu để phân loại một cách thông minh nhất. Nếu không trùng khớp, chọn phân loại gần nhất trong danh sách.
3. Giá trị trường "date" định dạng chuỗi "YYYY-MM-DD". Nếu mô tả có từ như "hôm qua", hãy tính ngày hôm qua dựa trên ngày hiện tại là ngày ${DateTime.now().toString().substring(0, 10)}. Nếu là "hôm nay" hoặc không nói rõ ngày, hãy trả về chuỗi "TODAY".
4. Trường "amount" là số tiền tổng cuối cùng (int). Nếu ghi "50k" hoặc "50 nghìn" hoặc "năm mươi ngàn", hãy chuyển thành số 50000. Nếu không tìm thấy, để giá trị mặc định là 0.
5. Trường "note" là ghi chú giao dịch ngắn gọn, viết hoa chữ cái đầu (ví dụ: "Ăn phở", "Mua trà sữa").

Đoạn văn bản mô tả giọng nói cần phân tích:
---------------------------------
$voiceText
---------------------------------
''';

    final content = [Content.text(prompt)];

    final modelNames = [
      'gemini-2.5-flash',
      'gemini-flash-latest',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash',
    ];

    for (final modelName in modelNames) {
      try {
        debugPrint("=== [Sheepify AI Voice] Thử phân tích bằng model: $modelName ===");
        final model = GenerativeModel(
          model: modelName,
          apiKey: _geminiApiKey,
          generationConfig: GenerationConfig(responseMimeType: 'application/json'), // Ép kết quả trả về là JSON
        );
        final response = await model.generateContent(content);
        final String? jsonResponseText = response.text;

        if (jsonResponseText != null && jsonResponseText.trim().isNotEmpty) {
          debugPrint("=== [Sheepify AI Voice] Thành công với model $modelName! JSON nhận từ Gemini: $jsonResponseText ===");
          final Map<String, dynamic> decodedJson = jsonDecode(jsonResponseText.trim());
          return ScannedTransactionModel.fromJson(decodedJson);
        }
      } catch (e) {
        debugPrint("=== [Sheepify AI Voice] Model $modelName gặp lỗi: $e. Thử model tiếp theo... ===");
      }
    }

    return null;
  }
}
