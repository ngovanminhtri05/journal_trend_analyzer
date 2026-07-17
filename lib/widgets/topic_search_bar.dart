import 'package:flutter/material.dart';

/// Reusable topic input used by the Home / Journals / Keywords tabs.
///
/// Owns its own [TextEditingController] and reports the trimmed, non-empty query
/// through [onSubmit] when the user presses enter or the trailing button. Views
/// stay free of input plumbing.
class TopicSearchBar extends StatefulWidget {
  const TopicSearchBar({
    super.key,
    required this.hintText,
    required this.onSubmit,
    this.initialValue,
  });

  final String hintText;
  final void Function(String query) onSubmit;
  final String? initialValue;

  @override
  State<TopicSearchBar> createState() => _TopicSearchBarState();
}

class _TopicSearchBarState extends State<TopicSearchBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit(query);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _submit,
          ),
        ),
      ),
    );
  }
}
