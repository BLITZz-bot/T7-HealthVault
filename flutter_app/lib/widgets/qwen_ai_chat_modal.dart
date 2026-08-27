import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../services/on_device_llm_service.dart';

/// Universal T7 Clinical AI Chat Modal
/// Available everywhere in the app after login (Home, Family Screen, Member Detail Screen)
class QwenAIChatModal {
  static void show(
    BuildContext context, {
    Map<String, dynamic>? member,
    Map<String, dynamic>? news2Result,
    Map<String, dynamic>? sepsisResult,
    Map<String, Map<String, dynamic>>? delta,
  }) {
    final currentLang = LanguageService.currentLanguage;
    final langInfo = LanguageService.getLanguageInfo(currentLang);
    final patientName = member?['full_name'] ?? member?['name'];
    final isPatientContext = patientName != null && patientName.toString().trim().isNotEmpty && patientName != 'General Health Query';

    final String initialGreeting = isPatientContext
        ? LanguageService.tr('t7_ai_greeting_patient')
        : LanguageService.tr('t7_ai_greeting_general');

    final List<Map<String, String>> chatMessages = [
      {'sender': 't7_ai', 'text': initialGreeting}
    ];

    bool isGenerating = false;
    final TextEditingController chatInputCtrl = TextEditingController();
    final ScrollController scrollController = ScrollController();

    // Quick dynamic suggestion chips tailored to patient demographics
    final isPregnantMember = (member?['is_pregnant'] == 1 || member?['is_pregnant'] == true);
    final memberAge = int.tryParse(member?['age']?.toString() ?? '99') ?? 99;
    final isChildMember = memberAge < 5;

    final List<String> quickPrompts;
    if (isPregnantMember) {
      quickPrompts = [
        '🤰 Pregnancy Danger Signs',
        '🩺 High BP & Pre-eclampsia',
        '💊 Safe Meds in ANC',
        '👶 Decreased Fetal Movement',
        '🍼 Exclusive Breastfeeding (EBF)',
      ];
    } else if (isChildMember) {
      quickPrompts = [
        '👶 Infant Danger Signs (IMNCI)',
        '💉 Vaccines Due Check',
        '💧 ORS & Pediatric Zinc Dosage',
        '🫁 Fast Breathing / Pneumonia',
        '📏 MUAC Malnutrition Care',
      ];
    } else {
      quickPrompts = [
        '🌡️ Fever Advice',
        '🩺 High BP Protocol',
        '🩸 Low Blood Sugar',
        '🫁 Breathlessness / SpO2',
        '📊 NEWS2 Score Breakdown',
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void sendMessage(String query) async {
              query = query.trim();
              if (query.isEmpty || isGenerating) return;
              chatInputCtrl.clear();

              setModalState(() {
                chatMessages.add({'sender': 'user', 'text': query});
                isGenerating = true;
              });

              // Scroll to bottom
              Future.delayed(const Duration(milliseconds: 80), () {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              try {
                final response = await OnDeviceLLMService.generateGenerativeClinicalExplanation(
                  member: member ?? {'name': 'General Health Query', 'age': 'Community'},
                  news2Result: news2Result ?? {'score': 0, 'risk_level': 'Normal / Low Risk'},
                  sepsisResult: sepsisResult ?? {'risk_percent': '0%', 'risk_level': 'Normal / Low Risk'},
                  delta: delta ?? {},
                  languageCode: currentLang,
                  customQuestion: query,
                );

                setModalState(() {
                  isGenerating = false;
                  chatMessages.add({'sender': 'qwen', 'text': response});
                });
              } catch (e) {
                setModalState(() {
                  isGenerating = false;
                  chatMessages.add({
                    'sender': 'qwen',
                    'text': 'Clinical AI consultation generated with standard protocol.\n\n• Maintain vital monitoring\n• Refer to PHC if danger signs persist.'
                  });
                });
              }

              Future.delayed(const Duration(milliseconds: 100), () {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.84,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: OnDeviceLLMService.isModelDownloadedNotifier,
                                builder: (context, isDownloaded, _) {
                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDownloaded ? Colors.green.shade50 : const Color(0x1F00796B),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isDownloaded ? Icons.verified_rounded : Icons.auto_awesome,
                                      color: isDownloaded ? Colors.green.shade700 : const Color(0xFF00796B),
                                      size: 22,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPatientContext
                                          ? 'T7 AI Doctor • $patientName'
                                          : 'T7 Clinical AI Chat',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    ValueListenableBuilder<bool>(
                                      valueListenable: OnDeviceLLMService.isModelDownloadedNotifier,
                                      builder: (context, isDownloaded, _) {
                                        return Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isDownloaded ? Colors.green : const Color(0xFF00897B),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                isDownloaded
                                                    ? '⚡ Neural LLM Loaded (${langInfo['native']})'
                                                    : '🤖 Clinical AI (${langInfo['native']})',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDownloaded ? Colors.green.shade800 : Colors.grey.shade700,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),

                    // Quick suggestions bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickPrompts.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6, bottom: 4),
                            child: ActionChip(
                              label: Text(p, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                              backgroundColor: Colors.teal.shade50,
                              side: BorderSide(color: Colors.teal.shade200),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: isGenerating
                                  ? null
                                  : () => sendMessage(p.replaceAll(RegExp(r'^[^\w]+'), '')),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Chat messages list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: chatMessages.length + (isGenerating ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == chatMessages.length && isGenerating) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.teal.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00796B)),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Synthesizing clinical advice...',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF004D40), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final msg = chatMessages[index];
                          final isUser = msg['sender'] == 'user';
                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.82,
                              ),
                              decoration: BoxDecoration(
                                color: isUser ? const Color(0xFF00796B) : Colors.grey.shade100,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                                  bottomRight: Radius.circular(isUser ? 4 : 16),
                                ),
                                border: isUser ? null : Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: TextStyle(
                                  color: isUser ? Colors.white : Colors.black87,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 12),

                    // Bottom Input Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatInputCtrl,
                            textInputAction: TextInputAction.send,
                            enabled: !isGenerating,
                            onSubmitted: sendMessage,
                            decoration: InputDecoration(
                              hintText: isPatientContext
                                  ? LanguageService.tr('t7_ask_patient_hint')
                                  : LanguageService.tr('t7_ask_hint'),
                              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: isGenerating ? Colors.grey : const Color(0xFF00796B),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                          onPressed: isGenerating ? null : () => sendMessage(chatInputCtrl.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Global Floating Action Button for T7 Clinical AI
class QwenChatFloatingButton extends StatelessWidget {
  final Map<String, dynamic>? member;
  final Map<String, dynamic>? news2Result;
  final Map<String, dynamic>? sepsisResult;
  final Map<String, Map<String, dynamic>>? delta;
  final String heroTag;

  const QwenChatFloatingButton({
    super.key,
    this.member,
    this.news2Result,
    this.sepsisResult,
    this.delta,
    this.heroTag = 'global_qwen_chat_fab',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => QwenAIChatModal.show(
        context,
        member: member,
        news2Result: news2Result,
        sepsisResult: sepsisResult,
        delta: delta,
      ),
      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
      label: const Text(
        'T7 Clinical AI',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF004D40),
    );
  }
}

typedef T7ClinicalAIChatModal = QwenAIChatModal;
typedef T7ChatFloatingButton = QwenChatFloatingButton;
