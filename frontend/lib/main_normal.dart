import 'package:flutter/material.dart';
import 'main.dart' as app;
import 'config/flavor_config.dart';

void main() {
  FlavorConfig.initialize(AppFlavor.normal);
  app.main();
}
