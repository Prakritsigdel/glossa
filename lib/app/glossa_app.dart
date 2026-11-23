import 'package:material_ui/material_ui.dart';
import 'router/app_router.dart';
import 'theme/glossa_theme.dart';

class GlossaApp extends StatelessWidget {
  const GlossaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Glossa',
      debugShowCheckedModeBanner: false,
      theme: glossaTheme(),
      routerConfig: appRouter,
    );
  }
}
