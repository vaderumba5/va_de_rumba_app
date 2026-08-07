import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/group_document.dart';
import '../services/group_document_service.dart';
import '../models/app_permission.dart';
import '../providers/current_user_scope.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const _categories = [
    'Dossier',
    'Rider técnico',
    'Contratos',
    'Facturas',
    'Letras',
    'Administración',
    'Promoción',
    'Otros',
  ];

  final _service = GroupDocumentService();
  bool _uploading = false;
  String _selectedCategory = 'Todos';

  Future<void> _upload() async {
    if (_uploading) return;

    final file = await _service.pickPdf();
    if (file == null || !mounted) return;

    final titleController = TextEditingController(
      text: file.name.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );
    final descriptionController = TextEditingController();
    var category = 'Otros';

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Subir documento'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: _categories
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) => category = value ?? category,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Subir PDF'),
          ),
        ],
      ),
    );

    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();

    if (accepted != true || title.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    try {
      await _service.upload(
        file: file,
        title: title,
        category: category,
        description: description,
      );
      if (mounted) _showMessage('Documento subido correctamente.');
    } catch (error, stackTrace) {
      debugPrint('Error al subir documento: $error\n$stackTrace');
      if (mounted) {
        _showMessage(_service.errorMessage(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDocument(GroupDocument document) async {
    try {
      final opened = await launchUrl(
        Uri.parse(document.downloadUrl),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!opened && mounted) {
        _showMessage('No se ha podido abrir el documento.', error: true);
      }
    } catch (error, stackTrace) {
      debugPrint('Error al abrir documento: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido abrir el documento.', error: true);
      }
    }
  }

  Future<void> _confirmDelete(GroupDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text('Se eliminará “${document.title}” de forma permanente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.delete(document);
      if (mounted) _showMessage('Documento eliminado.');
    } catch (error, stackTrace) {
      debugPrint('Error al eliminar documento: $error\n$stackTrace');
      if (mounted) {
        _showMessage('No se ha podido eliminar el documento.', error: true);
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManage = CurrentUserScope.authorization.canManageModule(
      CurrentUserScope.of(context),
      AppModules.documents,
    );
    return Scaffold(
      body: StreamBuilder<List<GroupDocument>>(
        stream: _service.watch(),
        builder: (context, snapshot) {
          final documents = snapshot.data ?? const <GroupDocument>[];
          final visibleDocuments = _selectedCategory == 'Todos'
              ? documents
              : documents
                  .where((document) => document.category == _selectedCategory)
                  .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  const Text(
                    'Documentación',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  FilledButton.icon(
                    onPressed: _uploading || !canManage ? null : _upload,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_outlined),
                    label: Text(_uploading ? 'Subiendo…' : 'Subir documento'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedCategory),
                initialValue: _selectedCategory,
                decoration:
                    const InputDecoration(labelText: 'Filtrar categoría'),
                items: ['Todos', ..._categories]
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No se han podido cargar los documentos.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (visibleDocuments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('Todavía no hay documentos en esta categoría.'),
                  ),
                )
              else
                ...visibleDocuments.map((document) =>
                    _documentTile(document, canManage: canManage)),
            ],
          );
        },
      ),
    );
  }

  Widget _documentTile(GroupDocument document, {required bool canManage}) {
    final date = document.createdAt == null
        ? 'Fecha pendiente'
        : DateFormat('d MMM y', 'es_ES').format(document.createdAt!);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(document.title),
        subtitle: Text(
          '${document.category} · $date · ${_fileSize(document.sizeBytes)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Abrir PDF',
              onPressed: () => _openDocument(document),
              icon: const Icon(Icons.open_in_new),
            ),
            IconButton(
              tooltip: 'Eliminar documento',
              onPressed: canManage ? () => _confirmDelete(document) : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  String _fileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${NumberFormat.decimalPattern('es_ES').format(bytes / 1024)} KB';
  }
}
