import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class BookstoreService {
  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<void> openGoogleMapsBookstore(Position position) async {
    final lat = position.latitude;
    final lng = position.longitude;

    // Query Google Maps untuk toko buku terdekat
    final uri = Uri.parse(
      'https://www.google.com/maps/search/toko+buku/@$lat,$lng,14z',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}