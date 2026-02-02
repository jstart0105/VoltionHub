import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '/core/services/api/api_service.dart';
import '/data/models/branch.dart';
// import '/data/models/user.dart'; // Removido
import '/ui/widgets/button.dart';

class BranchFormDialog extends StatefulWidget {
  final Branch? branch;
  final ApiService apiService;
  final Function onSave;

  const BranchFormDialog({
    super.key,
    this.branch,
    required this.apiService,
    required this.onSave,
  });

  @override
  State<BranchFormDialog> createState() => _BranchFormDialogState();
}

class _BranchFormDialogState extends State<BranchFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  // List<User> _allUsers = []; // Removido
  // List<User> _selectedAdmins = []; // Removido
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.branch?.name ?? '');
    _addressController = TextEditingController(text: widget.branch?.address ?? '');
  }

  Future<void> _saveBranch() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // final adminIds = _selectedAdmins.map((user) => user.id).toList(); // Removido
        if (widget.branch == null) {
          // Chamada de API atualizada
          await widget.apiService.addBranch(_nameController.text, _addressController.text);
        } else {
          // Chamada de API atualizada
          await widget.apiService.updateBranch(widget.branch!.id, _nameController.text, _addressController.text);
        }
        widget.onSave();
        Navigator.of(context).pop();
      } catch (e) {
        // Handle error
      } finally {
        // Garante que o isLoading seja definido como false mesmo se houver um erro
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.branch == null ? 'Nova Filial' : 'Editar Filial', style: Theme.of(context).textTheme.headlineSmall),
            const Gap(16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome da Filial'),
              validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
            ),
            const Gap(16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Endereço'),
              validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
            ),
            const Gap(16),
            // Dropdown e Wrap de Sub-Admins removidos
            const Gap(24),
            CustomButton(
              onPressed: _isLoading ? null : () => _saveBranch(),
              text: 'Salvar',
            ),
            const Gap(16), // Espaçamento extra na parte inferior
          ],
        ),
      ),
    );
  }
}

