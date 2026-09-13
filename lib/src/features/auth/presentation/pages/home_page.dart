import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/domain/entities/user_entity.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final UserEntity user;

  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final authController = getIt<AuthController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Células App'),
        actions: [
          IconButton(
            onPressed: () async {
              await authController.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginPage()),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child:
                    user.photoUrl == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Bem-vindo(a)!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(user.email, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
