# 📋 后端API需求清单 - OCR自动记账确认功能

## ✅ 已实现的API（无需修改）

根据API文档检查，以下API已经实现且满足前端需求：

### 1. OCR自动解析API ✅
**端点**: `POST /api/ocr/parse-auto`

**功能**: 智能解析OCR文本，根据置信度自动决定是否创建支出记录

**请求**:
```json
{
  "text": "麦当劳 25.80元 支付宝 2024-01-15",
  "autoCreateThreshold": 0.8
}
```

**响应**:
```json
{
  "success": true,
  "message": "解析成功，需要用户确认",
  "data": {
    "autoCreated": false,          // ← 关键字段：是否自动创建
    "recordId": "uuid",             // ← 关键字段：用于后续确认
    "expense": null,                // 未自动创建时为null
    "ocrRecord": {
      "id": "uuid",
      "originalText": "...",
      "parsedData": { /* 解析结果 */ },
      "confidenceScore": 0.65,
      "status": "success"
    },
    "parsedData": {
      "merchant": {
        "name": "麦当劳",
        "confidence": 0.95
      },
      "amount": {
        "value": 25.80,
        "confidence": 0.98
      },
      "date": {
        "value": "2024-01-15",
        "confidence": 0.90
      },
      "category": {
        "name": "餐饮",
        "confidence": 0.85
      },
      "paymentMethod": {
        "type": "支付宝",
        "confidence": 0.92
      }
    },
    "confidence": 0.65,
    "suggestions": {
      "shouldAutoCreate": false,
      "needsReview": true,
      "reason": "置信度 0.65 低于阈值 0.8"
    }
  }
}
```

**状态**: ✅ **已实现，完全满足需求**

---

### 2. OCR确认并创建支出API ✅
**端点**: `POST /api/ocr/confirm/:recordId`

**功能**: 用户确认后，使用修正的数据创建支出记录

**路径参数**:
- `recordId`: 从 `/api/ocr/parse-auto` 返回的记录ID

**请求**:
```json
{
  "amount": 25.80,
  "category": "餐饮",
  "description": "麦当劳午餐",
  "date": "2024-01-15T12:30:00.000Z",
  "location": "北京市朝阳区",
  "paymentMethod": "支付宝",
  "tags": ["午餐"]
}
```

**必填字段**:
- ✅ `amount`: 金额（必填）
- ✅ `category`: 类别（必填）
- ✅ `description`: 描述/商户（必填）

**可选字段**:
- `date`: 日期（默认当前时间）
- `location`: 地点（可选）
- `paymentMethod`: 支付方式（默认 "cash"）
- `tags`: 标签数组（默认 []）

**响应**:
```json
{
  "success": true,
  "message": "支出记录创建成功",
  "data": {
    "expense": {
      "id": "expense-uuid",
      "amount": 25.80,
      "category": "餐饮",
      "description": "麦当劳午餐",
      "date": "2024-01-15",
      "paymentMethod": "支付宝",
      "location": "北京市朝阳区",
      "tags": ["午餐"],
      "userId": "user-uuid",
      "createdAt": "2024-01-15T10:35:00Z",
      "updatedAt": "2024-01-15T10:35:00Z"
    },
    "ocrRecord": {
      "id": "ocr-uuid",
      "status": "confirmed",
      "expenseId": "expense-uuid"
    }
  }
}
```

**状态**: ✅ **已实现，完全满足需求**

---

## 🔍 需要确认的事项

### 1. API响应格式验证

请后端确认 `POST /api/ocr/parse-auto` 的响应是否**完全**按照以下格式返回：

