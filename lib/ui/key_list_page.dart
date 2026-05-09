import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:clipboard/clipboard.dart';
import 'package:ssh_key_manager/providers/key_manager_provider.dart';
import 'package:ssh_key_manager/models/ssh_key.dart';
import 'package:ssh_key_manager/utils/file_utils.dart';
import 'package:ssh_key_manager/ui/key_detail_dialog.dart';
import 'package:ssh_key_manager/ui/import_key_dialog.dart';

class KeyListPage extends StatefulWidget {
  const KeyListPage({super.key});

  @override
  State<KeyListPage> createState() => _KeyListPageState();
}

class _KeyListPageState extends State<KeyListPage> {
  String _searchQuery = '';
  bool _sortByDate = true;

  @override
  void initState() {
    super.initState();
    Provider.of<KeyManagerProvider>(context, listen: false).loadKeys();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _copyPublicKey(SSHKey key) async {
    try {
      final publicKey = await FileUtils.readPublicKey(key.publicKeyPath);
      await FlutterClipboard.copy(publicKey);
      _showSnackBar('公钥已复制到剪贴板');
    } catch (e) {
      _showSnackBar('复制失败: ${e.toString()}', isError: true);
    }
  }

  Future<void> _openFileLocation(SSHKey key) async {
    try {
      await FileUtils.openFileLocation(key.privateKeyPath);
    } catch (e) {
      _showSnackBar('打开失败: ${e.toString()}', isError: true);
    }
  }

  void _showKeyDetail(SSHKey key) {
    showDialog(
      context: context,
      builder: (context) => KeyDetailDialog(sshKey: key),
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) => const ImportKeyDialog(),
    );
  }

  void _confirmDelete(SSHKey key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除密钥 "${key.name}" 吗？这将同时删除私钥和公钥文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final keyManager =
                  Provider.of<KeyManagerProvider>(context, listen: false);
              await keyManager.deleteKey(key.id);
              if (mounted) {
                Navigator.pop(context);
                _showSnackBar('密钥已删除');
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  List<SSHKey> _filterKeys(List<SSHKey> keys) {
    var filtered = keys.where((key) {
      return key.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          key.comment?.toLowerCase().contains(_searchQuery.toLowerCase()) ==
              true;
    }).toList();

    filtered.sort((a, b) {
      if (_sortByDate) {
        return b.createdAt.compareTo(a.createdAt);
      } else {
        return a.name.compareTo(b.name);
      }
    });

    return filtered;
  }

  Widget _buildKeyCard(SSHKey key) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (key.comment != null && key.comment!.isNotEmpty)
                        Text(
                          key.comment!,
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                    ],
                  ),
                ),
                _getStatusBadge(key.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(key.type.displayName),
                  backgroundColor: const Color.fromARGB(26, 30, 136, 229),
                  labelStyle: const TextStyle(color: Color(0xFF1E88E5)),
                ),
                const SizedBox(width: 8),
                if (key.hasPassphrase)
                  const Chip(
                    label: Text('已加密'),
                    backgroundColor: Color.fromARGB(26, 255, 165, 0),
                    labelStyle: TextStyle(color: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '创建时间: ${DateFormat('yyyy-MM-dd HH:mm').format(key.createdAt)}',
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copyPublicKey(key),
                  tooltip: '复制公钥',
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () => _openFileLocation(key),
                  tooltip: '打开文件位置',
                ),
                IconButton(
                  icon: const Icon(Icons.info, size: 18),
                  onPressed: () => _showKeyDetail(key),
                  tooltip: '查看详情',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: () => _confirmDelete(key),
                  tooltip: '删除',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusBadge(KeyStatus status) {
    final statusInfo = {
      KeyStatus.valid: (
        '有效',
        Colors.green,
        const Color.fromARGB(26, 0, 128, 0)
      ),
      KeyStatus.invalid: (
        '无效',
        Colors.red,
        const Color.fromARGB(26, 255, 0, 0)
      ),
      KeyStatus.encrypted: (
        '已加密',
        Colors.orange,
        const Color.fromARGB(26, 255, 165, 0)
      ),
      KeyStatus.missing: (
        '缺失',
        Colors.grey,
        const Color.fromARGB(26, 128, 128, 128)
      ),
    };

    final (text, color, bgColor) = statusInfo[status]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyManager = Provider.of<KeyManagerProvider>(context);
    final filteredKeys = _filterKeys(keyManager.keys);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索密钥...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _showImportDialog,
                child: const Text('导入密钥'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _sortByDate = !_sortByDate;
                  });
                },
                child: Text(_sortByDate ? '按名称排序' : '按时间排序'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => keyManager.refreshKeys(),
              ),
            ],
          ),
        ),
        Expanded(
          child: keyManager.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredKeys.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.key_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无密钥'),
                          Text('点击"生成密钥"创建新密钥'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredKeys.length,
                      itemBuilder: (context, index) {
                        return _buildKeyCard(filteredKeys[index]);
                      },
                    ),
        ),
      ],
    );
  }
}
