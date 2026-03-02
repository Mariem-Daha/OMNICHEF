import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/chat_message.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final bool showAnimation;

  const ChatBubble({
    super.key,
    required this.message,
    this.showAnimation = true,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.message.isUser ? 0.2 : -0.2, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    if (widget.showAnimation) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.message.isUser 
              ? Alignment.centerRight 
              : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              top: 6,
              bottom: 6,
              left: widget.message.isUser ? 60 : 0,
              right: widget.message.isUser ? 0 : 60,
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Column(
              crossAxisAlignment: widget.message.isUser 
                  ? CrossAxisAlignment.end 
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18, 
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: widget.message.isUser
                        ? AppColors.warmGradient
                        : null,
                    color: widget.message.isUser
                        ? null
                        : (isDark ? AppColors.cardDark : AppColors.cardLight),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(widget.message.isUser ? 22 : 6),
                      bottomRight: Radius.circular(widget.message.isUser ? 6 : 22),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.message.isUser
                            ? AppColors.primary.withOpacity(0.2)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: widget.message.isUser ? 12 : 10,
                        offset: const Offset(0, 4),
                        spreadRadius: widget.message.isUser ? -2 : 0,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(
                      color: widget.message.isUser
                          ? Colors.white
                          : (isDark 
                              ? AppColors.textPrimaryDark 
                              : AppColors.textPrimaryLight),
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(widget.message.timestamp),
                    style: TextStyle(
                      color: isDark 
                          ? AppColors.textTertiaryDark 
                          : AppColors.textTertiaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Quick suggestion button for chat
class QuickSuggestionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const QuickSuggestionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  State<QuickSuggestionButton> createState() => _QuickSuggestionButtonState();
}

class _QuickSuggestionButtonState extends State<QuickSuggestionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark 
              ? AppColors.surfaceDark 
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_isPressed ? 0.15 : 0.08),
              blurRadius: _isPressed ? 8 : 12,
              offset: Offset(0, _isPressed ? 2 : 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.icon,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: TextStyle(
                color: isDark 
                    ? AppColors.textPrimaryDark 
                    : AppColors.textPrimaryLight,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
