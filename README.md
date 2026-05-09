# SSH密钥管理器

一个专业的SSH密钥对生成与本地管理工具，基于Flutter开发，完美适配Windows桌面系统。

## 功能特性

### 密钥生成
- ✅ 支持RSA 2048/4096位密钥类型
- ✅ 自定义密钥名称和备注信息
- ✅ 自定义存储路径（默认用户目录.ssh文件夹）
- ✅ 支持设置密钥密码（加密私钥）
- ✅ 生成后自动保存并校验密钥合法性
- ✅ 一键复制公钥到剪贴板

### 密钥管理
- ✅ 本地列表展示所有密钥（名称、类型、位数、创建时间、状态）
- ✅ 密钥查看、重命名、编辑备注
- ✅ 删除密钥（同时删除私钥和公钥文件）
- ✅ 打开文件所在位置
- ✅ 搜索/筛选密钥
- ✅ 支持按名称/时间排序
- ✅ 导入本地已存在的SSH密钥

### 高可用特性
- ✅ 全流程异常捕获（文件权限、路径不存在、密码错误等）
- ✅ 异步处理，不卡顿UI
- ✅ 实时状态提示（成功/失败/加载/空数据）
- ✅ 支持Windows系统暗色/亮色模式自适应

## 技术栈

- **框架**: Flutter 3.2.x (Dart)
- **状态管理**: Provider
- **密钥生成**: PointyCastle
- **持久化**: SharedPreferences
- **文件选择**: FilePicker
- **剪贴板**: Clipboard

## 安装与运行

### 环境要求
- Flutter 3.2.0 或更高版本
- Windows 10/11 操作系统

### 开发模式运行

```bash
# 克隆项目
git clone <repository-url>
cd keyman

# 安装依赖
flutter pub get

# 运行项目
flutter run -d windows
```

### 构建发布版本

```bash
# 构建Windows版本
flutter build windows

# 构建产物位置
# build/windows/x64/runner/Release/ssh_key_manager.exe
```

## 使用说明

### 生成新密钥
1. 点击左侧导航栏"生成密钥"
2. 输入密钥名称（如：id_rsa）
3. 选择密钥类型（RSA 2048位 或 RSA 4096位）
4. 可选：添加备注信息
5. 可选：设置密码保护私钥
6. 点击"生成密钥"按钮

### 管理密钥
1. 在"密钥列表"页面查看所有密钥
2. 使用搜索框筛选密钥
3. 点击操作按钮：
   - 📋 复制公钥到剪贴板
   - 📂 打开文件所在位置
   - ℹ️ 查看密钥详情和编辑
   - 🗑️ 删除密钥

### 导入密钥
1. 点击"导入密钥"按钮
2. 选择私钥文件（如：id_rsa）
3. 选择公钥文件（如：id_rsa.pub）
4. 点击"导入"按钮

## 项目结构

```
lib/
├── main.dart                    # 入口文件
├── app.dart                     # 应用主组件
├── models/
│   └── ssh_key.dart             # 密钥数据模型
├── providers/
│   ├── theme_provider.dart      # 主题状态管理
│   └── key_manager_provider.dart # 密钥管理状态
├── utils/
│   ├── key_generator.dart       # RSA密钥生成器
│   └── file_utils.dart          # 文件操作工具
└── ui/
    ├── home_page.dart           # 主页面布局
    ├── navigation_drawer.dart   # 左侧导航栏
    ├── key_list_page.dart       # 密钥列表页
    ├── generate_key_page.dart   # 密钥生成页
    ├── key_detail_dialog.dart   # 密钥详情对话框
    └── import_key_dialog.dart   # 导入密钥对话框
```

## 注意事项

1. 密钥文件默认保存在用户文档目录的 `.ssh` 文件夹中
2. 删除密钥会同时删除本地的私钥和公钥文件，请谨慎操作
3. 建议定期备份密钥文件到安全位置
4. 使用密码保护的密钥在使用时需要输入密码

## 许可证

MIT License

## 贡献

欢迎提交Issue和Pull Request！

---

**SSH密钥管理器** - 专业、安全、易用的密钥管理工具
