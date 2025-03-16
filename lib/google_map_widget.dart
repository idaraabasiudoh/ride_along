import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'google_maps_service.dart';

class GoogleMapWidget extends StatefulWidget {
  @override
  _GoogleMapWidgetState createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? _controller;
  LatLng _initialLocation = LatLng(45.3876, -75.6960); // Carleton University
  Location _location = Location();
  Set<Marker> _markers = {};
  List<LatLng> driverLocations = [
    LatLng(45.3500, -75.7500), // Example driver locations
    LatLng(45.4000, -75.7000),
    LatLng(45.4200, -75.6700),
  ];
  String? _ridePrice;
  String? _rideStatus;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  void _getUserLocation() async {
    var userLocation = await _location.getLocation();
    setState(() {
      _initialLocation = LatLng(userLocation.latitude!, userLocation.longitude!);
    });
  }

  // Fetch route and price for the driver to Carleton University
  void fetchDriverRouteAndPrice() async {
    LatLng driverLocation = LatLng(45.3500, -75.7500); // Example driver location

    // Get the route and distance to Carleton
    var route = await GoogleMapsService.getDriverToCarletonRoute(driverLocation);
    double distance = await GoogleMapsService.getDistance(driverLocation, _initialLocation);

    // Calculate the price (70% of Uber cost)
    double price = GoogleMapsService.calculateRidePrice(distance);

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('driver'),
          position: driverLocation,
          infoWindow: InfoWindow(title: 'Driver'),
        ),
      );
      _markers.add(
        Marker(
          markerId: MarkerId('passenger'),
          position: _initialLocation,
          infoWindow: InfoWindow(title: 'Passenger'),
        ),
      );
      _ridePrice = price.toStringAsFixed(2);
    });

    print("Route Polyline: ${route['routes'][0]['polyline']['encodedPolyline']}");
    print("Distance: ${distance.toStringAsFixed(2)} km");
    print("Estimated Ride Price: \$_ridePrice");
  }

  // Locate all drivers within 8km of the passenger
  void findDriversNearby() async {
    List<Map<String, dynamic>> nearbyDrivers = await GoogleMapsService.findDriversNearby(_initialLocation, driverLocations);

    setState(() {
      _rideStatus = nearbyDrivers.isEmpty
          ? 'No drivers found within 8 km'
          : '${nearbyDrivers.length} drivers found nearby';
    });

    print(_rideStatus);
  }

  // Handle ride request and driver response
  void handleRideRequest(Map<String, dynamic> driver) {
    setState(() {
      _rideStatus = 'Ride request sent to driver at ${driver['location']}';
    });
    // Logic for driver accepting or rejecting, and setting a price would go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ride-Share App')),
      body: GoogleMap(
        onMapCreated: (controller) => _controller = controller,
        initialCameraPosition: CameraPosition(
          target: _initialLocation,
          zoom: 14,
        ),
        myLocationEnabled: true,
        markers: _markers,
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: fetchDriverRouteAndPrice,
            child: Icon(Icons.directions),
            tooltip: 'Get Driver Route and Price',
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            onPressed: findDriversNearby,
            child: Icon(Icons.location_searching),
            tooltip: 'Find Drivers Nearby',
          ),
        ],
      ),
      bottomSheet: _rideStatus != null
          ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(_rideStatus!),
      )
          : null,
    );
  }
}
