import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';


class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class AiCoachChatScreen extends StatefulWidget{
  const AiCoachChatScreen({super.key});

  @override
  State<AiCoachChatScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachChatScreen>{
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  Future<void> _sendMessage() async{
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState((){
      _messages.add(ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    try{
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final response = await supabase.functions.invoke('ai_coach_feedback', body: {
        'query': text,
        'user_id': user.id
      });
      final feedback = (response.data?['feedback'] ?? 'No feedback received.').toString();

      setState((){
        _messages.add(ChatMessage(text: feedback, isUser: false));
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          text: "Error: ${e.toString()}",
          isUser: false,
        ));
      });
    }
  }
  @override
  Widget build(BuildContext context){
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Fitness Coach')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context,index){
                  final message = _messages[index];
                  final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                  final bubbleColor = message.isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest;
                  final textColor = message.isUser ? Colors.white : theme.colorScheme.onSurface;

                  return Column(
                    crossAxisAlignment: align,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 14),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(message.text, style: TextStyle(color: textColor, fontSize: 16)),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary
                ),
              ),
            _buildInputBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme){
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Ask your AI coach...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}