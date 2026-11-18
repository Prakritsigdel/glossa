import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/placeholder_controller.dart';
import '../models/placeholder_model.dart';

/// Placeholder View: renders data supplied through its MVC controller.
class PlaceholderView extends StatelessWidget {
  const PlaceholderView({super.key, required this.model});

  final PlaceholderModel model;

  @override
  Widget build(BuildContext context) {
    final controller = PlaceholderController(model);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.model.title,
                textAlign: TextAlign.center,
                style: AppTextStyles.display.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                controller.model.note,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
