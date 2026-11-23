import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';

class GestureIcons {
  static const String _family = 'gestureicons';

  GestureIcons._();

  static const IconData iconMouse = IconData(0xe65c, fontFamily: _family);
  static const IconData iconTabletTouch = IconData(0xe9ce, fontFamily: _family);
  static const IconData iconGestureFDrag =
      IconData(0xe686, fontFamily: _family);
  static const IconData iconMobileTouch = IconData(0xe9cd, fontFamily: _family);
  static const IconData iconGesturePress =
      IconData(0xe66c, fontFamily: _family);
  static const IconData iconGestureTap = IconData(0xe66f, fontFamily: _family);
  static const IconData iconGesturePinch =
      IconData(0xe66a, fontFamily: _family);
  static const IconData iconGesturePressHold =
      IconData(0xe66b, fontFamily: _family);
  static const IconData iconGestureFDragUpDown_ =
      IconData(0xe685, fontFamily: _family);
  static const IconData iconGestureFTap_ =
      IconData(0xe68e, fontFamily: _family);
  static const IconData iconGestureFSwipeRight =
      IconData(0xe68f, fontFamily: _family);
  static const IconData iconGestureFdoubleTap =
      IconData(0xe691, fontFamily: _family);
  static const IconData iconGestureFThreeFingers =
      IconData(0xe687, fontFamily: _family);
}

typedef OnTouchModeChange = void Function(bool);

class GestureHelp extends StatefulWidget {
  GestureHelp(
      {Key? key,
      required this.touchMode,
      required this.onTouchModeChange,
      required this.virtualMouseMode,
      this.inputModel})
      : super(key: key);
  final bool touchMode;
  final OnTouchModeChange onTouchModeChange;
  final VirtualMouseMode virtualMouseMode;
  final InputModel? inputModel;

  @override
  State<StatefulWidget> createState() =>
      _GestureHelpState(touchMode, virtualMouseMode);
}

class _GestureHelpState extends State<GestureHelp> {
  late int _selectedIndex;
  late bool _touchMode;
  final VirtualMouseMode _virtualMouseMode;

  _GestureHelpState(bool touchMode, VirtualMouseMode virtualMouseMode)
      : _virtualMouseMode = virtualMouseMode {
    _touchMode = touchMode;
    _selectedIndex = _touchMode ? 1 : 0;
  }

