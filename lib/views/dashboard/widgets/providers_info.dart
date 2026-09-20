import 'package:bett_box/common/common.dart';
import 'package:bett_box/views/proxies/providers.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';

class ProvidersInfo extends StatelessWidget {
  const ProvidersInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: getWidgetHeight(1),
        child: CommonCard(
          info: const Info(iconData: Icons.poll_outlined, label: 'INFO'),
          onPressed: () {
            showExtend(
              context,
              builder: (_, type) {
                return ProvidersView(type: type);
              },
            );
          },
          child: Container(
            padding: baseInfoEdgeInsets.copyWith(top: 0),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Rule & Providers',
                style: context.textTheme.bodyMedium?.toLight.adjustSize(0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
