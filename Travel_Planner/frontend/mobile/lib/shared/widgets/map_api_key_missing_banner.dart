import 'package:flutter/material.dart';

/// Reusable banner displayed when CARTO Basemaps API Key is not configured.
///
/// Educates the developer/user on why basemap tiles are not rendering and gives
/// the exact `--dart-define=CARTO_API_KEY=<key>` startup parameter.
/// Can be dismissed by the user to freely interact with markers and routes.
class MapApiKeyMissingBanner extends StatefulWidget {
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry margin;

  const MapApiKeyMissingBanner({
    super.key,
    this.onDismiss,
    this.margin = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<MapApiKeyMissingBanner> createState() => _MapApiKeyMissingBannerState();
}

class _MapApiKeyMissingBannerState extends State<MapApiKeyMissingBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        color: const Color(0xFFFFFBEB), // Amber 50
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(
            color: Color(0xFFFDE68A), // Amber 200
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.vpn_key_outlined,
                  size: 20,
                  color: Color(0xFFD97706), // Amber 600
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Chưa cấu hình CARTO Basemaps API Key',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E), // Amber 900
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Bản đồ nền yêu cầu API Key để tải tile. Khởi chạy với:',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF78350F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7), // Amber 100
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFCD34D),
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        '--dart-define=CARTO_API_KEY=<your_key>',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Lấy key miễn phí tại carto.com/basemaps/apikey',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFB45309),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF92400E),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Đóng thông báo',
                onPressed: () {
                  setState(() => _dismissed = true);
                  widget.onDismiss?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
