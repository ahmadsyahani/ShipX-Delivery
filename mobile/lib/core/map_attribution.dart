import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    child: Material(
      color: Colors.white,
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            '© OpenStreetMap contributors',
            style: TextStyle(fontSize: 11, color: Color(0xFF394B40)),
          ),
        ),
      ),
    ),
  );
}
