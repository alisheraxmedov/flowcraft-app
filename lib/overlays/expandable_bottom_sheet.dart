import 'package:flutter/material.dart';

class ExpandableBottomSheet extends StatefulWidget {
  const ExpandableBottomSheet({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, ScrollController scrollController)
      builder;

  @override
  State<ExpandableBottomSheet> createState() => _ExpandableBottomSheetState();
}

class _ExpandableBottomSheetState extends State<ExpandableBottomSheet> {
  final _sheetController = DraggableScrollableController();

  // Tracks if the sheet is largely expanded (e.g. > 0.5)
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(() {
      final expanded = _sheetController.size > 0.5;
      if (expanded != _isExpanded) {
        setState(() {
          _isExpanded = expanded;
        });
      }
    });
  }

  void _toggleSheet() {
    if (_sheetController.isAttached) {
      final targetSize = _isExpanded ? 0.15 : 0.9;
      _sheetController.animateTo(
        targetSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Tap area for drag handle / expand button
              InkWell(
                onTap: _toggleSheet,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  height: 48, // Taller tap area
                  child: Center(
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.expand_less_rounded, // Slightly rounded and obtuse looking
                        size: 32,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: widget.builder(context, scrollController),
              ),
            ],
          ),
        );
      },
    );
  }
}
