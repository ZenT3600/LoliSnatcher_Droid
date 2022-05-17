import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:LoliSnatcher/SnatchHandler.dart';
import 'package:LoliSnatcher/SearchGlobals.dart';
import 'package:LoliSnatcher/widgets/MarqueeText.dart';

class ActiveTitle extends StatelessWidget {
  const ActiveTitle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SearchHandler searchHandler = Get.find<SearchHandler>();
    final SnatchHandler snatchHandler = Get.find<SnatchHandler>();

    return Obx(() {
      if (snatchHandler.snatchActive.value) {
        return FittedBox(
          fit: BoxFit.fitWidth,
          child: Text("Snatching: ${snatchHandler.snatchStatus}"),
        );
      } else {
        if (searchHandler.list.isEmpty) {
          return const Text('LoliSnatcher');
        } else {
          return GestureDetector(
            onTap: () {
              searchHandler.openAndFocusSearch();
            },
            child: MarqueeText(
              text: searchHandler.currentTab.tags,
              fontSize: 16,
              isExpanded: false,
            ),
          );
        }
      }
    });
  }
}
