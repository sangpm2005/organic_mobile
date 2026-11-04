import 'package:flutter/material.dart';
import 'package:organic_mobile/shared/widgets/empty_state.dart';

class AsyncView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(T) builder;
  const AsyncView({super.key, required this.load, required this.builder});
  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(60),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      if (snapshot.hasError) {
        return EmptyState(
          'Chưa tải được dữ liệu',
          '${snapshot.error}',
          icon: Icons.cloud_off_outlined,
          action: OutlinedButton.icon(
            onPressed: () {
              final next = widget.load();
              setState(() {
                future = next;
              });
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        );
      }
      return widget.builder(snapshot.data as T);
    },
  );
}
