import 'package:whispa_frontend/providers/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget to display real-time connection status
/// Shows E2EE and Tor network status
class ShowConnection extends StatelessWidget {
  const ShowConnection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        // Determine E2EE status
        final bool e2eeActive = provider.isE2EEActive && provider.isInitialized;
        final Color e2eeColor = e2eeActive
            ? const Color.fromRGBO(32, 211, 102, 1) // Green
            : const Color.fromRGBO(161, 161, 170, 1); // Gray

        // Determine Tor status
        final bool torActive = provider.isTorConnected;
        final Color torColor = torActive
            ? const Color.fromRGBO(32, 211, 102, 1) // Green
            : const Color.fromRGBO(161, 161, 170, 1); // Gray

        return Row(
          children: [
            // E2EE Status
            Icon(
              Icons.lock,
              color: e2eeColor,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              e2eeActive ? "E2EE: Activated" : "E2EE: Inactive",
              style: TextStyle(
                color: e2eeColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(width: 35),

            // Tor Network Status
            Icon(
              Icons.storm_sharp,
              color: torColor,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              torActive ? "Tor: Connected" : "Tor: Disabled",
              style: TextStyle(
                color: torColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Connection status dot
            const Spacer(),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: provider.isConnected
                    ? Colors.green
                    : Colors.red,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              provider.isConnected ? "Online" : "Offline",
              style: TextStyle(
                color: provider.isConnected
                    ? Colors.green
                    : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}