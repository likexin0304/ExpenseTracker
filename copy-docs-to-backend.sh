#!/bin/bash

# 📋 将API文档复制到后端项目的脚本
# 使用方法: ./copy-docs-to-backend.sh /path/to/backend-project

# 检查参数
if [ -z "$1" ]; then
    echo "❌ 错误: 请提供后端项目路径"
    echo "📖 使用方法: ./copy-docs-to-backend.sh /path/to/backend-project"
    exit 1
fi

BACKEND_PROJECT_PATH="$1"
DOCS_DIR="${BACKEND_PROJECT_PATH}/docs"

# 检查后端项目是否存在
if [ ! -d "$BACKEND_PROJECT_PATH" ]; then
    echo "❌ 错误: 后端项目路径不存在: $BACKEND_PROJECT_PATH"
    exit 1
fi

# 创建docs目录（如果不存在）
if [ ! -d "$DOCS_DIR" ]; then
    echo "📁 创建docs目录: $DOCS_DIR"
    mkdir -p "$DOCS_DIR"
fi

# 复制文档
echo "📄 复制文档到后端项目..."
cp "后端API需求清单.md" "$DOCS_DIR/"

# 检查是否成功
if [ $? -eq 0 ]; then
    echo "✅ 文档复制成功！"
    echo "📍 文档位置: ${DOCS_DIR}/后端API需求清单.md"
    
    # 创建README（如果不存在）
    README_PATH="${DOCS_DIR}/README.md"
    if [ ! -f "$README_PATH" ]; then
        echo "📝 创建docs/README.md索引文件..."
        cat > "$README_PATH" << 'EOF'
# 📚 API文档

## OCR自动记账功能

### 前端需求文档
- [后端API需求清单](./后端API需求清单.md) - OCR确认功能的完整API需求

### 文档说明
- **版本**: v1.0.0
- **更新日期**: 2025-01-17
- **维护**: iOS前端团队

### 需要确认的事项
请后端团队查看"后端API需求清单.md"中标注⚠️的部分：
1. API响应格式验证
2. 错误处理场景
3. 字段命名规范

### 相关链接
- [完整API文档](../API-Backend.md)（如果存在）
EOF
        echo "✅ 已创建索引文件: $README_PATH"
    fi
    
    echo ""
    echo "🎉 完成！后续步骤："
    echo "1. cd $BACKEND_PROJECT_PATH"
    echo "2. 查看文档: cat docs/后端API需求清单.md"
    echo "3. 将docs目录提交到Git: git add docs/ && git commit -m '添加前端API需求文档'"
else
    echo "❌ 文档复制失败"
    exit 1
fi

