# CA Installer

将多种抓包软件的CA证书安装到系统中的 Magisk/KernelSU/APatch 模块。

## 功能特性

- 📦 **自动检测和安装证书**
- 🔐 **系统级证书安装**
- 📱 **Android 14+ 支持**
- 🔄 **多框架兼容**
- 🌍 **多语言支持**

## 支持的应用

- **AdGuard** - 广告拦截应用
- **Reqable** - 抓包软件
- **HttpCanary** - 抓包软件
- **ProxyPin** - 抓包软件

## 安装 | Installation

1. 下载最新的 Module.zip 文件
2. 安装模块
3. 重启设备

## 工作原理 | How it Works

1. 从各个软件的私有目录提取证书
2. 通过 CertName.dex 计算证书的系统证书名
3. 挂载证书

### 安装流程 | Installation Process

1. **customize.sh** - 在安装过程中提取模块文件并查找已安装的证书
2. **post-fs-data.sh** - 启动时检测新增的证书并挂载到系统证书目录
3. **CertName.dex** - 计算证书的 MD5 哈希值以确定正确的证书文件名

### 证书命名 | Certificate Naming

系统证书使用 OpenSSL 风格的命名规则：

```
[HASH].0
```

其中 `[HASH]` 是证书 Subject Name 的 MD5 哈希值的前 4 字节（little-endian 编码）。

CertName.java 程序计算这个哈希值，确保证书被正确识别。

### Android 14+ 支持

由于 Android 14+ 使用 APEX 模块来管理系统证书，Magisk 无法直接注入文件。本模块采用以下方案：

1. 创建 tmpfs 临时挂载点
2. 复制系统证书和模块证书到临时目录
3. 将临时目录绑定挂载到 `/apex/com.android.conscrypt/cacerts`
4. 为 zygote 进程应用同样的挂载

## 文件结构 | File Structure

```
├── CertName.java              # 证书哈希计算程序
├── make.py                    # 构建脚本
├── customize.sh               # 安装时执行
├── post-fs-data.sh            # 启动时执行
├── .ca_inst_state.sh          # 服务脚本（状态检测）
├── module.prop                # 模块配置
└── system/etc/security/cacerts/  # 证书存储目录
```

## 文件说明 | File Descriptions

### CertName.java
计算证书的系统级文件名。使用 MD5 哈希算法计算证书 Subject Name 的哈希值，取前 4 字节作为十六进制文件名前缀。

### make.py
构建脚本，执行以下操作：
- 编译 CertName.java 为 dex 文件
- 为所有文件生成 SHA256 校验和
- 打包整个模块为 ZIP 文件

### customize.sh
Magisk 安装脚本，负责：
- 验证 ZIP 文件完整性
- 提取模块文件
- 查找并复制用户已安装的证书到模块目录

### post-fs-data.sh
启动脚本，负责：
- 检测系统中的证书
- 设置正确的 SELinux 上下文
- 对于 Android 14+，挂载证书目录到 APEX 模块

### .ca_inst_state.sh
服务脚本，检查模块是否被禁用并更新模块状态描述。

## 日志 | Logs

安装后的日志可以在以下位置找到：

```
/data/adb/modules/CA-Installer/CustomCACert.log
```

使用 `adb shell` 查看日志：

```bash
adb shell cat /data/adb/modules/CA-Installer/CustomCACert.log
```

## 常见问题 | FAQ

**Q: 模块安装后需要重启吗？**
A: 是的，需要重启设备以使证书生效。

**Q: 如何卸载模块？**
A: 在 Magisk/KernelSU/APatch 管理器中找到 CA Installer 模块，点击卸载即可。

**Q: 为什么某个应用的证书没有被安装？**
A: 确保应用已经安装并且证书已经导入到应用中。检查日志文件了解详细信息。

**Q: 支持自定义证书吗？**
A: 当前模块仅支持从特定应用中查找证书。如需添加其他应用，请修改 post-fs-data.sh 中的检查逻辑。

**Q: 模块与其他 root 管理器兼容吗？**
A: 支持 Magisk、KernelSU 和 APatch 三种框架。

## 构建 | Building

使用提供的 make.py 脚本构建模块：

```bash
# 需要 Java 8+ 和 Android SDK Build Tools
python3 make.py
```

这将生成 `Module.zip` 文件。

### 构建要求

- Python 3
- Java 8 或更高版本
- Android SDK Build Tools（dx 工具）

## 许可证 | License

该项目的具体许可证信息请查看项目根目录中的 LICENSE 文件。

## 贡献者 | Contributors

- **Twilight** - 原始作者
- **Lan** - 当前维护者

## 支持 | Support

如果遇到问题，请：

1. 检查 `/data/adb/modules/CA-Installer/CustomCACert.log` 日志文件
2. 确保使用最新版本的模块
3. 提供详细的错误信息和日志内容

## 更新日志 | Changelog

请看 [CHANGELOG.md](./CHANGELOG.md)

---

**最后更新** | Last Updated: 2025-10-10