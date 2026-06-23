import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/theme/app_colors.dart';
import '../common/sheep_widgets.dart';
import '../common/sheep_notifications.dart';
import '../../../../data/services/sheepify_scan_ai_service.dart';

class VoiceInputDialog extends StatefulWidget {
  const VoiceInputDialog({super.key});

  @override
  State<VoiceInputDialog> createState() => _VoiceInputDialogState();
}

class _VoiceInputDialogState extends State<VoiceInputDialog>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  bool _isSpeechAvailable = false;
  bool _isListening = false;
  String _textResult = '';
  String _statusMessage = 'Đang khởi động microphone...';
  
  late final AnimationController _waveController;
  final TextEditingController _textController = TextEditingController();
  bool _isProcessingAI = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    _initSpeech();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('=== [Speech Status] $status ===');
          if (mounted) {
            setState(() {
              if (status == 'listening') {
                _isListening = true;
                _statusMessage = 'Đang lắng nghe... Hãy nói đi';
              } else {
                _isListening = false;
                if (status == 'notListening') {
                  _statusMessage = _textResult.isNotEmpty
                      ? 'Đã ghi nhận giọng nói!'
                      : 'Đã dừng lắng nghe';
                }
              }
            });
          }
        },
        onError: (error) {
          debugPrint('=== [Speech Error] $error ===');
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage = 'Vui lòng thử nói lại hoặc gõ văn bản';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isSpeechAvailable = available;
          _statusMessage = available
              ? 'Chạm vào mic và nói câu lệnh của bạn'
              : 'Không hỗ trợ nhập giọng nói. Bạn hãy nhập bằng tay ở ô dưới nhé!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeechAvailable = false;
          _statusMessage = 'Không thể kết nối mic. Vui lòng gõ nội dung bên dưới.';
        });
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
    } else {
      if (!_isSpeechAvailable) {
        _initSpeech();
        return;
      }
      
      if (mounted) {
        setState(() {
          _textResult = '';
          _textController.clear();
          _isListening = true;
          _statusMessage = 'Đang kết nối mic...';
        });
      }
      
      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _textResult = result.recognizedWords;
                _textController.text = _textResult;
                if (result.finalResult) {
                  _statusMessage = 'Nhấp vào nút Hoàn thành hoặc nút gửi bên dưới';
                }
              });
            }
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: 'vi_VN', // Nhận diện tiếng Việt
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusMessage = 'Lỗi thu âm: $e';
          });
        }
      }
    }
  }

  Future<void> _processTextAndPrefill(String text) async {
    if (text.trim().isEmpty) {
      SheepNotifications.showError(context, 'Vui lòng nhập hoặc nói nội dung giao dịch!');
      return;
    }

    setState(() {
      _isProcessingAI = true;
      _statusMessage = 'AI đang phân tích câu lệnh...';
    });

    final result = await SheepifyScanAIService.processVoiceDescription(text);

    if (!mounted) return;

    setState(() {
      _isProcessingAI = false;
    });

    if (result != null) {
      Navigator.pop(context, result); // Trả kết quả ScannedTransactionModel về
    } else {
      SheepNotifications.showError(context, 'AI không thể phân tách giao dịch từ câu này. Hãy thử câu khác!');
      setState(() {
        _statusMessage = 'Hãy thử mô tả rõ ràng hơn (ví dụ: ăn trưa 50k)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(theme.brightness),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SheepRadius.sheet),
          ),
        ),
        padding: EdgeInsets.only(
          top: SheepSpacing.xl,
          left: SheepSpacing.page,
          right: SheepSpacing.page,
          bottom: MediaQuery.of(context).viewInsets.bottom + SheepSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(SheepRadius.sm),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                '🎙️ Nhập giao dịch bằng giọng nói',
                style: TextStyle(
                  fontSize: SheepTypeScale.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(theme.brightness),
                ),
              ),
              const SizedBox(height: 12),
              
              // Status or Voice recognized display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(minHeight: 52),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: SheepTypeScale.body,
                    fontWeight: FontWeight.w500,
                    color: _isListening ? accentColor : AppColors.getTextSecondary(theme.brightness),
                  ),
                ),
              ),
              
              // Animated Pulse Sound Wave Area
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Rings
                      if (_isListening)
                        ...List.generate(3, (index) {
                          return AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              final progress = (_waveController.value + (index / 3)) % 1.0;
                              return Container(
                                width: 78 + (progress * 80),
                                height: 78 + (progress * 80),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withValues(alpha: 0.18 * (1.0 - progress)),
                                ),
                              );
                            },
                          );
                        }),
                      
                      // Mic Button
                      GestureDetector(
                        onTap: _isProcessingAI ? null : _toggleListening,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? accentColor : AppColors.getSubtleSurface(theme.brightness),
                            border: Border.all(
                              color: _isListening ? Colors.transparent : AppColors.getBorder(theme.brightness),
                              width: 1.5,
                            ),
                            boxShadow: _isListening
                                ? [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.38),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                          child: Icon(
                            _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                            color: _isListening ? Colors.white : AppColors.getTextPrimary(theme.brightness),
                            size: 36,
                          ),
                        ),
                      ),
                      
                      if (_isProcessingAI)
                        const SizedBox(
                          width: 78,
                          height: 78,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Manual fallback text input
              TextField(
                controller: _textController,
                enabled: !_isProcessingAI,
                textInputAction: TextInputAction.send,
                onSubmitted: _processTextAndPrefill,
                decoration: InputDecoration(
                  hintText: 'Nhập mô tả bằng chữ',
                  hintStyle: TextStyle(color: AppColors.getTextSecondary(theme.brightness)),
                  filled: true,
                  fillColor: AppColors.getSubtleSurface(theme.brightness),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    borderSide: BorderSide(color: AppColors.getBorder(theme.brightness)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SheepRadius.md),
                    borderSide: BorderSide(color: accentColor),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send_rounded, color: accentColor),
                    onPressed: () => _processTextAndPrefill(_textController.text),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