  /// Helper to exit relative mouse mode when certain conditions are met.
  /// This reduces code duplication across multiple UI callbacks.
  void _exitRelativeMouseModeIf(bool condition) {
    if (condition) {
      widget.inputModel?.setRelativeMouseMode(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final space = 8.0;
    final availableWidth = size.width - 32.0;
    final cols = availableWidth > 420 ? 3 : 2;
    final width = (availableWidth - space * (cols - 1)) / cols;
    final hairline = MyTheme.mobileHairline(context);
    final mutedText = MyTheme.mobileMutedText(context);
    final primaryText = MyTheme.mobilePrimaryText(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: mutedText.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Center(
          child: ToggleSwitch(
            initialLabelIndex: _selectedIndex,
            activeFgColor: Colors.white,
            inactiveFgColor: mutedText,
            activeBgColor: const [MyTheme.accent],
            inactiveBgColor: MyTheme.mobileSurface(context),
            borderColor: [hairline],
            borderWidth: 1,
            cornerRadius: 10,
            totalSwitches: 2,
            minWidth: 148,
            minHeight: 40,
            fontSize: 13,
            iconSize: 18,
            labels: [
              translate("Mouse mode"),
              translate("Touch mode"),
            ],
            icons: const [Icons.mouse_rounded, Icons.touch_app_rounded],
            onToggle: (index) {
              setState(() {
                if (_selectedIndex != index) {
                  _selectedIndex = index ?? 0;
                  _touchMode = index == 0 ? false : true;
                  widget.onTouchModeChange(_touchMode);
                  // Exit relative mouse mode when switching to touch mode
                  _exitRelativeMouseModeIf(_touchMode);
                }
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: MyTheme.mobileSurface(context),
            borderRadius: BorderRadius.circular(MyTheme.mobileCardRadius),
            border: Border.all(color: hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await _virtualMouseMode.toggleVirtualMouse();
                  _exitRelativeMouseModeIf(
                      !_virtualMouseMode.showVirtualMouse);
                  setState(() {});
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _virtualMouseMode.showVirtualMouse,
                      activeColor: MyTheme.accent,
                      onChanged: (value) async {
                        if (value == null) return;
                        await _virtualMouseMode.toggleVirtualMouse();
                        _exitRelativeMouseModeIf(
                            !_virtualMouseMode.showVirtualMouse);
                        setState(() {});
                      },
                    ),
                    Expanded(
                      child: Text(
                        translate('Show virtual mouse'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_touchMode && _virtualMouseMode.showVirtualMouse)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        translate('Virtual mouse size'),
                        style: TextStyle(fontSize: 12, color: mutedText),
                      ),
                      Row(
                        children: [
                          Text(translate('Small'),
                              style:
                                  TextStyle(fontSize: 12, color: mutedText)),
                          Expanded(
                            child: Slider(
                              activeColor: MyTheme.accent,
                              value: _virtualMouseMode.virtualMouseScale,
                              min: 0.8,
                              max: 1.8,
                              divisions: 10,
                              onChanged: (value) {
                                _virtualMouseMode.setVirtualMouseScale(value);
                                setState(() {});
                              },
                            ),
                          ),
                          Text(translate('Large'),
                              style:
                                  TextStyle(fontSize: 12, color: mutedText)),
                        ],
                      ),
                    ],
                  ),
                ),
              if (!_touchMode && _virtualMouseMode.showVirtualMouse)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await _virtualMouseMode.toggleVirtualJoystick();
                      _exitRelativeMouseModeIf(
                          !_virtualMouseMode.showVirtualJoystick);
                      setState(() {});
                    },
                    child: Row(
                      children: [
                        Checkbox(
                          value: _virtualMouseMode.showVirtualJoystick,
                          activeColor: MyTheme.accent,
                          onChanged: (value) async {
                            if (value == null) return;
                            await _virtualMouseMode.toggleVirtualJoystick();
                            _exitRelativeMouseModeIf(
                                !_virtualMouseMode.showVirtualJoystick);
                            setState(() {});
                          },
                        ),
                        Expanded(
                          child: Text(
                            translate("Show virtual joystick"),
                            style: TextStyle(fontSize: 13, color: primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_touchMode &&
                  _virtualMouseMode.showVirtualMouse &&
                  _virtualMouseMode.showVirtualJoystick &&
                  widget.inputModel != null)
                Obx(() => Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          widget.inputModel!.toggleRelativeMouseMode();
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: widget.inputModel!.relativeMouseMode.value,
                              activeColor: MyTheme.accent,
                              onChanged: (value) {
                                if (value == null) return;
                                widget.inputModel!.setRelativeMouseMode(value);
                              },
                            ),
                            Expanded(
                              child: Text(
                                translate('Relative mouse mode'),
                                style:
                                    TextStyle(fontSize: 13, color: primaryText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: space,
          runSpacing: space,
          children: _touchMode
              ? [
                  GestureInfo(
                      width,
                      GestureIcons.iconMobileTouch,
                      translate("One-Finger Tap"),
                      translate("Left Mouse")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGesturePressHold,
                      translate("One-Long Tap"),
                      translate("Right Mouse")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFSwipeRight,
                      translate("One-Finger Move"),
                      translate("Mouse Drag")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFThreeFingers,
                      translate("Three-Finger vertically"),
                      translate("Mouse Wheel")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFDrag,
                      translate("Two-Finger Move"),
                      translate("Canvas Move")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGesturePinch,
                      translate("Pinch to Zoom"),
                      translate("Canvas Zoom")),
                ]
              : [
                  GestureInfo(
                      width,
                      GestureIcons.iconMobileTouch,
                      translate("One-Finger Tap"),
                      translate("Left Mouse")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGesturePressHold,
                      translate("One-Long Tap"),
                      translate("Right Mouse")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFSwipeRight,
                      translate("Double Tap & Move"),
                      translate("Mouse Drag")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFThreeFingers,
                      translate("Three-Finger vertically"),
                      translate("Mouse Wheel")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGestureFDrag,
                      translate("Two-Finger Move"),
                      translate("Canvas Move")),
                  GestureInfo(
                      width,
                      GestureIcons.iconGesturePinch,
                      translate("Pinch to Zoom"),
                      translate("Canvas Zoom")),
                ],
        ),
      ],
    );
  }
}

class GestureInfo extends StatelessWidget {
  const GestureInfo(this.width, this.icon, this.fromText, this.toText,
      {Key? key})
      : super(key: key);

  final String fromText;
  final String toText;
  final IconData icon;
  final double width;

  final iconSize = 28.0;
  final iconColor = MyTheme.accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: MyTheme.mobileSurface(context),
        borderRadius: BorderRadius.circular(MyTheme.mobileControlRadius),
        border: Border.all(color: MyTheme.mobileHairline(context), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
          const SizedBox(height: 6),
          Text(
            fromText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: MyTheme.mobileMutedText(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            toText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: MyTheme.mobilePrimaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}
