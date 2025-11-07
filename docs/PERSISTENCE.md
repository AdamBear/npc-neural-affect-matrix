# NPC 数据持久化说明

## 概述

NPC Neural Affect Matrix 现在支持 JSON 文件持久化，可以在服务器重启后保留 NPC 的记忆数据。

## 数据存储位置

### 1. NPC 记忆数据 (Memory Records)
- **存储位置**: `target/release/npc_data/` 或可执行文件所在目录的 `npc_data/`
- **文件格式**: `{npc_id}.json`
- **持久化**: ✅ 是 - 服务器重启后自动加载

### 2. 神经网络模型
- **存储位置**: `target/release/npc_models_cache/NPC-Prediction-Model-v0.0.1/`
- **文件列表**:
  - `model.onnx` (268 MB) - ONNX神经网络模型
  - `tokenizer.json` (711 KB) - 分词器配置
  - `vocab.txt` (231 KB) - 词汇表
  - `config.json` - 模型配置
  - `version.txt` - 版本信息
- **自动更新**: ✅ 是 - 版本不匹配时自动从 Hugging Face 下载

## 功能特性

### 自动保存
每次 NPC 记忆发生变化时，数据会自动保存到 JSON 文件：
- ✅ 添加新记忆时 (`evaluate_interaction`)
- ✅ 导入记忆时 (`import`)
- ✅ 清空记忆时 (`clear`)
- ✅ 删除 NPC 时自动删除对应文件 (`remove_npc`)

### 自动加载
服务器启动时自动加载所有已保存的 NPC 数据：
```
INFO  npc_neural_affect_matrix: ✅ Loaded 1 NPC memory files from disk
```

### 数据格式

每个 NPC 的记忆存储为 JSON 数组：

```json
[
  {
    "id": "10ffdd7f-bf50-4104-9548-2206b0cfe5e1",
    "source_id": "player",
    "text": "Hello friend!",
    "valence": 0.514,
    "arousal": 0.1155,
    "past_time": 0
  }
]
```

**字段说明**:
- `id`: 记忆记录的唯一标识符
- `source_id`: 交互来源（如 "player", "thief" 等）
- `text`: 交互文本内容
- `valence`: 情绪效价值 (-1.0 到 1.0)
- `arousal`: 情绪唤醒度 (-1.0 到 1.0)
- `past_time`: 时间戳

## 使用示例

### 创建 NPC 并添加记忆
```bash
# 1. 初始化模型（可选，首次使用会自动初始化）
curl -X POST http://localhost:3000/api/v1/initialize

# 2. 创建 NPC
curl -X POST http://localhost:3000/api/v1/npcs \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "identity": {
        "name": "Marcus",
        "background": "A friendly shopkeeper"
      },
      "personality": {
        "valence": 0.3,
        "arousal": -0.1
      },
      "memory": {
        "decay_rate": 0.1
      }
    }
  }'

# 返回: {"success":true,"data":{"npc_id":"xxx-xxx-xxx"}}

# 3. 添加交互记忆（会自动保存到文件）
curl -X POST http://localhost:3000/api/v1/npcs/{npc_id}/evaluate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Thank you for your help!",
    "source_id": "player"
  }'
```

### 查看保存的数据
```bash
# 查看 NPC 数据目录
ls -lh target/release/npc_data/

# 查看特定 NPC 的数据
cat target/release/npc_data/{npc_id}.json
```

### 重启服务器测试持久化
```bash
# 1. 停止服务器
# Ctrl+C 或 kill

# 2. 重新启动服务器
./target/release/npc-neural-affect-matrix

# 3. 查看启动日志，应该看到：
# INFO  npc_neural_affect_matrix: ✅ Loaded N NPC memory files from disk

# 4. 验证数据已恢复
curl http://localhost:3000/api/v1/npcs/{npc_id}/memory
```

## API 端点

### 获取 NPC 记忆
```bash
GET /api/v1/npcs/{npc_id}/memory
```

### 清空 NPC 记忆
```bash
DELETE /api/v1/npcs/{npc_id}/memory
```
注意：清空后会保存空数组到文件

### 删除 NPC
```bash
DELETE /api/v1/npcs/{npc_id}
```
注意：删除 NPC 会同时删除对应的 JSON 文件

## 技术细节

### 文件操作
- **存储目录**: 自动创建在可执行文件的父目录下
- **文件权限**: 使用标准文件系统权限
- **并发安全**: 使用 Mutex 保护内存数据和文件写入

### 错误处理
- 文件读取失败时会记录警告但不会阻止启动
- 文件写入失败会返回错误给 API 调用者
- 损坏的 JSON 文件会被跳过并记录警告

### 性能考虑
- 每次记忆变化都会写文件（适合小规模数据）
- 大规模应用建议考虑批量写入或数据库方案

## 未来改进计划

- [ ] 批量保存优化（减少磁盘 I/O）
- [ ] SQLite 数据库支持（可选）
- [ ] 数据压缩选项
- [ ] 自动备份功能
- [ ] 数据导入/导出工具

## 故障排查

### 数据没有保存
1. 检查是否调用了 `/initialize` 端点初始化模型
2. 检查 `/evaluate` 请求是否返回成功
3. 查看服务器日志是否有错误信息
4. 确认文件系统权限

### 数据没有加载
1. 检查服务器启动日志
2. 确认 `npc_data/` 目录存在且有读取权限
3. 验证 JSON 文件格式是否正确

### 文件位置找不到
数据文件位于可执行文件的同级目录下的 `npc_data/` 文件夹中：
```bash
# 开发环境
D:\apps\npc-neural-affect-matrix\target\release\npc_data\

# 生产环境（根据实际部署位置）
/path/to/deployment/npc_data/
```
