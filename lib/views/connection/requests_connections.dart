import 'package:flutter/material.dart';

import 'connections.dart';

class RequestsConnectionsView extends StatelessWidget {
  final bool startOnConnections;

  const RequestsConnectionsView({super.key, this.startOnConnections = false});

  @override
  Widget build(BuildContext context) => ConnectionsView(
    respectCurrentPage: !startOnConnections,
    startWithHistory: !startOnConnections,
  );
}
