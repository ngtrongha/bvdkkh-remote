// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'package:flutter/material.dart';
import '../../common/widgets/api_connection_badge.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/mobile/pages/settings_page.dart';
import 'package:flutter_hbb/web/settings_page.dart';
import 'package:get/get.dart';
import '../../common.dart';
import '../../common/support_ticket_listener.dart';
import '../../common/widgets/chat_page.dart';
import '../../models/platform_model.dart';
import '../../models/state_model.dart';
import 'connection_page.dart';
import 'scan_page.dart';

abstract class PageShape extends Widget {
  final String title = "";
  final Widget icon = Icon(null);
  final List<Widget> appBarActions = [];
}

class HomePage extends StatefulWidget {
  static final homeKey = GlobalKey<HomePageState>();

  HomePage() : super(key: homeKey);

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  var _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;
  final List<PageShape> _pages = [];
  int _chatPageTabIndex = -1;
  bool get isChatPageCurrentTab => isAndroid
      ? _selectedIndex == _chatPageTabIndex
      : false; // change this when ios have chat page

  void refreshPages() {
    setState(() {
      initPages();
    });
  }

  @override
  void initState() {
    super.initState();
    initPages();
    if (isAndroid || isIOS) {
      SupportTicketListener.instance.initClientWatcher();
    }
  }

  void initPages() {
    _pages.clear();
    if (!bind.isIncomingOnly()) {
      _pages.add(ConnectionPage(
        appBarActions: [],
      ));
    }
    if (isAndroid && !bind.isOutgoingOnly()) {
      _chatPageTabIndex = _pages.length;
      _pages.addAll([ChatPage(type: ChatPageType.mobileMain), ServerPage()]);
    }
    _pages.add(SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    final hairline = MyTheme.mobileHairline(context);
    final surface = MyTheme.mobileSurface(context);
    final currentPage = _pages.elementAt(_selectedIndex);
    final isConnectionTab = currentPage is ConnectionPage;
    final showQrOnConnection =
        isConnectionTab && !isWeb && !bind.isDisableSettings();

    return WillPopScope(
        onWillPop: () async {
          if (_selectedIndex != 0) {
            setState(() {
              _selectedIndex = 0;
            });
          } else {
            return true;
          }
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: surface,
            foregroundColor: MyTheme.mobilePrimaryText(context),
            centerTitle: false,
            titleSpacing: 16,
            toolbarHeight: 56,
            title: appTitle(),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: hairline),
            ),
            actions: [
              const Center(child: ApiConnectionBadge()),
              const SizedBox(width: 4),
              if (showQrOnConnection)
                IconButton(
                  tooltip: translate('Scan QR'),
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (BuildContext context) => ScanPage(),
                      ),
                    );
                  },
                ),
              ...currentPage.appBarActions,
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: hairline, width: 1)),
            ),
            child: BottomNavigationBar(
              key: navigationBarKey,
              elevation: 0,
              backgroundColor: Colors.transparent,
              items: _pages
                  .map((page) => BottomNavigationBarItem(
                        icon: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: page.icon,
                        ),
                        activeIcon: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: MyTheme.accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: page.icon,
                        ),
                        label: page.title,
                      ))
                  .toList(),
              currentIndex: _selectedIndex,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: MyTheme.accent,
              unselectedItemColor: MyTheme.mobileMutedText(context),
              selectedFontSize: 12,
              unselectedFontSize: 11,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
              onTap: (index) => setState(() {
                // close chat overlay when go chat page
                if (_selectedIndex != index) {
                  _selectedIndex = index;
                  if (isChatPageCurrentTab) {
                    gFFI.chatModel.hideChatIconOverlay();
                    gFFI.chatModel.hideChatWindowOverlay();
                    gFFI.chatModel.mobileClearClientUnread(
                        gFFI.chatModel.currentKey.connId);
                  }
                }
              }),
            ),
          ),
          body: currentPage,
        ));
  }

  Widget appTitle() {
    final currentUser = gFFI.chatModel.currentUser;
    final currentKey = gFFI.chatModel.currentKey;
    if (isChatPageCurrentTab &&
        currentUser != null &&
        currentKey.peerId.isNotEmpty) {
      final connected =
          gFFI.serverModel.clients.any((e) => e.id == currentKey.connId);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: currentKey.isOut
                ? translate('Outgoing connection')
                : translate('Incoming connection'),
            child: Icon(
              currentKey.isOut
                  ? Icons.call_made_rounded
                  : Icons.call_received_rounded,
              size: 18,
              color: MyTheme.accent,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "${currentUser.firstName} ${currentUser.id}".trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: MyTheme.mobilePrimaryText(context),
              ),
            ),
          ),
          if (connected)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(left: 6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: MyTheme.statusOnline,
              ),
            ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: MyTheme.mobileHairline(context),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 18,
                  color: MyTheme.accent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            bind.mainGetAppNameSync(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MyTheme.mobilePrimaryText(context),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

class WebHomePage extends StatelessWidget {
  final connectionPage =
      ConnectionPage(appBarActions: <Widget>[const WebSettingsPage()]);

  @override
  Widget build(BuildContext context) {
    stateGlobal.isInMainPage = true;
    handleUnilink(context);
    return Scaffold(
      // backgroundColor: MyTheme.grayBg,
      appBar: AppBar(
        centerTitle: true,
        title: Text("${bind.mainGetAppNameSync()} (Preview)"),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(padding: EdgeInsets.only(bottom: 4),
              child: ApiConnectionBadge()),
        ),
        actions: connectionPage.appBarActions,
      ),
      body: connectionPage,
    );
  }

  handleUnilink(BuildContext context) {
    if (webInitialLink.isEmpty) {
      return;
    }
    final link = webInitialLink;
    webInitialLink = '';
    final splitter = ["/#/", "/#", "#/", "#"];
    var target = '';
    for (var s in splitter) {
      if (link.contains(s)) {
        var list = link.split(s);
        if (list.length < 2 || list[1].isEmpty) {
          return;
        }
        list.removeAt(0);
        target = list.join(s);
        break;
      }
    }

    if (target.isEmpty) {
      final cleanUri = Uri.tryParse(link);
      if (cleanUri != null && cleanUri.pathSegments.isNotEmpty) {
        target = cleanUri.pathSegments.join('/');
        if (cleanUri.hasQuery) {
          target = '$target?${cleanUri.query}';
        }
      }
    }

    if (target.isEmpty) {
      return;
    }
    final uri = Uri.tryParse("rustdesk://$target");
    if (uri == null) {
      return;
    }
    final args = urlLinkToCmdArgs(uri);
    if (args == null || args.isEmpty) {
      return;
    }
    bool isFileTransfer = false;
    bool isViewCamera = false;
    bool isTerminal = false;
    String? id;
    String? password;
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--connect':
        case '--play':
          id = args[i + 1];
          i++;
          break;
        case '--file-transfer':
          isFileTransfer = true;
          id = args[i + 1];
          i++;
          break;
        case '--view-camera':
          isViewCamera = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal':
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--terminal-admin':
          setEnvTerminalAdmin();
          isTerminal = true;
          id = args[i + 1];
          i++;
          break;
        case '--password':
          password = args[i + 1];
          i++;
          break;
        default:
          break;
      }
    }
    if (id != null) {
      connect(context, id, 
        isFileTransfer: isFileTransfer, 
        isViewCamera: isViewCamera, 
        isTerminal: isTerminal,
        password: password);
    }
  }
}
