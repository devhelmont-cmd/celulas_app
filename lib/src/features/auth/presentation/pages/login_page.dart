import 'package:celulas_app/src/core/injections/injection_container.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_controller.dart';
import 'package:celulas_app/src/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/fade_page_route.dart';
import '../../../home/presentation/pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  //late final AuthController _authController;
  final _authController = getIt<AuthController>();

  @override
  void initState() {
    super.initState();
    /*final dataSource = AuthRemoteDataSourceImpl();
    final repository = AuthRepositoryImpl(remoteDataSource: dataSource);

    _authController = AuthController(
      loginWithEmailUseCase: LoginWithEmailUseCase(repository),
      loginWithGoogleUseCase: LoginWithGoogleUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
    );*/

    _authController.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    final state = _authController.value;
    if (state is AuthErrorState) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else if (state is AuthSuccessState) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bem-vindo, ${state.user.email}!')),
      );
      Navigator.of(
        context,
      ).pushReplacement(FadePageRoute(page: HomePage(user: state.user)));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authController.removeListener(_onAuthStateChanged);
    _authController.dispose();
    super.dispose();
  }

  void _onLoginWithEmail() {
    if (_formKey.currentState?.validate() ?? false) {
      _authController.loginWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    }
  }

  void _onLoginWithGoogle() {
    _authController.logingWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: ValueListenableBuilder<AuthState>(
                valueListenable: _authController,
                builder: (context, state, child) {
                  final isLoading = state is AuthLoadingState;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.church_outlined,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Células App',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Acesse sua conta para continuar',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          hintText: 'exemplo@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        enabled: !isLoading,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe seu e-mail';
                          }
                          if (!value.contains('@')) {
                            return 'Informe um e-mail válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          label: Text('Senha'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Informe sua senha';
                          }
                          if (value.length < 6) {
                            return 'A senha deve ter pelo menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      if (isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        FilledButton(
                          onPressed: _onLoginWithEmail,
                          child: Text('Entrar'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          //TODO: Implementar redefinição de senha
                        },
                        child: const Text('Esqueceu a senha?'),
                      ),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OU'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _onLoginWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Continuar com o Google'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
