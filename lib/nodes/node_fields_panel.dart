import 'package:flutter/widgets.dart';

/// Displays dynamic key-value data fields inside a node.
///
/// Reads from the node's `data` map and renders each entry as
/// a labelled row.
class NodeFieldsPanel extends StatelessWidget {
  /// Creates a [NodeFieldsPanel].
  const NodeFieldsPanel({
    super.key,
    required this.data,
  });

  /// The key-value data to display.
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: data.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  '${entry.key}: ',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF888888),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF444444),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
