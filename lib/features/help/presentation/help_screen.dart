import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../help_content.dart';

class _ChatTurn {
  final String question;
  final List<HelpTopic> answers;
  _ChatTurn(this.question, this.answers);
}

/// Hindi help: ask a question in your own words (Hindi / Hinglish / English)
/// and get the matching step-by-step guide. Works fully offline.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _question = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatTurn> _turns = [];
  final _latestQuestionKey = GlobalKey();

  static const _suggestions = [
    'बिल कैसे बनाएं?',
    'नया सामान कैसे जोड़ें?',
    'प्रिंटर कैसे जोड़ें?',
    'उधार कैसे लिखें?',
    'बैकअप कैसे लें?',
    'नए फ़ोन में डेटा कैसे लाएं?',
  ];

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    setState(() => _turns.add(_ChatTurn(q, HelpSearch.search(q))));
    _question.clear();
    // Bring the new question + answer to the top of the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _latestQuestionKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _openTopic(HelpTopic t) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HelpTopicScreen(topic: t)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('मदद', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              children: [
                _botBubble(
                  child: const Text(
                    'नमस्ते! 🙏\nअपना सवाल नीचे लिखें — हिंदी, Hinglish या English में। जैसे: "printer kaise jode"।\nया नीचे की सूची से कोई भी गाइड खोलें।',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
                for (final turn in _turns) ...[
                  _userBubble(turn.question, key: identical(turn, _turns.last) ? _latestQuestionKey : null),
                  if (turn.answers.isEmpty)
                    _botBubble(
                      child: const Text(
                        'माफ़ कीजिए, इसका जवाब नहीं मिला। 😕\nकम शब्दों में लिखकर देखें, जैसे "बिल", "प्रिंटर", "उधार", "बैकअप"। या नीचे की सूची देखें।',
                        style: TextStyle(fontSize: 16, height: 1.5),
                      ),
                    )
                  else
                    _botBubble(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TopicSteps(topic: turn.answers.first),
                          if (turn.answers.length > 1) ...[
                            const SizedBox(height: 10),
                            const Text('शायद आप यह भी पूछना चाहते हैं:', style: TextStyle(fontWeight: FontWeight.w700)),
                            for (final other in turn.answers.skip(1))
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                                onPressed: () => _openTopic(other),
                                child: Text('${other.icon} ${other.title}', style: const TextStyle(fontSize: 15)),
                              ),
                          ],
                        ],
                      ),
                    ),
                ],
                if (_turns.isEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions
                        .map((s) => ActionChip(
                              label: Text(s, style: const TextStyle(fontSize: 15)),
                              onPressed: () => _ask(s),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('सारी गाइड', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
                const SizedBox(height: 8),
                for (final t in helpTopics)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Text(t.icon, style: const TextStyle(fontSize: 28)),
                      title: Text(t.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openTopic(t),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _ask,
                      style: const TextStyle(fontSize: 17),
                      decoration: const InputDecoration(hintText: 'अपना सवाल लिखें…', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    iconSize: 28,
                    onPressed: () => _ask(_question.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _userBubble(String text, {Key? key}) => Align(
        key: key,
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(top: 10, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      );

  Widget _botBubble({required Widget child}) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10, right: 24),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: child,
        ),
      );
}

class HelpTopicScreen extends StatelessWidget {
  final HelpTopic topic;
  const HelpTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('मदद', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [_TopicSteps(topic: topic)]),
    );
  }
}

class _TopicSteps extends StatelessWidget {
  final HelpTopic topic;
  const _TopicSteps({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${topic.icon}  ${topic.title}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 10),
        for (var i = 0; i < topic.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.accent,
                  child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(topic.steps[i], style: const TextStyle(fontSize: 16, height: 1.45))),
              ],
            ),
          ),
        if (topic.tip != null)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(10)),
            child: Text('💡 ${topic.tip!}', style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
      ],
    );
  }
}
