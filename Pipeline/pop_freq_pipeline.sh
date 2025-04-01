#!/bin/bash
# Simplified Population-specific Frequency Calculation
# 使用方法：bash pop_freq_pipeline.sh [输入VCF] [population列表目录] [输出前缀]

# ====================== 用户配置 ======================
VCF_FILE="$1"                      # 输入VCF文件路径
POP_DIR="$2"                       # population样本列表目录
OUT_PREFIX="$3"                    # 输出文件前缀
# =====================================================

echo "========================================"
echo "Population-specific Frequency Calculation"
echo "输入VCF: $VCF_FILE"
echo "Population样本目录: $POP_DIR"
echo "输出前缀: $OUT_PREFIX"
echo "========================================"

# 遍历population列表文件
for pop_file in "$POP_DIR"/*.txt; do
    # 从文件名提取population名称
    pop_name=$(basename "$pop_file" .txt)
    
    echo "处理population: $pop_name"
    
    # 运行vcftools计算频率
    vcftools --gzvcf "$VCF_FILE" \
             --keep "$pop_file" \
             --freq \
             --out "${OUT_PREFIX}_${pop_name}"
    
    # 检查是否成功生成.frq文件
    if [ ! -f "${OUT_PREFIX}_${pop_name}.frq" ]; then
        echo "警告: 未能生成 ${pop_name} 的频率文件"
    else
        echo " > 已生成: ${OUT_PREFIX}_${pop_name}.frq"
    fi
done

echo "所有population处理完成！"
