import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state.dart';
import '../widgets/widgets.dart';

/// Search screen (FR-1): a topic input plus the live results list, with
/// loading / empty / error states. The searched topic also feeds the Trends
/// and Dashboard tabs (they read `SearchProvider.lastQuery`).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    context.read<SearchProvider>().search(query);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Search a research topic (e.g. Machine Learning)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _submit,
              ),
            ),
          ),
        ),
        Expanded(child: _buildBody(provider)),
      ],
    );
  }

  Widget _buildBody(SearchProvider provider) {
    switch (provider.state) {
      case ViewState.idle:
        return const EmptyView(
          icon: Icons.travel_explore,
          message: 'Enter a topic above to explore publications.',
        );
      case ViewState.loading:
        return const LoadingView(message: 'Searching OpenAlex…');
      case ViewState.error:
        return ErrorView(
          message: provider.errorMessage ?? 'Something went wrong.',
          onRetry: provider.retry,
        );
      case ViewState.empty:
        return EmptyView(
          message: 'No publications found for "${provider.lastQuery}".',
        );
      case ViewState.success:
        return ListView.builder(
          itemCount: provider.results.length,
          itemBuilder: (context, i) => PaperCard(work: provider.results[i]),
        );
    }
  }
}
