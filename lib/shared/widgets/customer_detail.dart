import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/json.dart';
import 'empty_state.dart';

class CustomerDetail extends StatefulWidget {
  final String title;
  final Future<Json> Function() load;
  final Widget Function(Json data, Future<void> Function() reload) builder;
  const CustomerDetail({
    super.key,
    required this.title,
    required this.load,
    required this.builder,
  });
  @override
  State<CustomerDetail> createState() => _CustomerDetailState();
}

class _CustomerDetailState extends State<CustomerDetail>
    with WidgetsBindingObserver {
  Json? data;
  String? error;
  bool loading = false, active = true;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reload();
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (active && mounted && ModalRoute.of(context)?.isCurrent == true) {
        reload();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active && mounted && ModalRoute.of(context)?.isCurrent == true) {
      reload();
    }
  }

  Future<void> reload() async {
    if (loading) return;
    loading = true;
    try {
      final next = await widget.load();
      if (mounted) {
        setState(() {
          data = next;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      loading = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          onPressed: reload,
          icon: const Icon(Icons.refresh),
          tooltip: 'Cập nhật',
        ),
      ],
    ),
    body: data == null
        ? error == null
              ? const Center(child: CircularProgressIndicator())
              : EmptyState(
                  'Chưa tải được dữ liệu',
                  error!,
                  action: TextButton(
                    onPressed: reload,
                    child: const Text('Thử lại'),
                  ),
                )
        : Column(
            children: [
              if (error != null)
                MaterialBanner(
                  content: Text(error!),
                  actions: [
                    TextButton(onPressed: reload, child: const Text('Thử lại')),
                  ],
                ),
              Expanded(child: widget.builder(data!, reload)),
            ],
          ),
  );
}
