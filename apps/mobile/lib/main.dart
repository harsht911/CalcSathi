import 'package:flutter/material.dart';

import 'app.dart';
import 'core/firebase_bootstrap.dart';

Future<void> main() async {
  await bootstrapFirebase();
  runApp(const CalcSathiApp());
}
