import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/retinazo_logo.dart';

/// Drawer renders account details and delegates navigation to its parent.
class HomeDrawer extends StatelessWidget {
  final String name;
  final String email;
  final String roleLabel;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const HomeDrawer({
    super.key,
    required this.name,
    required this.email,
    required this.roleLabel,
    required this.labels,
    required this.icons,
    required this.onSelected,
    required this.onLogout,
  }) : assert(labels.length == icons.length);

  @override
  Widget build(BuildContext context) => Drawer(
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
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(roleLabel, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  email,
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
                  for (int i = 0; i < labels.length; i++)
                    _opcionLateral(
                      icons[i],
                      labels[i].replaceAll('\n', ' '),
                      () {
                        Navigator.pop(context);
                        onSelected(i);
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
                onLogout();
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
