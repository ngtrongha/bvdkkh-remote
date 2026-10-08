// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remoter
// Author: Nguyễn Trọng Hà

import 'package:flutter/material.dart';

class AnimatedDropdownItem<T> {
  final T value;
  final String label;
  final Widget? icon;
  final Widget? child;

  const AnimatedDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.child,
  });
}

class AnimatedDropdown<T> extends StatefulWidget {
  final T value;
  final List<AnimatedDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final bool enabled;
  final double? height;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final Color? borderColor;
  final Color? dropdownColor;
  final TextStyle? textStyle;
  final BorderRadius? borderRadius;
  final double maxDropdownHeight;

  const AnimatedDropdown({
    Key? key,
    required this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.enabled = true,
    this.height = 42,
    this.contentPadding,
    this.fillColor,
    this.borderColor,
    this.dropdownColor,
    this.textStyle,
    this.borderRadius,
    this.maxDropdownHeight = 260,
  }) : super(key: key);

  @override
  State<AnimatedDropdown<T>> createState() => _AnimatedDropdownState<T>();
}

class _AnimatedDropdownState<T> extends State<AnimatedDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _closeDropdown(animate: false);
    _controller.dispose();
    super.dispose();
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _closeDropdown(animate: true);
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final spaceBelow = screenHeight - (offset.dy + size.height);
    final openUpwards =
        spaceBelow < widget.maxDropdownHeight && offset.dy > spaceBelow;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dropdownBg = widget.dropdownColor ??
        (isDark ? const Color(0xFF1E293B) : Colors.white);
    final borderCol = widget.borderColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    final textColor = widget.textStyle?.color ??
        (isDark ? Colors.white : const Color(0xFF0F172A));

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => _closeDropdown(animate: true),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: openUpwards ? const Offset(0, -4) : Offset(0, size.height + 4),
              targetAnchor:
                  openUpwards ? Alignment.topLeft : Alignment.bottomLeft,
              followerAnchor:
                  openUpwards ? Alignment.bottomLeft : Alignment.topLeft,
              child: SizedBox(
                width: size.width,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SizeTransition(
                    sizeFactor: _expandAnimation,
                    axisAlignment: openUpwards ? 1.0 : -1.0,
                    child: Material(
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.35),
                      borderRadius:
                          widget.borderRadius ?? BorderRadius.circular(8),
                      color: dropdownBg,
                      child: Container(
                        decoration: BoxDecoration(
                          color: dropdownBg,
                          borderRadius:
                              widget.borderRadius ?? BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        constraints:
                            BoxConstraints(maxHeight: widget.maxDropdownHeight),
                        child: ClipRRect(
                          borderRadius:
                              widget.borderRadius ?? BorderRadius.circular(8),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: widget.items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final item = widget.items[index];
                              final isSelected = item.value == widget.value;
                              return _DropdownItemTile<T>(
                                item: item,
                                isSelected: isSelected,
                                isDark: isDark,
                                textColor: textColor,
                                onTap: () {
                                  widget.onChanged?.call(item.value);
                                  _closeDropdown(animate: true);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _controller.forward();
  }

  void _closeDropdown({bool animate = true}) {
    if (!_isOpen || _overlayEntry == null) return;
    if (animate) {
      _controller.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        if (mounted) setState(() => _isOpen = false);
      });
    } else {
      _overlayEntry?.remove();
      _overlayEntry = null;
      if (mounted) setState(() => _isOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.fillColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC));
    final border = widget.borderColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));
    final focusedBorder = const Color(0xFFE11D48);
    final textCol = widget.textStyle?.color ??
        (isDark ? Colors.white : const Color(0xFF0F172A));

    final selectedItem = widget.items.firstWhere(
      (it) => it.value == widget.value,
      orElse: () => widget.items.isNotEmpty
          ? widget.items.first
          : AnimatedDropdownItem<T>(value: widget.value, label: ''),
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.enabled ? _toggleDropdown : null,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.height,
          padding: widget.contentPadding ??
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(6),
            border: Border.all(
              color: _isOpen ? focusedBorder : border,
              width: _isOpen ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (selectedItem.icon != null) ...[
                selectedItem.icon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: selectedItem.child ??
                    Text(
                      selectedItem.label.isNotEmpty
                          ? selectedItem.label
                          : (widget.hintText ?? ''),
                      style: widget.textStyle ??
                          TextStyle(color: textCol, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownItemTile<T> extends StatefulWidget {
  final AnimatedDropdownItem<T> item;
  final bool isSelected;
  final bool isDark;
  final Color textColor;
  final VoidCallback onTap;

  const _DropdownItemTile({
    Key? key,
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.textColor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_DropdownItemTile<T>> createState() => _DropdownItemTileState<T>();
}

class _DropdownItemTileState<T> extends State<_DropdownItemTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.isDark
        ? const Color(0xFF334155)
        : const Color(0xFFF1F5F9);
    final selectedBg = widget.isDark
        ? const Color(0xFF0F172A).withOpacity(0.6)
        : const Color(0xFFE2E8F0).withOpacity(0.6);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: widget.isSelected
              ? selectedBg
              : (_isHovered ? hoverBg : Colors.transparent),
          child: Row(
            children: [
              if (widget.item.icon != null) ...[
                widget.item.icon!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: widget.item.child ??
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: widget.isSelected
                            ? const Color(0xFFE11D48)
                            : widget.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              if (widget.isSelected)
                const Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: Color(0xFFE11D48),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
