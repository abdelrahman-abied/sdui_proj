import 'package:flutter/material.dart';
import '../sdui/sdui_parser.dart';
// You might need your mock network service here or pass a callback

class SDUILazyList extends StatefulWidget {
  final Map<String, dynamic> uiJson;

  const SDUILazyList({super.key, required this.uiJson});

  @override
  State<SDUILazyList> createState() => _SDUILazyListState();
}

class _SDUILazyListState extends State<SDUILazyList> {
  late ScrollController _scrollController;
  List<dynamic> _items = [];
  String? _nextUrl;
  bool _isLoading = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // 1. Initialize with data sent from server
    _items = widget.uiJson['children'] ?? [];
    _nextUrl = widget.uiJson['props']?['next_url'];
    _hasMore = widget.uiJson['props']?['has_more'] ?? false;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 2. Detect Bottom of List
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || _nextUrl == null) return;

    setState(() {
      _isLoading = true;
    });

    // 3. Simulate Network Request for "Page 2"
    // In a real app: final response = await http.get(_nextUrl);
    await Future.delayed(const Duration(seconds: 2));
    final newBatch = MockPaginationService.getNextBatch(_nextUrl!);

    if (mounted) {
      setState(() {
        // 4. Append new items to the existing list
        _items.addAll(newBatch['items']);
        
        // 5. Update cursor for the NEXT fetch (Page 3)
        _nextUrl = newBatch['next_url'];
        _hasMore = newBatch['has_more'];
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
        // Render Loading Spinner at the bottom
        if (index == _items.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        // Render SDUI Item
        final itemData = (_items[index] as Map).cast<String, dynamic>();
        return SDUIParser(uiJson: itemData);
      },
    );
  }
}

// --- MOCK SERVICE FOR DEMO ---
class MockPaginationService {
  static Map<String, dynamic> getNextBatch(String url) {
    debugPrint("🌐 Fetching: $url");
    
    // Generate 5 dummy items
    List<Map<String, dynamic>> newItems = List.generate(5, (index) {
      int id = DateTime.now().millisecondsSinceEpoch + index;
      return {
        "type": "PRODUCT_CARD",
        "props": {
          "name": "Loaded Item #$id",
          "price": "\$${(index + 1) * 10}"
        },
        "action": {
          "type": "show_toast",
          "data": { "message": "Clicked Item $id" }
        }
      };
    });

    return {
      "items": newItems,
      "next_url": "/api/products?page=3", // In a real app, logic handles page numbers
      "has_more": true 
    };
  }
}