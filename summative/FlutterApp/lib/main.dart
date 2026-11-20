import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/predict_page.dart';

void main() => runApp(const DebtApp());

class DebtApp extends StatelessWidget {
  const DebtApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Graduate Debt',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const PredictPage(),
      );
}
