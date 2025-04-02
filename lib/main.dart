import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Provides hashValues.
import 'package:http/http.dart' as http;
import 'mapbox_map_wrapper.dart';

// Your API keys:
const String GOLF_COURSE_API_KEY = "CWOLF3X67UH2BCT4FKCQXSOSFI";
const String MAPBOX_ACCESS_TOKEN = "pk.eyJ1Ijoicmlja2gybmQiLCJhIjoiY204czljb2tlMGVmdjJpcHY5cmc4ZTV6ayJ9.jt_I63l0OVPJq0QulNHaNw";

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
        // Using a new color scheme with a secondary color:
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
            .copyWith(secondary: Colors.orangeAccent),
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
    List<Hole> holesList =
        holesJson.map((holeJson) => Hole.fromJson(holeJson)).toList();
    return Course(
      id: json['id'] ?? "",
      name: json['name'] ?? "Unknown Course",
      holes: holesList,
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
    var tee = json['teeBox'];
    LatLng teeBox = LatLng(tee['lat']?.toDouble() ?? 0.0, tee['lng']?.toDouble() ?? 0.0);
    var polygonJson = json['greenPolygon'] as List;
    List<LatLng> polygon = polygonJson
        .map((point) =>
            LatLng(point['lat']?.toDouble() ?? 0.0, point['lng']?.toDouble() ?? 0.0))
        .toList();

    return Hole(
      number: json['number'] ?? 1,
      par: json['par'] ?? 4,
      teeBox: teeBox,
      greenPolygon: polygon,
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
        var jsonData = json.decode(response.body);
        var coursesJson = jsonData['courses'] as List;
        List<Course> fetchedCourses =
            coursesJson.map((courseJson) => Course.fromJson(courseJson)).toList();
        setState(() {
          courses = fetchedCourses;
          if (courses.isNotEmpty) {
            selectedCourse = courses[0];
            currentHole = selectedCourse!.holes[0];
            flagPosition = currentHole!.teeBox;
          }
          isLoading = false;
        });
      } else {
        setState(() {
          courses = _dummyCourses();
          selectedCourse = courses[0];
          currentHole = selectedCourse!.holes[0];
          flagPosition = currentHole!.teeBox;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching courses: $e");
      setState(() {
        courses = _dummyCourses();
        selectedCourse = courses[0];
        currentHole = selectedCourse!.holes[0];
        flagPosition = currentHole!.teeBox;
        isLoading = false;
      });
    }
  }

  List<Course> _dummyCourses() {
    Course dummyCourse = Course(
      id: "dummy1",
      name: "Dummy Golf Course",
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
        ),
      ],
    );
    return [dummyCourse];
  }

  // Calculate distance in yards using the Haversine formula.
  double calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371000; // in meters
    double dLat = _deg2rad(b.latitude - a.latitude);
    double dLon = _deg2rad(b.longitude - a.longitude);
    double lat1 = _deg2rad(a.latitude);
    double lat2 = _deg2rad(b.latitude);
    double aVal = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    double distanceInMeters = earthRadius * c;
    return distanceInMeters * 1.09361; // convert meters to yards
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  // Ray-casting algorithm to check if a point is inside a polygon.
  bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      LatLng vertex1 = polygon[j];
      LatLng vertex2 = polygon[(j + 1) % polygon.length];
      if (((vertex1.latitude > point.latitude) != (vertex2.latitude > point.latitude)) &&
          (point.longitude < (vertex2.longitude - vertex1.longitude) *
                  (point.latitude - vertex1.latitude) /
                  (vertex2.latitude - vertex1.latitude) +
              vertex1.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  void _onMapCreated(MapboxMapController controller) async {
    mapController = controller;
    if (currentHole != null) {
      // Draw the green polygon overlay.
      await mapController!.addFill(
        FillOptions(
          geometry: [currentHole!.greenPolygon],
          fillColor: "#228B22",
          fillOpacity: 0.5,
        ),
      );
      // Add the draggable flag.
      flagSymbol = await mapController!.addSymbol(
        SymbolOptions(
          geometry: flagPosition!,
          iconImage: "golf-15", // Use a built-in Mapbox icon or a custom asset.
          iconSize: 1.5,
          draggable: true,
        ),
      );
    }
    // Center the map on the tee box.
    mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16),
    );
    // Listen for symbol taps to simulate dragging.
    mapController!.onSymbolTapped.add((Symbol symbol) {
      _simulateDrag(symbol);
    });
  }

  Future<void> _simulateDrag(Symbol symbol) async {
    // Force unwrap geometry (assumed non-null).
    LatLng currentPos = symbol.options.geometry!;
    // For demonstration, move the flag slightly north.
    LatLng newPosition = LatLng(currentPos.latitude + 0.00005, currentPos.longitude);
    if (isPointInPolygon(newPosition, currentHole!.greenPolygon)) {
      await mapController!.updateSymbol(symbol, SymbolOptions(geometry: newPosition));
      setState(() {
        flagPosition = newPosition;
        yardage = calculateDistance(currentHole!.teeBox, flagPosition!);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Flag must remain on the green")),
      );
    }
  }

  void _startRound() {
    if (selectedCourse != null && selectedCourse!.holes.isNotEmpty) {
      setState(() {
        currentHole = selectedCourse!.holes[0];
        flagPosition = currentHole!.teeBox;
        yardage = 0.0;
      });
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Round started at Hole 1")),
      );
    }
  }

  void _showHoleSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Hole"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: selectedCourse?.holes.length ?? 0,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text("Hole ${selectedCourse!.holes[index].number}"),
                  onTap: () {
                    setState(() {
                      currentHole = selectedCourse!.holes[index];
                      flagPosition = currentHole!.teeBox;
                      yardage = 0.0;
                    });
                    mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16),
                    );
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showCourseSelection() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Select Course"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: courses.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(courses[index].name),
                  onTap: () {
                    setState(() {
                      selectedCourse = courses[index];
                      currentHole = selectedCourse!.holes[0];
                      flagPosition = currentHole!.teeBox;
                      yardage = 0.0;
                    });
                    mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(currentHole!.teeBox, 16),
                    );
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        );
      },
    );
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
      appBar: AppBar(
        title: Text("Golf Rangefinder"),
        actions: [
          IconButton(
            icon: Icon(Icons.golf_course),
            onPressed: _showHoleSelection,
          ),
          IconButton(
            icon: Icon(Icons.map),
            onPressed: _showCourseSelection,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapboxMap(
            accessToken: MAPBOX_ACCESS_TOKEN,
            styleString: "mapbox://styles/mapbox/satellite-v9",
            initialCameraPosition:
                CameraPosition(target: currentHole!.teeBox, zoom: 16),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 100,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Yardage: ${yardage.toStringAsFixed(1)} yds",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _startRound,
                  child: Text("Start Round"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
