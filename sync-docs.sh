#!/bin/bash

# 🔄 文档同步脚本
# 将ExpenseTracker的文档同步到后端项目

# ==================== 配置 ====================
SOURCE_PROJECT="/Users/kexin.li/Desktop/ExpenseTracker"
TARGET_PROJECT="/Users/kexin.li/Desktop/Backend-Project"  # 修改为实际路径

# 要同步的文件列表
FILES=(
    "后端API需求清单.md"
    "API-Backend.md"
)

# ==================== 脚本逻辑 ====================

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查源项目是否存在
if [ ! -d "$SOURCE_PROJECT" ]; then
    echo -e "${RED}❌ 错误: 源项目不存在: $SOURCE_PROJECT${NC}"
    exit 1
fi

# 检查目标项目是否存在
if [ ! -d "$TARGET_PROJECT" ]; then
    echo -e "${RED}❌ 错误: 目标项目不存在: $TARGET_PROJECT${NC}"
    echo -e "${YELLOW}💡 提示: 请修改脚本中的 TARGET_PROJECT 路径${NC}"
    exit 1
fi

# 创建目标docs目录
TARGET_DOCS="${TARGET_PROJECT}/docs"
mkdir -p "$TARGET_DOCS"

echo -e "${GREEN}🔄 开始同步文档...${NC}"
echo "📂 源目录: $SOURCE_PROJECT"
echo "📂 目标目录: $TARGET_DOCS"
echo ""

# 同步每个文件
SYNCED=0
FAILED=0

for file in "${FILES[@]}"; do
    SOURCE_FILE="${SOURCE_PROJECT}/${file}"
    TARGET_FILE="${TARGET_DOCS}/${file}"
    
    if [ ! -f "$SOURCE_FILE" ]; then
        echo -e "${YELLOW}⚠️  跳过: ${file} (文件不存在)${NC}"
        continue
    fi
    
    # 检查文件是否有变化
    if [ -f "$TARGET_FILE" ]; then
        if cmp -s "$SOURCE_FILE" "$TARGET_FILE"; then
            echo -e "✓ 无变化: ${file}"
            continue
        fi
    fi
    
    # 复制文件
    if cp "$SOURCE_FILE" "$TARGET_FILE"; then
        echo -e "${GREEN}✅ 已同步: ${file}${NC}"
        SYNCED=$((SYNCED + 1))
    else
        echo -e "${RED}❌ 失败: ${file}${NC}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo -e "${GREEN}🎉 同步完成！${NC}"
echo "📊 统计: 成功 $SYNCED 个, 失败 $FAILED 个"

# 如果在Git仓库中，显示Git状态
if [ -d "${TARGET_PROJECT}/.git" ]; then
    echo ""
    echo -e "${YELLOW}📝 Git状态:${NC}"
    cd "$TARGET_PROJECT"
    git status --short docs/
    
    echo ""
    echo -e "${YELLOW}💡 提示: 如需提交更新，运行:${NC}"
    echo "   cd $TARGET_PROJECT"
    echo "   git add docs/"
    echo "   git commit -m '更新前端API文档'"
    echo "   git push"
fi

