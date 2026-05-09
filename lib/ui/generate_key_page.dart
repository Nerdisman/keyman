import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssh_key_manager/providers/key_manager_provider.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';
import 'package:ssh_key_manager/utils/file_utils.dart';

class GenerateKeyPage extends StatefulWidget {
  const GenerateKeyPage({super.key});

  @override
  State<GenerateKeyPage> createState() => _GenerateKeyPageState();
}

class _GenerateKeyPageState extends State<GenerateKeyPage> {
  final _formKey = GlobalKey<FormState>();
  String _keyName = '';
  String? _comment;
  String? _passphrase;
  String? _confirmPassphrase;
  String? _customPath;
  KeyType _selectedType = KeyType.rsa2048;
  bool _isGenerating = false;
  String? _errorMessage;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _generateKey() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passphrase != null && _passphrase != _confirmPassphrase) {
      setState(() {
        _errorMessage = '两次输入的密码不一致';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final keyManager = Provider.of<KeyManagerProvider>(context, listen: false);
    final success = await keyManager.generateKey(
      name: _keyName,
      type: _selectedType,
      comment: _comment,
      passphrase: _passphrase,
      customPath: _customPath,
    );

    setState(() {
      _isGenerating = false;
    });

    if (success) {
      _showSnackBar('密钥生成成功');
      _formKey.currentState!.reset();
      setState(() {
        _selectedType = KeyType.rsa2048;
        _customPath = null;
      });
    } else {
      setState(() {
        _errorMessage = keyManager.errorMessage ?? '生成失败';
      });
    }
  }

  Future<void> _selectPath() async {
    final defaultPath = await FileUtils.getDefaultSSHPath();
    setState(() {
      _customPath = defaultPath;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '生成新密钥',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '密钥名称',
                hintText: '例如: id_rsa',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密钥名称';
                }
                if (value.contains(RegExp(r'[\\/:*?"<>|]'))) {
                  return '名称不能包含特殊字符';
                }
                return null;
              },
              onSaved: (value) => _keyName = value!,
              onChanged: (value) => _keyName = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                hintText: '添加备注信息',
                border: OutlineInputBorder(),
              ),
              onSaved: (value) => _comment = value,
              onChanged: (value) => _comment = value,
            ),
            const SizedBox(height: 16),
            const Text('密钥类型'),
            const SizedBox(height: 8),
            Row(
              children: KeyType.values.map((type) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedType = type;
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedType == type
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey,
                              width: 2,
                            ),
                            color: _selectedType == type
                                ? Theme.of(context).primaryColor
                                : Colors.transparent,
                          ),
                          child: _selectedType == type
                              ? const Icon(Icons.check,
                                  size: 12, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(type.displayName),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: '存储路径（可选）',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: _customPath),
                    onSaved: (value) => _customPath = value,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectPath,
                  child: const Text('选择路径'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('设置密码（可选，加密私钥）'),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
                hintText: '输入密码以加密私钥',
              ),
              obscureText: true,
              onSaved: (value) => _passphrase = value,
              onChanged: (value) => _passphrase = value,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: '确认密码',
                border: OutlineInputBorder(),
                hintText: '再次输入密码',
              ),
              obscureText: true,
              onSaved: (value) => _confirmPassphrase = value,
              onChanged: (value) => _confirmPassphrase = value,
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateKey,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 8),
                          Text('生成中...'),
                        ],
                      )
                    : const Text('生成密钥'),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '生成的密钥将保存在指定路径下，包含私钥和公钥文件',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
