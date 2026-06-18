import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/state.dart';
import '../widgets/widgets.dart';
import 'detail_screen.dart';

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
    final filters = context.read<FilterProvider>().activeFilterClauses;
    context.read<SearchProvider>().search(query, filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SearchProvider>();
    // Re-run the current search whenever the taxonomy filter changes (FR-13),
    // so toggling a filter immediately refreshes the visible results.
    final filters = context.watch<FilterProvider>().activeFilterClauses;
    if (provider.lastQuery.isNotEmpty &&
        provider.state != ViewState.loading &&
        !listEquals(filters, provider.lastFilters)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SearchProvider>().search(
          provider.lastQuery,
          filters: filters,
        );
      });
    }

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
        const FilterPanel(),
        const SizedBox(height: 8),
        const _SearchTrendBadge(),
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
          itemBuilder: (context, i) {
            final work = provider.results[i];
            return PaperCard(
              work: work,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DetailScreen(work: work)),
              ),
            );
          },
        );
    }
  }
}

/// FR-9 trend badge for the searched topic. Reuses the year data the
/// [TrendProvider] already fetched for the same shared topic, so the Search
/// tab shows the verdict without an extra request. Hidden until that data is
/// ready and matches the current query.
class _SearchTrendBadge extends StatelessWidget {
  const _SearchTrendBadge();

  @override
  Widget build(BuildContext context) {
    final query = context.watch<SearchProvider>().lastQuery;
    final trend = context.watch<TrendProvider>();
    final classification = trend.trendClassification;

    if (query.isEmpty ||
        trend.state != ViewState.success ||
        trend.lastQuery != query ||
        classification == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TrendBadge(classification: classification),
      ),
    );
  }
}
