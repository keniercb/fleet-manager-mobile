import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // El bootstrap de sesión lo ejecuta SessionController.build() al crear
  // el provider (RF-01.2 auto-login: lee token de secure storage y llama
  // a GET /api/auth/me si existe).
  runApp(const ProviderScope(child: RegistroRecorridosApp()));
}
