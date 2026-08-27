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

    final TextEditingController chatInputCtrl = TextEditingController();
    final ScrollController scrollController = ScrollController();

    // Quick suggestion chips
    final List<String> quickPrompts = [
      '🌡️ Fever Advice',
      '🩺 High BP Protocol',
      '🩸 Low Blood Sugar',
      '🤰 Pregnancy Danger Signs',
      '👶 Child Dehydration (ORS)',
    ];

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
              if (query.isEmpty) return;
              chatInputCtrl.clear();

              setModalState(() {
                chatMessages.add({'sender': 'user', 'text': query});
              });

              // Scroll to bottom
              Future.delayed(const Duration(milliseconds: 100), () {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });

              final response = await OnDeviceLLMService.generateGenerativeClinicalExplanation(
                member: member ?? {'name': 'General Health Query', 'age': 'Community'},
                news2Result: news2Result ?? {'score': 0, 'risk_level': 'Normal / Low Risk'},
                sepsisResult: sepsisResult ?? {'risk_percent': '0%', 'risk_level': 'Normal / Low Risk'},
                delta: delta ?? {},
                languageCode: currentLang,
                customQuestion: query,
              );

              setModalState(() {
                chatMessages.add({'sender': 'qwen', 'text': response});
              });

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
                height: MediaQuery.of(context).size.height * 0.82,
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0x1F00796B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.auto_awesome, color: Color(0xFF00796B), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPatientContext
                                      ? 'T7 Clinical AI Chat • $patientName'
                                      : 'T7 Clinical AI Chat',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${langInfo['name']} (${langInfo['native']}) • 100% On-Device',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ],
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
                              onPressed: () => sendMessage(p.replaceAll(RegExp(r'^[^\w]+'), '')),
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
                        itemCount: chatMessages.length,
                        itemBuilder: (context, index) {
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
                            backgroundColor: const Color(0xFF00796B),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                          onPressed: () => sendMessage(chatInputCtrl.text),
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
