import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

// Replace with your actual keys
const String GOLF_COURSE_API_KEY = "CWOLF3X67UH2BCT4FKCQXSOSFI";
const String MAPBOX_ACCESS_TOKEN = "sk.eyJ1Ijoicmlja2gybmQiLCJhIjoiY205MXA1NWtqMDNqazJpcHkzcHBvcWQ4eCJ9.FLm9Eeo-Vvl9WFJBSfVc_w";

void main() {
  runApp(GolfRangefinderApp());
}

class GolfRangefinderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golf Rangefinder',
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: MapScreen(),
    );
  }
}

class Course {
  final String id;
  final String name;
  final List<Hole> holes;

  Course({required this.id, required this.name, required this.holes});

  factory Course.fromJson(Map<String, dynamic> json) {
    var holesJson = json['holes'] as List;
    return Course(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unnamed Course',
      holes: holesJson.map((h) => Hole.fromJson(h)).toList(),
    );
  }
}

class Hole {
  final int number;
  final int par;
  final LatLng teeBox;
  final List<LatLng> greenPolygon;

  Hole({
    required this.number,
    required this.par,
    required this.teeBox,
    required this.greenPolygon,
  });

  factory Hole.fromJson(Map<String, dynamic> json) {
    final tee = json['teeBox'];
    final greenJson = json['greenPolygon'] as List;
    return Hole(
      number: json['number'],
      par: json['par'],
      teeBox: LatLng(tee['lat'].toDouble(), tee['lng'].toDouble()),
      greenPolygon: greenJson
          .map((p) => LatLng(p['lat'].toDouble(), p['lng'].toDouble()))
          .toList(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMapController? mapController;
  List<Course> courses = [];
  Course? selectedCourse;
  Hole? currentHole;
  Symbol? flagSymbol;
  LatLng? flagPosition;
  double yardage = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCourses();
  }

  Future<void> fetchCourses() async {
    final url = Uri.parse("https://golfcourseapi.com/api/courses?apikey=$GOLF_COURSE_API_KEY");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Course> fetchedCourses = (data['courses'] as List)
            .map((json) => Course.fromJson(json))
            .toList();

        setState(() {
          courses = fetchedCourses;
          selectedCourse = courses.first;
          currentHole = selectedCourse!.holes.first;
          flagPosition = currentHole!.teeBox;
          isLoading = false;
        });
      } else {
        useDummyCourses();
      }
    } catch (e) {
      useDummyCourses();
    }
  }

  void useDummyCourses() {
    Course dummy = Course(
      id: "1",
      name: "Dummy Course",
      holes: [
        Hole(
          number: 1,
          par: 4,
          teeBox: LatLng(37.33233141, -122.0312186),
          greenPolygon: [
            LatLng(37.3325, -122.0315),
            LatLng(37.3325, -122.0310),
            LatLng(37.3321, -122.0310),
            LatLng(37.3321, -122.0315),
          ],
        )
      ],
    );
    setState(() {
      courses = [dummy];
      selectedCourse = dummy;
      currentHole = dummy.holes[0];
      flagPosition = currentHole!.teeBox;
      isLoading = false;
    });
  }

  double calculateYardage(LatLng a, LatLng b) {
    const double R = 6371000; // meters
    double dLat = _deg2rad(b.latitude - a.latitude);
    double dLon = _deg2rad(b.longitude - a.longitude);
    double lat1 = _deg2rad(a.latitude);
    double lat2 = _deg2rad(b.latitude);
    double aVal = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return (R * c) * 1.09361; // yards
  }

  double _deg2rad(double deg) => deg * pi / 180;

  void _onMapCreated(MapboxMapController controller) async {
    mapController = controller;

    if (currentHole == null) return;

    // Draw green
    await mapController!.addFill(
      FillOptions(
        geometry: [currentHole!.greenPolygon],
        fillColor: "#00FF00",
        fillOpacity: 0.3,
      ),
    );

    // Drop flag
    flagSymbol = await mapController!.addSymbol(
      SymbolOptions(
        geometry: flagPosition!,
        iconImage: "golf-15",
        iconSize: 1.5,
        draggable: true,
      ),
    );

    mapController!.onSymbolTapped.add((symbol) async {
      final newPos = LatLng(symbol.options.geometry!.latitude + 0.00005, symbol.options.geometry!.longitude);
      await mapController!.updateSymbol(symbol, SymbolOptions(geometry: newPos));
      setState(() {
        flagPosition = newPos;
        yardage = calculateYardage(currentHole!.teeBox, newPos);
      });
    });

    await mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16),
    );
  }

  void _startRound() {
    if (selectedCourse == null) return;
    setState(() {
      currentHole = selectedCourse!.holes.first;
      flagPosition = currentHole!.teeBox;
      yardage = 0.0;
    });
    mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Golf Rangefinder")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Golf Rangefinder")),
      body: Stack(
        children: [
          MapboxMap(
            accessToken: MAPBOX_ACCESS_TOKEN,
            styleString: "mapbox://styles/mapbox/satellite-v9",
            initialCameraPosition: CameraPosition(
              target: currentHole!.teeBox,
              zoom: 16,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 100,
            left: 20,
            child: Card(
              color: Colors.white70,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  "Yardage: ${yardage.toStringAsFixed(1)} yds",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _startRound,
              child: Text("Start Round"),
            ),
          ),
        ],
      ),
    );
  }
}

