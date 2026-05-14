import 'package:flutter/material.dart';

import '../sdui/sdui_page_loader.dart';
import '../sdui/sdui_parser.dart';

class SDUILazyList extends StatefulWidget {
  final Map<String, dynamic> uiJson;

  const SDUILazyList({super.key, required this.uiJson});

  @override
  State<SDUILazyList> createState() => _SDUILazyListState();
}

class _SDUILazyListState extends State<SDUILazyList> {
  late final ScrollController _scrollController;
  final List<dynamic> _items = [];
  String? _nextUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    final props = (widget.uiJson['props'] as Map?) ?? const {};
    _items.addAll((widget.uiJson['children'] as List?) ?? const []);
    _nextUrl = props['nextUrl'] as String?;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || _nextUrl == null) return;
    setState(() => _isLoading = true);

    try {
      final next = await SDUIApiService.fetchEndpoint(_nextUrl!, useCache: false);
      final newChildren = (next['children'] as List?) ?? const [];
      final newNextUrl = (next['props'] as Map?)?['nextUrl'] as String?;
      if (!mounted) return;
      setState(() {
        _items.addAll(newChildren);
        _nextUrl = newChildren.isEmpty ? null : newNextUrl;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('LAZY_LIST page fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _nextUrl = null; // give up so we don't loop on errors
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      controller: _scrollController,
      itemCount: _items.length + (_isLoading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final node = Map<String, dynamic>.from(_items[index] as Map);
        return SDUIParser(uiJson: node);
      },
    );
  }
}