**关键字段**:
```json
{
  "data": {
    "autoCreated": boolean,      // 是否自动创建（必须）
    "recordId": string | null,   // 记录ID（autoCreated=false时必须）
    "parsedData": {              // 解析数据（必须）
      "amount": { 
        "value": number,
        "confidence": number 
      },
      "merchant": { 
        "name": string,
        "confidence": number 
      },
      "date": { 
        "value": string,
        "confidence": number 
      },
      "category": { 
        "name": string,
        "confidence": number 
      },
      "paymentMethod": { 
        "type": string,
        "confidence": number 
      },
      "originalText": string     // 原始文本（可选但建议）
    },
    "confidence": number,        // 整体置信度（必须）
    "suggestions": {             // 建议（必须）
      "shouldAutoCreate": boolean,
      "needsReview": boolean,
      "reason": string
    },
    "ocrRecord": {               // OCR记录（可选）
      "id": string,
      "originalText": string,
      "confidenceScore": number,
      "status": string
    }
  }
}
```

**重要**:
1. ⚠️ `parsedData` 中是否有 `originalText` 字段？
   - 如果**没有**，原始文本在 `ocrRecord.originalText` 中
   - 前端已按 `ocrRecord.originalText` 实现

2. ⚠️ 字段命名确认：
   - `paymentMethod.type` 还是 `paymentMethod.value`？
   - 前端当前使用 `paymentMethod.type`

---

### 2. 错误处理

请确认以下错误场景的响应格式：

#### 场景1: recordId不存在或已过期
```bash
POST /api/ocr/confirm/invalid-or-expired-id
```

**期望响应**:
```json
{
  "success": false,
  "message": "OCR记录不存在或已过期",
  "error": "RECORD_NOT_FOUND"
}
```
**状态码**: 404

#### 场景2: 必填字段缺失
```bash
POST /api/ocr/confirm/:recordId
Body: { "category": "餐饮" }  // 缺少 amount 和 description
```

**期望响应**:
```json
{
  "success": false,
  "message": "缺少必填字段",
  "error": "VALIDATION_ERROR",
  "details": {
    "amount": "金额不能为空",
    "description": "描述不能为空"
  }
}
```
**状态码**: 400

#### 场景3: 记录已被确认
```bash
POST /api/ocr/confirm/:recordId  // recordId 对应的记录 status 已经是 "confirmed"
```

**期望响应**:
```json
{
  "success": false,
  "message": "该记录已被确认，不能重复确认",
  "error": "RECORD_ALREADY_CONFIRMED"
}
```
**状态码**: 409

---

## ⚠️ 可选优化建议（非必需）

### 1. 支持部分字段更新

**当前行为**: 前端发送所有字段（包括null值）

**建议优化**: 允许只发送需要修正的字段

**示例**:
```json
// 当前（前端发送所有字段）
{
  "amount": 25.80,
  "category": "餐饮",
  "description": "麦当劳",
  "date": "2024-01-15T12:30:00.000Z",
  "location": null,              // 即使为null也发送
  "paymentMethod": "支付宝",
  "tags": null                   // 即使为null也发送
}

// 优化后（只发送修正的字段）
{
  "amount": 25.80,
  "description": "麦当劳午餐"    // 只修正了描述
}
```

**好处**:
- 减少请求体大小
- 语义更清晰（明确哪些字段被修正）
- 后端可以保留原始解析数据

**优先级**: 低（可选）

---

### 2. 返回更详细的创建信息

**当前响应**:
```json
{
  "data": {
    "expense": { /* 支出记录 */ },
    "ocrRecord": { /* OCR记录 */ }
  }
}
```

**建议增强**:
```json
{
  "data": {
    "expense": { /* 支出记录 */ },
    "ocrRecord": { 
      "id": "uuid",
      "status": "confirmed",
      "expenseId": "expense-uuid",
      "corrections": {                    // 🆕 记录用户修正了哪些字段
        "amount": { 
          "original": 25.00, 
          "corrected": 25.80 
        },
        "description": { 
          "original": "麦当劳", 
          "corrected": "麦当劳午餐" 
        }
      }
    }
  }
}
```

**好处**:
- 便于统计哪些字段容易识别错误
- 帮助改进OCR识别算法
- 提供审计轨迹

**优先级**: 低（可选）

---

## 📊 API调用流程确认

