import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../services/cloud_health_service.dart';
import '../services/local_host_server_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CloudHealthService.instance,
        ApiConstants.modeNotifier,
        LocalHostServerService.instance.isRunning,
      ]),
      builder: (context, _) {
        final health = CloudHealthService.instance;
        final isHost = LocalHostServerService.instance.isRunning.value;
        final isOffline = ApiConstants.isOfflineMode;

        // Never show disconnected banner if local offline or hosting the database
        if (isOffline || isHost || health.isConnected) {
          return const SizedBox.shrink();
        }

        final isLan = ApiConstants.currentMode == ConnectionMode.wifi ||
            ApiConstants.currentMode == ConnectionMode.usb;
        final hostLabel = health.targetHostLabel;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.red.shade800,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isLan ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isLan
                      ? '⚠️ Kasir Master ($hostLabel) Terputus'
                      : '⚠️ Server Cloud Terputus (Memeriksa internet...)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: health.isChecking
                    ? null
                    : () => health.checkHealth(),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (health.isChecking) ...[
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        health.isChecking ? 'Menguji...' : 'Uji Sambungan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
