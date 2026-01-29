import 'dart:io';
import 'package:tray_manager/tray_manager.dart';
import 'package:trust_tunnel_rock/controllers/app_controller.dart';
import 'package:window_manager/window_manager.dart';

class TrayControl extends TrayListener {
  TrayControl._();
  static final TrayControl instance = TrayControl._();

  Future<void> init() async {
    trayManager.addListener(this);

    String iconPath;
    if (Platform.isWindows) {
      iconPath = '${Directory.current.path}\\assets\\app_icon.ico';
    } else {
      iconPath = '${Directory.current.path}/assets/app_icon.png';
    }

    await trayManager.setIcon(iconPath);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'show',
            label: 'Show',
            onClick: (_) => windowManager.show(),
          ),
          MenuItem(
            key: 'exit',
            label: 'Exit',
            onClick: (_) async {
              await AppController().publicKillProcess();
              windowManager.close();
            },
          ),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => windowManager.isVisible().then(
    (v) => v ? windowManager.hide() : windowManager.show(),
  );

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();
}