### 完整流程（低置信度场景）

```
[用户] 点击背后3次
    ↓
[前端] 截图 + OCR识别文本
    ↓
[前端] POST /api/ocr/parse-auto
    Body: { "text": "识别的文本", "autoCreateThreshold": 0.8 }
    ↓
[后端] 解析文本，计算置信度
    ↓
[后端] 置信度 < 0.8，返回:
    {
      "autoCreated": false,
      "recordId": "abc-123",
      "parsedData": { ... },
      "confidence": 0.65,
      "suggestions": { "needsReview": true }
    }
    ↓
[前端] 检测 autoCreated = false 且 recordId 存在
    ↓
[前端] 自动弹出确认界面
    显示: ⚠️ 识别置信度：65%
    预填充: 金额、商户、类别等
    ↓
[用户] 检查数据，修正错误，点击"确认"
    ↓
[前端] POST /api/ocr/confirm/abc-123
    Body: {
      "amount": 25.80,
      "category": "餐饮",
      "description": "麦当劳午餐",
      "date": "2024-01-15T12:30:00.000Z",
      "paymentMethod": "支付宝",
      "tags": ["午餐"]
    }
    ↓
[后端] 验证 recordId，创建支出记录
    ↓
[后端] 返回:
    {
      "success": true,
      "data": {
        "expense": { ... },
        "ocrRecord": { 
          "status": "confirmed",
          "expenseId": "expense-uuid"
        }
      }
    }
    ↓
[前端] 显示成功提示，关闭确认界面
```

**请确认**: 这个流程是否与后端实现一致？

---

## 🎯 前端已完成的工作

### 1. 数据模型
- ✅ `AutoExpenseData`: 包含 `autoCreated`, `recordId`, `needsConfirmation`
- ✅ `ExpenseCorrections`: 用户修正的数据模型
- ✅ `OCRAutoData`: 后端响应数据模型

### 2. 服务层
- ✅ `AutoExpenseService.processAutoExpense()`: 调用 `/api/ocr/parse-auto`
- ✅ `AutoExpenseService.confirmAndCreateExpense()`: 调用 `/api/ocr/confirm/:recordId`

### 3. ViewModel层
- ✅ `AutoRecognitionViewModel.handleAutoExpenseSuccess()`: 区分自动创建和需要确认
- ✅ `AutoRecognitionViewModel.confirmAndCreateExpense()`: 确认并创建

### 4. UI层
- ✅ `AutoRecognitionView`: 自动弹出确认界面
- ✅ `ConfirmExpenseView`: 完整的确认和编辑界面
  - 置信度提示（颜色编码）
  - 所有字段可编辑
  - 数据验证
  - 原始文本显示

---

## ✅ 总结

### 必需的（已实现）
1. ✅ `POST /api/ocr/parse-auto` - 已实现
2. ✅ `POST /api/ocr/confirm/:recordId` - 已实现

### 需要确认的
1. ⚠️ `parsedData` 字段结构（特别是 `originalText` 位置）
2. ⚠️ `paymentMethod.type` vs `paymentMethod.value` 命名
3. ⚠️ 错误响应格式（404, 400, 409 场景）

### 可选优化的
1. 💡 支持部分字段更新（非必需）
2. 💡 返回修正信息用于统计（非必需）

---

## 📞 后续沟通要点

与后端沟通时，请重点确认：

1. **响应格式**: 
   - 原始OCR文本在哪个字段？`parsedData.originalText` 还是 `ocrRecord.originalText`？
   - 支付方式字段是 `paymentMethod.type` 还是 `paymentMethod.value`？

2. **错误处理**:
   - recordId不存在时返回什么？
   - 重复确认时返回什么？
   - 必填字段缺失时的详细错误信息？

3. **API稳定性**:
   - 这两个API是否已部署到生产环境？
   - 是否会有breaking changes？

如果以上API按照文档实现，**前端无需任何额外的后端支持**，功能已经完全可用！🎉

