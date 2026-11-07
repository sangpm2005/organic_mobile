import 'package:flutter/material.dart';

import '../../domain/vietnam_address.dart';

class AddressChoice {
  final String code, label, searchText;
  const AddressChoice(this.code, this.label, {this.searchText = ''});
}

class SearchableAddressField extends StatelessWidget {
  final String id, label, value;
  final List<AddressChoice> choices;
  final ValueChanged<String> onChanged;
  final bool enabled;
  const SearchableAddressField({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final selected = choices
        .where((option) => option.code == value)
        .firstOrNull;
    return Padding(
      key: ValueKey(id),
      padding: const EdgeInsets.only(bottom: 16),
      child: FormField<String>(
        key: ValueKey('$id.$value'),
        initialValue: value,
        enabled: enabled,
        validator: (_) =>
            selected == null ? 'Vui lòng chọn ${label.toLowerCase()}.' : null,
        builder: (field) => Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: InkWell(
            onTap: !enabled
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    final result = await showModalBottomSheet<AddressChoice>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _AddressChoices(
                        label: label,
                        value: value,
                        choices: choices,
                      ),
                    );
                    if (result == null || !context.mounted) return;
                    field.didChange(result.code);
                    onChanged(result.code);
                  },
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              isEmpty: selected == null,
              decoration: InputDecoration(
                labelText: label,
                enabled: enabled,
                errorText: field.errorText,
                suffixIcon: const Icon(Icons.expand_more),
              ),
              child: Text(
                selected?.label ?? 'Chọn ${label.toLowerCase()}',
                style: selected == null
                    ? TextStyle(color: Theme.of(context).hintColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressChoices extends StatefulWidget {
  final String label, value;
  final List<AddressChoice> choices;
  const _AddressChoices({
    required this.label,
    required this.value,
    required this.choices,
  });
  @override
  State<_AddressChoices> createState() => _AddressChoicesState();
}

class _AddressChoicesState extends State<_AddressChoices> {
  String query = '';
  bool matches(AddressChoice option) {
    final tokens = addressText(query)
        .split(' ')
        .where((v) => v.isNotEmpty)
        .toList();
    final words = addressText('${option.label} ${option.searchText}')
        .split(' ');
    return tokens.every(
      (token) => words.any(
        (word) =>
            word == token ||
            (!RegExp(r'^\d+$').hasMatch(token) && word.startsWith(token)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final choices = widget.choices.where(matches).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chọn ${widget.label.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const ValueKey('address.options.search'),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nhập từ khóa tìm kiếm',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (text) => setState(() => query = text),
              ),
            ),
            Expanded(
              child: choices.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Không tìm thấy địa chỉ phù hợp.'),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: choices.length,
                      itemBuilder: (context, index) {
                        final option = choices[index];
                        return ListTile(
                          key: ValueKey('address.option.${option.code}'),
                          title: Text(option.label),
                          selected: option.code == widget.value,
                          trailing: option.code == widget.value
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
