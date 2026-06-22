# TOML Parser Plugin for Godot 4.6+

一个完整的 TOML v1.0 解析器和序列化器插件，适用于 Godot 4.6+。

## 功能特性

- 完整的 TOML v1.0 规范支持
- 解析 TOML 字符串为 Godot Dictionary
- 将 Godot Dictionary 序列化为 TOML 字符串
- 支持从文件加载和保存
- 错误处理和位置信息
- 作为自动加载单例全局可用

## 安装方法

### 方法一：通过 Godot 编辑器安装

1. 下载或克隆此仓库
2. 将 `addons/toml_parser` 文件夹复制到你的 Godot 项目的 `addons` 目录下
3. 在 Godot 编辑器中，进入 **项目 > 项目设置 > 插件**
4. 找到 "TOML Parser" 插件并启用它

### 方法二：手动安装

1. 下载或克隆此仓库
2. 将整个 `addons/toml_parser` 文件夹复制到你的 Godot 项目的 `addons` 目录下
3. 编辑你的 `project.godot` 文件，在 `[editor_plugins]` 部分添加：
   ```ini
   enabled=PackedStringArray("res://addons/toml_parser/plugin.cfg")
   ```

## 使用方法

插件启用后，会自动注册一个名为 `TOML` 的全局自动加载单例。你可以在任何脚本中直接使用它。

### 解析 TOML 字符串

```gdscript
var toml_string = """
[database]
server = "192.168.1.1"
ports = [ 8001, 8001, 8002 ]
connection_max = 5000
enabled = true
"""

var data = TOML.parse(toml_string)
print(data.database.server)  # 输出: 192.168.1.1
print(data.database.ports)   # 输出: [8001, 8001, 8002]
```

### 从文件加载 TOML

```gdscript
var data = TOML.load("res://config.toml")
if not data.is_empty():
    print(data)
```

### 安全解析（带错误处理）

```gdscript
var result = TOML.try_parse(toml_string)
if result.ok:
    print(result.data)
else:
    print("解析错误: ", result.error)
```

### 序列化为 TOML 字符串

```gdscript
var data = {
    "database": {
        "server": "192.168.1.1",
        "ports": [8001, 8001, 8002],
        "connection_max": 5000,
        "enabled": true
    }
}

var toml_string = TOML.dumps(data)
print(toml_string)
```

### 保存到文件

```gdscript
var data = {
    "database": {
        "server": "192.168.1.1",
        "ports": [8001, 8001, 8002],
        "connection_max": 5000,
        "enabled": true
    }
}

TOML.dump("user://config.toml", data)
```

## API 参考

### TOML 单例方法

| 方法 | 参数 | 返回值 | 说明 |
|------|------|--------|------|
| `parse(src: String)` | TOML 字符串 | `Dictionary` | 解析 TOML 字符串，失败时返回空字典并打印错误 |
| `load(path: String)` | 文件路径 | `Dictionary` | 从文件加载 TOML，失败时返回空字典 |
| `try_parse(src: String)` | TOML 字符串 | `Dictionary` | 安全解析，返回 `{ok: bool, data: Dictionary, error: String}` |
| `try_load(path: String)` | 文件路径 | `Dictionary` | 安全加载，返回 `{ok: bool, data: Dictionary, error: String}` |
| `dumps(data: Dictionary)` | 数据字典 | `String` | 将字典序列化为 TOML 字符串 |
| `dump(path: String, data: Dictionary)` | 文件路径, 数据字典 | `void` | 将字典保存为 TOML 文件 |

## 支持的 TOML 特性

- 基本字符串和字面量字符串
- 多行基本字符串和多行字面量字符串
- 整数、浮点数、特殊浮点值（inf, nan）
- 布尔值
- 日期时间（偏移日期时间、本地日期时间、本地日期、本地时间）
- 数组（包括混合类型数组）
- 内联表
- 标准表
- 数组表（Array of Tables）
- 注释
- 嵌套键
- 所有标准转义序列

## 许可证

MIT License

## 作者

Blueprint Project
