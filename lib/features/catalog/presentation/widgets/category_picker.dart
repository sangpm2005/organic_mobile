import 'package:flutter/material.dart';

import '../../../../core/utils/json.dart';

/// Malformed parent links appear at the root; cycles cannot trap navigation.
List<Json> categoryChildren(List<Json> rows, List<String> path) {
  final byId = {for (final r in rows) '${r['id']}': r};
  final ids = byId.keys.toSet();
  bool cyclicRoot(String id) {
    final visited = <String>[];
    var cursor = id;
    while (ids.contains(cursor)) {
      if (visited.contains(cursor)) {
        final cycle = visited.sublist(visited.indexOf(cursor))..sort();
        return cycle.first == id;
      }
      visited.add(cursor);
      cursor = '${byId[cursor]?['parentId'] ?? ''}';
    }
    return false;
  }

  return rows.where((r) {
    final id = '${r['id']}', parent = '${r['parentId'] ?? ''}';
    return !path.contains(id) &&
        (path.isEmpty
            ? parent.isEmpty || !ids.contains(parent) || cyclicRoot(id)
            : parent == path.last);
  }).toList()..sort(
    (a, b) => '${a['name'] ?? a['categoryName']}'.compareTo(
      '${b['name'] ?? b['categoryName']}',
    ),
  );
}

Future<Json?> chooseCategory(BuildContext context, List<Json> rows) =>
    showModalBottomSheet<Json>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryPicker(rows),
    );

class _CategoryPicker extends StatefulWidget {
  final List<Json> rows;
  const _CategoryPicker(this.rows);
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  final path = <String>[];
  @override
  Widget build(BuildContext context) {
    var rows = categoryChildren(widget.rows, path);
    if (path.isEmpty && rows.isEmpty) {
      rows = widget.rows; // Isolated cycles remain selectable.
    }
    final current = widget.rows
        .where((r) => path.isNotEmpty && '${r['id']}' == path.last)
        .firstOrNull;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Column(
        children: [
          ListTile(
            title: const Text('Danh mục sản phẩm'),
            trailing: IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (path.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: Text(
                path
                    .map(
                      (id) =>
                          '${widget.rows.firstWhere((r) => '${r['id']}' == id)['name']}',
                    )
                    .join(' › '),
              ),
              onTap: () => setState(() => path.removeLast()),
            ),
          ListTile(
            leading: const Icon(Icons.grid_view_outlined),
            title: Text(
              current == null ? 'Tất cả sản phẩm' : 'Tất cả ${current['name']}',
            ),
            onTap: () => Navigator.pop(context, current ?? <String, dynamic>{}),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                for (final row in rows)
                  ListTile(
                    title: Text('${row['name'] ?? row['categoryName']}'),
                    trailing:
                        categoryChildren(widget.rows, [
                          ...path,
                          '${row['id']}',
                        ]).isEmpty
                        ? null
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      final next = [...path, '${row['id']}'];
                      if (categoryChildren(widget.rows, next).isEmpty) {
                        Navigator.pop(context, row);
                      } else {
                        setState(() => path.add('${row['id']}'));
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
