import 'package:rd_app/app/router/app_routes.dart';
import 'package:flutter/material.dart';

import 'package:rd_app/app/session_controller.dart';
import 'package:rd_app/core/theme/app_theme.dart';
import 'package:rd_app/shared/widgets/retinazo_logo.dart';
import 'package:rd_app/shared/widgets/page_body.dart';

class HomeScreen extends StatefulWidget {
  final SessionController sesion;
  const HomeScreen({super.key, required this.sesion});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SessionController get _sesion => widget.sesion;

  void _abrir(int index) {
    if (_sesion.isAdmin) {
      switch (index) {
        case 0:
          AppRoutes.adminUsers(context);
        case 1:
          AppRoutes.patients(context);
        case 2:
          AppRoutes.history(context);
        case 3:
          AppRoutes.statistics(context);
        default:
          AppRoutes.adminAudit(context);
      }
      return;
    }
    switch (index) {
      case 0:
        AppRoutes.patients(context);
      case 1:
        AppRoutes.patients(context, paraEvaluar: true);
      case 2:
        AppRoutes.history(context);
      default:
        AppRoutes.statistics(context);
    }
  }

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    await _sesion.logout();
    if (!mounted) return;
    // AuthGate drops the signed-in navigation stack.
  }

  static const _titulos = [
    'Pacientes',
    'Capturar imágenes\nde fondo de ojo',
    'Historial de\nevaluaciones',
    'Estadísticas',
  ];
  static const _iconos = [
    Icons.person_outline,
    Icons.photo_camera_outlined,
    Icons.history,
    Icons.bar_chart,
  ];
  List<String> get _labels => _sesion.isAdmin
      ? const [
          'Usuarios',
          'Todos los pacientes',
          'Todas las evaluaciones',
          'Estadísticas globales',
          'Actividad administrativa',
        ]
      : _titulos;
  List<IconData> get _icons => _sesion.isAdmin
      ? const [
          Icons.manage_accounts_outlined,
          Icons.people_outline,
          Icons.history,
          Icons.bar_chart,
          Icons.fact_check_outlined,
        ]
      : _iconos;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_sesion.isAdmin ? 'Administración' : 'Inicio')),
    drawer: _menuLateral(),
    body: PageBody(
      children: [
        const SizedBox(height: 12),
        if (_sesion.isAdmin) ...[
          Text(
            'Panel de administración',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestiona las cuentas y todos los expedientes de Retinazo.',
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: _sesion.admin,
            builder: (context, _) {
              final o = _sesion.admin.overview;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${o.users} usuarios')),
                  Chip(label: Text('${o.unconfirmed} correos pendientes')),
                  Chip(label: Text('${o.inactive} desactivados')),
                  Chip(label: Text('${o.patients} pacientes')),
                  Chip(label: Text('${o.evaluations} evaluaciones')),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _sesion.refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar panel'),
            ),
          ),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                MediaQuery.sizeOf(context).width < 360 ||
                    MediaQuery.textScalerOf(context).scale(14) > 17
                ? 1
                : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent:
                200 * MediaQuery.textScalerOf(context).scale(14) / 14,
          ),
          itemCount: _labels.length,
          itemBuilder: (context, i) => Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: Key('menu-$i'),
              borderRadius: BorderRadius.circular(20),
              splashColor: AppTheme.primario.withValues(alpha: 0.12),
              highlightColor: AppTheme.primario.withValues(alpha: 0.05),
              onTap: () => _abrir(i),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[i], size: 44, color: AppTheme.primario),
                    const SizedBox(height: 18),
                    Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );

  Widget _menuLateral() => Drawer(
    backgroundColor: const Color(0xFF0B5555),
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppTheme.fondo,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const RetinazoLogo(size: 76),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Cerrar menú',
                      onPressed: () => Navigator.pop(context),
                      color: Colors.white.withValues(alpha: 0.8),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Retinazo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  (_sesion.auth.personal?.nombre ?? 'Personal de salud'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _sesion.isAdmin
                      ? 'Administrador · v1.1.0'
                      : 'Profesional · v1.1.0',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  (_sesion.auth.personal?.usuario ?? ''),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 24,
            endIndent: 24,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 0, 14),
                    child: Text(
                      'MENÚ PRINCIPAL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  _opcionLateral(
                    Icons.home_outlined,
                    'Inicio',
                    () => Navigator.pop(context),
                    activa: true,
                  ),
                  for (int i = 0; i < _labels.length; i++)
                    _opcionLateral(
                      _icons[i],
                      _labels[i].replaceAll('\n', ' '),
                      () {
                        Navigator.pop(context);
                        _abrir(i);
                      },
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _salir();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _opcionLateral(
    IconData icono,
    String titulo,
    VoidCallback onTap, {
    bool activa = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: activa
          ? Colors.white.withValues(alpha: 0.14)
          : Colors.transparent,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: activa ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icono, color: Colors.white, size: 23),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: Colors.white.withValues(alpha: 0.6),
      ),
    ),
  );
}
