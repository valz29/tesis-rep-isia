import 'package:flutter/material.dart';

import '../../domain/entities/admin_account.dart';
import '../controllers/admin_controller.dart';

Future<AdminAccount?> chooseProfessional(
  BuildContext context,
  AdminController admin,
) => showModalBottomSheet<AdminAccount>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ProfessionalPicker(admin: admin),
);

class _ProfessionalPicker extends StatefulWidget {
  final AdminController admin;
  const _ProfessionalPicker({required this.admin});
  @override
  State<_ProfessionalPicker> createState() => _ProfessionalPickerState();
}

class _ProfessionalPickerState extends State<_ProfessionalPicker> {
  final _query = TextEditingController();
  late Future<List<AdminAccount>> _rows = widget.admin.eligibleOwners('');
  void _search() =>
      setState(() => _rows = widget.admin.eligibleOwners(_query.text.trim()));
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text(
              'Profesional responsable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Solo profesionales activos con correo confirmado.'),
            TextField(
              controller: _query,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Buscar por nombre o correo',
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<AdminAccount>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _search,
                        child: const Text('No se pudo cargar. Reintentar'),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay profesionales elegibles para esta búsqueda.',
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      for (final account in snapshot.data!)
                        ListTile(
                          title: Text(account.name),
                          subtitle: Text(account.email),
                          onTap: () => Navigator.pop(context, account),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
