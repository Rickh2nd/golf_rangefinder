// This file is used on Flutter Web.
import 'package:flutter/material.dart';

class MapboxMap extends StatelessWidget {
  final String accessToken;
  final String styleString;
  final CameraPosition initialCameraPosition;
  final Function(MapboxMapController) onMapCreated;
  final bool myLocationEnabled;

  const MapboxMap({
    Key? key,
    required this.accessToken,
    required this.styleString,
    required this.initialCameraPosition,
    required this.onMapCreated,
    this.myLocationEnabled = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Mapbox GL is not supported on Flutter Web.",
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class MapboxMapController {
  // Stub controller—no functionality.
}

class CameraPosition {
  final LatLng target;
  final double zoom;

  const CameraPosition({required this.target, required this.zoom});
}

class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}
