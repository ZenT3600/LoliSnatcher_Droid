import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:lolisnatcher/src/handlers/settings_handler.dart';
import 'package:lolisnatcher/src/handlers/service_handler.dart';
import 'package:lolisnatcher/src/pages/about_page.dart';
import 'package:lolisnatcher/src/pages/settings/save_cache_page.dart';
import 'package:lolisnatcher/src/pages/settings/booru_page.dart';
import 'package:lolisnatcher/src/pages/settings/database_page.dart';
import 'package:lolisnatcher/src/pages/settings/debug_page.dart';
import 'package:lolisnatcher/src/pages/settings/gallery_page.dart';
import 'package:lolisnatcher/src/pages/settings/user_interface_page.dart';
import 'package:lolisnatcher/src/pages/settings/filter_tags_page.dart';
import 'package:lolisnatcher/src/widgets/common/settings_widgets.dart';
import 'package:lolisnatcher/src/pages/loli_sync_page.dart';
import 'package:lolisnatcher/src/pages/settings/backup_restore_page.dart';
import 'package:lolisnatcher/src/pages/settings/theme_page.dart';
import 'package:lolisnatcher/src/widgets/common/flash_elements.dart';
import 'package:lolisnatcher/src/widgets/common/mascot_image.dart';

/// Then settings page is pretty self explanatory it will display, allow the user to edit and save settings
class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  Future<bool> _onWillPop() async {
    final SettingsHandler settingsHandler = SettingsHandler.instance;
    bool result = await settingsHandler.saveSettings(restate: true);
    await settingsHandler.loadSettings();
    // await settingsHandler.getBooru();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final SettingsHandler settingsHandler = SettingsHandler.instance;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text("Settings"),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _onWillPop()) {
                  Navigator.of(context).pop();
                }
              }),
        ),
        body: Center(
          child: ListView(
            children: <Widget>[
              SettingsButton(
                name: 'Boorus & Search',
                icon: const Icon(Icons.image_search),
                page: () => const BooruPage(),
              ),
              SettingsButton(
                name: 'Interface',
                icon: const Icon(Icons.grid_on),
                page: () => const UserInterfacePage(),
              ),
              SettingsButton(
                name: 'Themes',
                icon: const Icon(Icons.palette),
                page: () => const ThemePage(),
              ),
              SettingsButton(
                name: 'Gallery',
                icon: const Icon(Icons.view_carousel),
                page: () => const GalleryPage(),
              ),
              SettingsButton(
                name: 'Snatching & Caching',
                icon: const Icon(Icons.settings),
                page: () => const SaveCachePage(),
              ),
              SettingsButton(
                name: 'Tag Filters',
                icon: const Icon(CupertinoIcons.tag),
                page: () => const FiltersEdit(),
              ),
              SettingsButton(
                name: 'Database',
                icon: const Icon(Icons.list_alt),
                page: () => const DatabasePage(),
              ),
              SettingsButton(
                name: 'Backup & Restore [Beta]',
                icon: const Icon(Icons.restore_page),
                page: () => const BackupRestorePage(),
              ),
              SettingsButton(
                name: 'LoliSync',
                icon: const Icon(Icons.sync),
                action: settingsHandler.dbEnabled
                    ? null
                    : () {
                        FlashElements.showSnackbar(
                          context: context,
                          title: const Text("Error!", style: TextStyle(fontSize: 20)),
                          content: const Text("Database must be enabled to use LoliSync"),
                          leadingIcon: Icons.error_outline,
                          leadingIconColor: Colors.red,
                          sideColor: Colors.red,
                        );
                      },
                page: settingsHandler.dbEnabled ? () => const LoliSyncPage() : null,
              ),
              SettingsButton(
                name: 'About',
                icon: const Icon(Icons.info_outline),
                page: () => const AboutPage(),
              ),
              SettingsButton(
                name: 'Check for Updates',
                icon: const Icon(Icons.update),
                action: () {
                  settingsHandler.checkUpdate(withMessage: true);
                },
              ),
              SettingsButton(
                name: 'Help',
                icon: const Icon(Icons.help_center_outlined),
                action: () {
                  ServiceHandler.launchURL("https://github.com/NO-ob/LoliSnatcher_Droid/wiki");
                },
                trailingIcon: const Icon(Icons.exit_to_app),
              ),
              Obx(() {
                if (settingsHandler.isDebug.value) {
                  return SettingsButton(name: 'Debug', icon: const Icon(Icons.developer_mode), page: () => const DebugPage());
                } else {
                  return const SizedBox();
                }
              }),
              const VersionButton(),
              const MascotImage(),
            ],
          ),
        ),
      ),
    );
  }
}

class VersionButton extends StatefulWidget {
  const VersionButton({Key? key}) : super(key: key);

  @override
  State<VersionButton> createState() => _VersionButtonState();
}

class _VersionButtonState extends State<VersionButton> {
  int debugTaps = 0;

  @override
  Widget build(BuildContext context) {
    final SettingsHandler settingsHandler = SettingsHandler.instance;

    final String verText = "Version: ${settingsHandler.verStr} (${settingsHandler.buildNumber})";
    const String buildTypeText = EnvironmentConfig.isFromStore ? "/ Play" : (kDebugMode ? "/ Debug" : "");

    return SettingsButton(
      name: "$verText $buildTypeText".trim(),
      icon: const Icon(null), // to align with other items
      action: () {
        if (settingsHandler.isDebug.value) {
          FlashElements.showSnackbar(
            context: context,
            title: const Text("Debug mode is already enabled!", style: TextStyle(fontSize: 18)),
            leadingIcon: Icons.warning_amber,
            leadingIconColor: Colors.yellow,
            sideColor: Colors.yellow,
          );
        } else {
          debugTaps++;
          if (debugTaps > 5) {
            settingsHandler.isDebug.value = true;
            FlashElements.showSnackbar(
              context: context,
              title: const Text("Debug mode is enabled!", style: TextStyle(fontSize: 18)),
              leadingIcon: Icons.warning_amber,
              leadingIconColor: Colors.green,
              sideColor: Colors.green,
            );
          }
        }

        setState(() {});
      },
      drawBottomBorder: false,
    );
  }
}