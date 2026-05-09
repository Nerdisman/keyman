import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';
import 'package:ssh_key_manager/providers/key_manager_provider.dart';
import 'package:ssh_key_manager/utils/file_utils.dart';

class KeyDetailDialog extends StatefulWidget {
  final SSHKey sshKey;

  const KeyDetailDialog({super.key, required this.sshKey});

  @override
  State<KeyDetailDialog> createState() => _KeyDetailDialogState();
}

class _KeyDetailDialogState extends State<KeyDetailDialog> {
  bool _isEditing = false;
  String _editedName = '';
  String _editedComment = '';

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyPublicKey() async {
    try {
      final publicKey =
          await FileUtils.readPublicKey(widget.sshKey.publicKeyPath);
      await FlutterClipboard.copy(publicKey);
      _showSnackBar('公钥已复制');
    } catch (e) {
      _showSnackBar('复制失败');
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editedName = widget.sshKey.name;
      _editedComment = widget.sshKey.comment ?? '';
    });
  }

  void _saveChanges() {
    Provider.of<KeyManagerProvider>(context, listen: false).updateKey(
      widget.sshKey.id,
      name: _editedName,
      comment: _editedComment.isEmpty ? null : _editedComment,
    );
    setState(() {
      _isEditing = false;
    });
    _showSnackBar('修改已保存');
  }

  @override
  Widget build(BuildContext context) {
    final sshKey = widget.sshKey;

    return AlertDialog(
      title: const Text('密钥详情'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing)
              Column(
                children: [
                  TextField(
                    controller: TextEditingController(text: _editedName),
                    onChanged: (value) => _editedName = value,
                    decoration: const InputDecoration(labelText: '名称'),
                  ),
                  TextField(
                    controller: TextEditingController(text: _editedComment),
                    onChanged: (value) => _editedComment = value,
                    decoration: const InputDecoration(labelText: '备注'),
                  ),
                  const SizedBox(height: 16),
                ],
              )
            else
              Column(
                children: [
                  _buildDetailRow('名称', sshKey.name),
                  _buildDetailRow('类型', sshKey.type.displayName),
                  _buildDetailRow('状态', _getStatusText(sshKey.status)),
                  _buildDetailRow('密码保护', sshKey.hasPassphrase ? '是' : '否'),
                  _buildDetailRow('创建时间',
                      DateFormat('yyyy-MM-dd HH:mm').format(sshKey.createdAt)),
                  _buildDetailRow('私钥路径', sshKey.privateKeyPath),
                  _buildDetailRow('公钥路径', sshKey.publicKeyPath),
                  if (sshKey.comment != null && sshKey.comment!.isNotEmpty)
                    _buildDetailRow('备注', sshKey.comment!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _copyPublicKey,
                    child: const Text('复制公钥'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        if (_isEditing)
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                },
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: _saveChanges,
                child: const Text('保存'),
              ),
            ],
          )
        else
          Row(
            children: [
              TextButton(
                onPressed: _startEditing,
                child: const Text('编辑'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusText(KeyStatus status) {
    return switch (status) {
      KeyStatus.valid => '有效',
      KeyStatus.invalid => '无效',
      KeyStatus.encrypted => '已加密',
      KeyStatus.missing => '缺失',
    };
  }
}
