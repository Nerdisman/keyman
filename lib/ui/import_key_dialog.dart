import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ssh_key_manager/providers/key_manager_provider.dart';

class ImportKeyDialog extends StatefulWidget {
  const ImportKeyDialog({super.key});

  @override
  State<ImportKeyDialog> createState() => _ImportKeyDialogState();
}

class _ImportKeyDialogState extends State<ImportKeyDialog> {
  String? _privateKeyPath;
  String? _publicKeyPath;
  bool _isImporting = false;
  String? _errorMessage;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectPrivateKey() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowedExtensions: ['', 'pem', 'key'],
    );

    if (result != null) {
      setState(() {
        _privateKeyPath = result.files.single.path;
        if (_privateKeyPath != null && _publicKeyPath == null) {
          _publicKeyPath = '${_privateKeyPath!}.pub';
        }
      });
    }
  }

  Future<void> _selectPublicKey() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowedExtensions: ['pub'],
    );

    if (result != null) {
      setState(() {
        _publicKeyPath = result.files.single.path;
      });
    }
  }

  Future<void> _importKey() async {
    if (_privateKeyPath == null || _publicKeyPath == null) {
      setState(() {
        _errorMessage = '请选择私钥和公钥文件';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    final keyManager = Provider.of<KeyManagerProvider>(context, listen: false);
    final success =
        await keyManager.importKey(_privateKeyPath!, _publicKeyPath!);

    setState(() {
      _isImporting = false;
    });

    if (mounted) {
      if (success) {
        _showSnackBar('密钥导入成功');
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = keyManager.errorMessage ?? '导入失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导入密钥'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('请选择私钥和公钥文件'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _privateKeyPath ?? '未选择私钥',
                  style: TextStyle(
                    fontSize: 12,
                    color: _privateKeyPath != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _selectPrivateKey,
                child: const Text('选择私钥'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _publicKeyPath ?? '未选择公钥',
                  style: TextStyle(
                    fontSize: 12,
                    color: _publicKeyPath != null ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _selectPublicKey,
                child: const Text('选择公钥'),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isImporting ? null : _importKey,
          child: _isImporting
              ? const CircularProgressIndicator()
              : const Text('导入'),
        ),
      ],
    );
  }
}
