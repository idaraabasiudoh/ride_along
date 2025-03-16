import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String apiKey = "AIzaSyAVCLhTi9_yZjE8flxJFWkqo9c087NE420";
const String carletonLat = "45.3876"; // Carleton University Latitude
const String carletonLng = "-75.6960"; // Carleton University Longitude

class GoogleMapsService {
  static Future<Map<String, dynamic>> getRoute(LatLng origin, LatLng destination) async {
    final url = Uri.parse(
        "https://routes.googleapis.com/directions/v2:computeRoutes?"
            "key=$apiKey");

    final body = jsonEncode({
      "origin": {
        "location": {"latLng": {"latitude": origin.latitude, "longitude": origin.longitude}}
      },
      "destination": {
        "location": {"latLng": {"latitude": destination.latitude, "longitude": destination.longitude}}
      },
      "travelMode": "DRIVE",
      "computeAlternativeRoutes": false,
      "routingPreference": "TRAFFIC_AWARE",
    });

    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: body);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Failed to get route");
    }
  }

  static Future<double> getDistance(LatLng origin, LatLng destination) async {
    var routeData = await getRoute(origin, destination);
    return routeData['routes'][0]['distanceMeters'] / 1000.0; // Convert meters to km
  }

  // Get route and distance from a driver to Carleton University
  static Future<Map<String, dynamic>> getDriverToCarletonRoute(LatLng driverLocation) async {
    LatLng carletonLocation = LatLng(double.parse(carletonLat), double.parse(carletonLng));
    return await getRoute(driverLocation, carletonLocation);
  }

  // Find drivers within an 8km radius from the passenger location
  static Future<List<Map<String, dynamic>>> findDriversNearby(LatLng passengerLocation, List<LatLng> driverLocations) async {
    List<Map<String, dynamic>> nearbyDrivers = [];
    for (var driverLocation in driverLocations) {
      double distance = await getDistance(passengerLocation, driverLocation);
      if (distance <= 8.0) { // 8km radius
        Map<String, dynamic> driverInfo = {
          'location': driverLocation,
          'distance': distance,
        };
        nearbyDrivers.add(driverInfo);
      }
    }
    return nearbyDrivers;
  }

  // Calculate the ride price, limiting it to 70% of Uber/Lyft price
  static double calculateRidePrice(double distanceInKm) {
    const double uberPricePerKm = 2.0; // Example price (can be adjusted)
    double estimatedPrice = distanceInKm * uberPricePerKm;
    return estimatedPrice * 0.7; // Cap at 70% of Uber price
  }
}
