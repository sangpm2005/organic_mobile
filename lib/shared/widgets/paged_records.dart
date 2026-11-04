import 'package:flutter/material.dart';

import '../../core/utils/json.dart';

/// Keeps earlier pages visible when a subsequent page fails.
class PagedRecords extends StatefulWidget {
  final Future<Json> Function(int page) load;
  final Widget Function(Json item) itemBuilder;
  final String empty;
  final List<Widget> header;
  final Object? refreshToken;
  const PagedRecords({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.header = const [],
    this.refreshToken,
  });
  @override
  State<PagedRecords> createState() => _PagedRecordsState();
}

class _PagedRecordsState extends State<PagedRecords> {
  List<Json> rows = [];
  int page = -1;
  bool busy = false, more = true;
  String? error;
  bool refreshAfter = false;
  @override
  void didUpdateWidget(covariant PagedRecords oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      if (busy) {
        refreshAfter = true;
      } else {
        fetch(reset: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    fetch(reset: true);
  }

  Future<void> fetch({bool reset = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = reset ? 0 : page + 1;
      final data = await widget.load(next);
      if (!mounted) return;
      setState(() {
        final items = pageItems(data);
        rows = reset ? items : [...rows, ...items];
        page = next;
        more = rows.length < number(data['totalElements']);
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
      if (mounted && refreshAfter) {
        refreshAfter = false;
        fetch(reset: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => fetch(reset: true),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        ...widget.header,
        ...rows.map(widget.itemBuilder),
        if (!busy && error == null && rows.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(widget.empty)),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!busy && (more || error != null))
          TextButton(
            onPressed: () => fetch(reset: page < 0),
            child: Text(error == null ? 'Xem thêm' : 'Thử lại'),
          ),
      ],
    ),
  );
}
