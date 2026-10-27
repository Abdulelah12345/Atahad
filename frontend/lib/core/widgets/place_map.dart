import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/at_colors.dart';
import '../theme/at_tokens.dart';

// a small map: the pin and the circle the proof counts inside, a tap moves the pin
class PlaceMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final void Function(double latitude, double longitude)? onMove;
  final double height;

  const PlaceMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150,
    this.onMove,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final point = LatLng(latitude, longitude);
    // a bigger circle needs a wider view
    final zoom = radiusMeters >= 500 ? 14.5 : (radiusMeters >= 250 ? 15.5 : 16.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              // a new point or radius draws the map again around it
              key: ValueKey('$latitude,$longitude,$radiusMeters'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: zoom,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onTap: onMove == null ? null : (_, p) => onMove!(p.latitude, p.longitude),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.atahad.app',
                ),
                CircleLayer(circles: [
                  CircleMarker(
                    point: point,
                    radius: radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: c.accent.withValues(alpha: 0.18),
                    borderColor: c.accent,
                    borderStrokeWidth: 2,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(Icons.location_on_rounded, size: 44, color: c.primary),
                  ),
                ]),
              ],
            ),
            // the map data needs its credit, a tiny one in the corner
            PositionedDirectional(
              bottom: 4,
              end: 6,
              child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black.withValues(alpha: 0.55))),
            ),
            if (onMove != null)
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.surface.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(Radii.full)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: c.inkMuted),
                    const SizedBox(width: 4),
                    Text('اضغط تعدّل النقطة', style: Theme.of(context).textTheme.labelSmall!.copyWith(fontSize: 11)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
