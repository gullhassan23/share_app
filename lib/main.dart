import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_app_latest/routes/app_pages.dart';
import 'package:share_app_latest/routes/app_routes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Share-It',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // GETX ROUTING
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
