#!/bin/bash

# 🔍 监控文档变化并自动同步到后端项目
# 使用方法: ./watch-and-sync.sh /path/to/backend-project

# ==================== 配置 ====================
BACKEND_PROJECT="${1:-/Users/kexin.li/Desktop/Backend-Project}"
SOURCE_FILE="后端API需求清单.md"
WATCH_INTERVAL=2  # 检查间隔（秒）

# ==================== 颜色 ====================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ==================== 脚本逻辑 ====================

echo -e "${BLUE}👀 开始监控文档变化...${NC}"
echo "📄 监控文件: $SOURCE_FILE"
echo "🎯 目标项目: $BACKEND_PROJECT"
echo "⏰ 检查间隔: ${WATCH_INTERVAL}秒"
echo ""
echo -e "${YELLOW}💡 提示: 按 Ctrl+C 停止监控${NC}"
echo ""

# 检查目标项目
if [ ! -d "$BACKEND_PROJECT" ]; then
    echo -e "${RED}❌ 错误: 目标项目不存在: $BACKEND_PROJECT${NC}"
    exit 1
fi

# 创建目标docs目录
TARGET_DOCS="${BACKEND_PROJECT}/docs"
mkdir -p "$TARGET_DOCS"

# 记录上次的文件修改时间
LAST_MODIFIED=0

while true; do
    # 获取当前文件修改时间
    if [ -f "$SOURCE_FILE" ]; then
        CURRENT_MODIFIED=$(stat -f %m "$SOURCE_FILE" 2>/dev/null || stat -c %Y "$SOURCE_FILE" 2>/dev/null)
        
        # 如果文件有更新
        if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ]; then
            if [ "$LAST_MODIFIED" != "0" ]; then
                echo -e "${GREEN}🔄 检测到文件变化，开始同步...${NC}"
                
                # 复制文件
                if cp "$SOURCE_FILE" "${TARGET_DOCS}/${SOURCE_FILE}"; then
                    echo -e "${GREEN}✅ 同步成功！${NC}"
                    echo "📍 目标位置: ${TARGET_DOCS}/${SOURCE_FILE}"
                    echo "⏰ 时间: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo ""
                else
                    echo -e "${RED}❌ 同步失败${NC}"
                fi
            else
                echo -e "${BLUE}📝 初始状态已记录${NC}"
            fi
            
            LAST_MODIFIED=$CURRENT_MODIFIED
        fi
    fi
    
    # 等待下次检查
    sleep $WATCH_INTERVAL
done

