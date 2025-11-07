# 📋 ONNX模型训练步骤指南

## 📊 模型输入输出格式

根据代码 `src/modules/emotion/predictor.rs:209-262`，当前模型规格：

### 输入格式
- `input_ids`: 形状 `[1, 512]`，类型 `int64`（tokenized文本ID）
- `attention_mask`: 形状 `[1, 512]`，类型 `int64`（注意力掩码）
- 最大文本长度：512 tokens
- Tokenizer：基于BERT的tokenizer（`tokenizer.json`）

### 输出格式
- 形状：`[1, 2]`，类型 `float32`
- `[0, 0]`：Valence（情感愉悦度，范围 -1.0 到 +1.0）
- `[0, 1]`：Arousal（情感激活度，范围 -1.0 到 +1.0）

---

## 🔧 训练步骤

### 1. 准备训练数据集

推荐使用项目提供的数据集或类似格式：
- **官方数据集**: [NPC Valence-Arousal Dataset](https://huggingface.co/datasets/Mavdol/NPC-Valence-Arousal) （70K+游戏对话）

数据格式应为：
```json
[
  {
    "text": "Thank you for saving my life!",
    "valence": 0.85,
    "arousal": 0.45
  },
  {
    "text": "How dare you attack my village!",
    "valence": -0.78,
    "arousal": 0.82
  }
]
```

### 2. 选择基础模型架构

当前项目使用的是**BERT-based架构**。推荐选项：
- **DistilBERT**: 轻量级，适合实时游戏（推荐）
- **BERT-base**: 标准选择
- **RoBERTa**: 更高精度但更大

### 3. 训练环境搭建

```bash
# 创建Python虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install torch transformers datasets onnx onnxruntime scikit-learn
```

### 4. 训练脚本示例

```python
import torch
import torch.nn as nn
from transformers import AutoModel, AutoTokenizer, Trainer, TrainingArguments
from datasets import load_dataset
import onnx

# 1. 定义模型架构
class ValenceArousalModel(nn.Module):
    def __init__(self, base_model_name="distilbert-base-uncased"):
        super().__init__()
        self.bert = AutoModel.from_pretrained(base_model_name)
        # 输出2维：[valence, arousal]
        self.regressor = nn.Linear(self.bert.config.hidden_size, 2)
        self.tanh = nn.Tanh()  # 限制输出到 [-1, 1]

    def forward(self, input_ids, attention_mask):
        outputs = self.bert(input_ids=input_ids, attention_mask=attention_mask)
        pooled = outputs.last_hidden_state[:, 0, :]  # [CLS] token
        predictions = self.regressor(pooled)
        return self.tanh(predictions)

# 2. 加载数据集
dataset = load_dataset("Mavdol/NPC-Valence-Arousal")  # 或您自己的数据
tokenizer = AutoTokenizer.from_pretrained("distilbert-base-uncased")

def preprocess(examples):
    tokens = tokenizer(
        examples["text"],
        padding="max_length",
        truncation=True,
        max_length=512
    )
    tokens["labels"] = [[ex["valence"], ex["arousal"]] for ex in examples]
    return tokens

train_dataset = dataset["train"].map(preprocess, batched=True)

# 3. 训练配置
model = ValenceArousalModel()

training_args = TrainingArguments(
    output_dir="./npc-emotion-model",
    num_train_epochs=5,
    per_device_train_batch_size=16,
    learning_rate=2e-5,
    warmup_steps=500,
    weight_decay=0.01,
    logging_dir="./logs",
    save_strategy="epoch"
)

# 4. 自定义损失函数（MSE for regression）
def compute_loss(model, inputs, return_outputs=False):
    outputs = model(**inputs)
    labels = inputs.pop("labels")
    loss = nn.MSELoss()(outputs, labels)
    return (loss, outputs) if return_outputs else loss

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    compute_loss=compute_loss
)

# 5. 开始训练
trainer.train()

# 6. 保存PyTorch模型
model.save_pretrained("./trained_model")
tokenizer.save_pretrained("./trained_model")
```

### 5. 转换为ONNX格式

```python
import torch
import onnx

# 加载训练好的模型
model = ValenceArousalModel()
model.load_state_dict(torch.load("./trained_model/pytorch_model.bin"))
model.eval()

# 准备虚拟输入（用于ONNX导出）
dummy_input_ids = torch.randint(0, 30522, (1, 512))
dummy_attention_mask = torch.ones((1, 512), dtype=torch.long)

# 导出为ONNX
torch.onnx.export(
    model,
    (dummy_input_ids, dummy_attention_mask),
    "model.onnx",
    input_names=["input_ids", "attention_mask"],
    output_names=["output"],
    dynamic_axes={
        "input_ids": {0: "batch_size"},
        "attention_mask": {0: "batch_size"}
    },
    opset_version=14
)

# 验证ONNX模型
onnx_model = onnx.load("model.onnx")
onnx.checker.check_model(onnx_model)
print("✅ ONNX模型验证成功!")
```

### 6. 测试ONNX模型

```python
import onnxruntime as ort
import numpy as np

# 加载ONNX Runtime会话
session = ort.InferenceSession("model.onnx")

# 测试输入
text = "Thank you for saving my village!"
tokens = tokenizer(text, padding="max_length", truncation=True, max_length=512, return_tensors="np")

# 推理
outputs = session.run(
    None,
    {
        "input_ids": tokens["input_ids"].astype(np.int64),
        "attention_mask": tokens["attention_mask"].astype(np.int64)
    }
)

valence, arousal = outputs[0][0]
print(f"Valence: {valence:.2f}, Arousal: {arousal:.2f}")
```

---

## 🔄 集成到项目中

训练完成后，替换项目中的模型：

### 1. 准备模型文件
- `model.onnx`（ONNX模型）
- `tokenizer.json`（HuggingFace格式）
- `config.json`（可选配置）

### 2. 放置到缓存目录
```bash
# 项目会自动在以下位置查找
target/release/npc_models_cache/NPC-Prediction-Model-v0.0.1/
├── model.onnx
├── tokenizer.json
├── config.json
└── version.txt
```

### 3. 更新版本号（可选）
修改 `src/modules/emotion/predictor.rs:71`：
```rust
const MODEL_VERSION: &'static str = "v0.0.2"; // 您的新版本
```

---

## 📈 训练优化建议

### 1. 数据增强
- 同义词替换
- 回译（back-translation）
- 添加游戏特定领域数据

### 2. 超参数调优
- Learning rate: `1e-5` 到 `5e-5`
- Batch size: `16` 或 `32`
- Epochs: `3-10`（根据数据集大小）

### 3. 评估指标
- MSE（均方误差）
- MAE（平均绝对误差）
- Pearson相关系数

### 4. 模型压缩（可选）
- 量化（INT8）：使用 `onnxruntime.quantization`
- 蒸馏（Distillation）：使用更小的学生模型

---

## 📚 相关资源

- **官方模型**: [HuggingFace Model Hub](https://huggingface.co/Mavdol/NPC-Valence-Arousal-Prediction-ONNX)
- **数据集**: [HuggingFace Datasets](https://huggingface.co/datasets/Mavdol/NPC-Valence-Arousal)
- **理论基础**: Russell's Circumplex Model of Affect
- **ONNX文档**: https://onnx.ai/
- **当前项目**: https://github.com/mavdol/npc-neural-affect-matrix

---

## 🎯 快速开始检查清单

- [ ] 准备或下载训练数据集
- [ ] 安装Python依赖（torch, transformers, onnx等）
- [ ] 选择基础模型架构（推荐DistilBERT）
- [ ] 运行训练脚本
- [ ] 转换为ONNX格式
- [ ] 验证ONNX模型输入输出
- [ ] 测试推理性能
- [ ] 集成到项目中
- [ ] 更新版本号和文档

---

## ⚠️ 注意事项

1. **内存要求**: 训练BERT类模型至少需要8GB RAM，推荐16GB+
2. **GPU推荐**: 使用CUDA加速可大幅减少训练时间
3. **数据质量**: 模型性能高度依赖训练数据的质量和多样性
4. **版本兼容**: 确保ONNX opset版本与onnxruntime版本兼容
5. **测试覆盖**: 在多种文本输入上测试模型，确保输出在[-1, 1]范围内
