import 'package:flutter/material.dart';

import '../core/utils/fa_number.dart';

/// One pickable asset in [showAssetSearchSheet].
class AssetSearchOption {
  const AssetSearchOption({
    required this.id,
    required this.nameFa,
    required this.symbol,
    this.name = '',
  });

  final String id;
  final String nameFa;
  final String symbol;
  final String name;

  String get label => '$nameFa ($symbol)';

  /// Persian name, English name, symbol or id; Persian digits accepted.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = toAsciiDigits(query).toLowerCase();
    return nameFa.contains(query) ||
        name.toLowerCase().contains(q) ||
        symbol.toLowerCase().contains(q) ||
        id.contains(q);
  }
}

/// Searchable full-height picker. A dropdown with ninety Persian labels is
/// unusable on a phone; a search sheet finds «روپیه» in two keystrokes.
/// Shared by the calculator and the widget settings.
Future<String?> showAssetSearchSheet(
  BuildContext context, {
  required String title,
  required List<AssetSearchOption> options,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  builder: (_) => AssetSearchSheet(title: title, options: options),
);

class AssetSearchSheet extends StatefulWidget {
  const AssetSearchSheet({
    super.key,
    required this.title,
    required this.options,
  });

  final String title;
  final List<AssetSearchOption> options;

  @override
  State<AssetSearchSheet> createState() => _AssetSearchSheetState();
}

class _AssetSearchSheetState extends State<AssetSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.options.where((o) => o.matches(_query)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '${widget.title} — جست‌وجو',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('موردی پیدا نشد'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final o = matches[i];
                        return ListTile(
                          title: Text(o.nameFa),
                          subtitle: Text(o.symbol),
                          onTap: () => Navigator.of(context).pop(o.id),
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
