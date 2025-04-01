#!/bin/bash
# AF-based Frequency Processing Pipeline
# 使用方法：bash af_processing_pipeline.sh [输入VCF] [输出目录]

# ====================== 用户配置区域 ======================
VCF_FILE="/home/shenzhuoyang/PGHAdatabase/SNP_filtered_variants.vcf.gz"                      # 输入VCF文件路径
OUTPUT_DIR="/home/shenzhuoyang/PGHAdatabase"                    # 输出目录路径
DATASET="MyDataset"                # 数据集名称
POPULATION="global1"                # 群体标识
# ========================================================

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "AF-based Frequency Processing Pipeline"
echo "输入文件: $VCF_FILE"
echo "输出目录: $OUTPUT_DIR"
echo "========================================"

# 步骤1：计算等位基因频率
echo "步骤1/4：计算等位基因频率..."
if [[ "$VCF_FILE" == *.gz ]]; then
    vcftools --gzvcf "$VCF_FILE" --freq  --out "$OUTPUT_DIR/output_frequency"
else
    vcftools --vcf "$VCF_FILE" --freq --out "$OUTPUT_DIR/output_frequency"
fi

# 检查.frq文件是否生成成功
if [ ! -s "$OUTPUT_DIR/output_frequency.frq" ]; then
    echo "错误：未能生成.frq文件，请检查VCF文件格式！"
    exit 1
fi

# 步骤2：创建rsID映射文件
echo "步骤2/4：创建rsID映射文件..."
if [[ "$VCF_FILE" == *.gz ]]; then
    zcat "$VCF_FILE" | awk 'BEGIN{OFS="\t"} !/^#/ && $3 ~ /^rs/ {print $1,$2,$3}' > "$OUTPUT_DIR/rsid_map.tsv"
else
    awk 'BEGIN{OFS="\t"} !/^#/ && $3 ~ /^rs/ {print $1,$2,$3}' "$VCF_FILE" > "$OUTPUT_DIR/rsid_map.tsv"
fi

# 检查rsID文件是否生成成功
if [ ! -s "$OUTPUT_DIR/rsid_map.tsv" ]; then
    echo "警告：未能从VCF文件中提取rsID，将使用位置作为标识"
    # 创建基于位置的ID映射
    if [[ "$VCF_FILE" == *.gz ]]; then
        zcat "$VCF_FILE" | awk 'BEGIN{OFS="\t"} !/^#/ {print $1,$2,$1":"$2}' > "$OUTPUT_DIR/rsid_map.tsv"
    else
        awk 'BEGIN{OFS="\t"} !/^#/ {print $1,$2,$1":"$2}' "$VCF_FILE" > "$OUTPUT_DIR/rsid_map.tsv"
    fi
fi

# 步骤3：计算样本量（从.frq文件获取）
echo "步骤3/4：计算样本量..."
SAMPLE_SIZE=$(awk 'NR==2 {split($5,a,":"); print a[1]*2}' "$OUTPUT_DIR/output_frequency.frq")
echo " > 检测到样本量: $SAMPLE_SIZE"

# 步骤4：处理频率数据并生成最终结果
echo "步骤4/4：处理频率数据..."
awk -v dataset="$DATASET" -v sample_size="$SAMPLE_SIZE" -v population="$POPULATION" '
BEGIN {
    OFS = "\t";
    # 打印表头
    print "chr", "rs_id", "pos", "ref", "alt", "ref_allele_freq", "alt_allele_freq",
          "dataset", "sample_size", "homozygous_reference", "homozygous_reference_freq",
          "heterozygous", "heterozygous_freq", "homozygous_alternative",
          "homozygous_alternative_freq", "variant", "population";
}
# 处理.frq文件（NR==FNR表示第一个文件）
NR==FNR && FNR>1 {  
    # 解析vcftools生成的.frq格式（CHROM POS N_ALLELES N_CHR AL1:FREQ AL2:FREQ）
    split($5, ref, ":");
    split($6, alt, ":");
    
    # 建立坐标到频率的映射
    key = $1 SUBSEP $2;
    pos_map[key] = $0;
    ref_map[key] = ref[1];
    alt_map[key] = alt[1];
    freq_map[key] = ref[2] "\t" alt[2];
    next;
}
# 处理rsID映射文件（第二个文件）
{
    # 建立坐标到rsID的映射
    rsid_map[$1,$2] = $3;
}
END {
    # 遍历所有检测到的位点
    for (key in pos_map) {
        split(key, arr, SUBSEP);
        chrom = arr[1];
        pos = arr[2];
        
        # 获取rsID（若无则标记为.）
        rsid = (key in rsid_map) ? rsid_map[key] : ".";
        
        # 解析等位基因频率
        split(freq_map[key], freqs, "\t");
        ref_freq = freqs[1];
        alt_freq = freqs[2];
        
        # 计算基因型频率（Hardy-Weinberg平衡假设）
        hom_ref = ref_freq * ref_freq;
        het = 2 * ref_freq * alt_freq;
        hom_alt = alt_freq * alt_freq;
        
        # 生成基因型字符串
        hom_ref_gt = ref_map[key] ref_map[key];
        het_gt = ref_map[key] alt_map[key];
        hom_alt_gt = alt_map[key] alt_map[key];
        
        # 生成variant ID
        variant = chrom ":" pos "-" ref_map[key] "-" alt_map[key];
        
        # 输出结果
        print chrom, rsid, pos, ref_map[key], alt_map[key], ref_freq, alt_freq,
              dataset, sample_size,
              hom_ref_gt, hom_ref,
              het_gt, het,
              hom_alt_gt, hom_alt,
              variant, population;
    }
}' "$OUTPUT_DIR/output_frequency.frq" "$OUTPUT_DIR/rsid_map.tsv" > "$OUTPUT_DIR/final_result.tsv"

# 检查输出文件
if [ -s "$OUTPUT_DIR/final_result.tsv" ]; then
    echo "分析完成！结果文件: $OUTPUT_DIR/final_result.tsv"
    echo "========================================"
    echo "前3行结果预览:"
    head -n 3 "$OUTPUT_DIR/final_result.tsv"
    echo "========================================"
    echo "统计信息:"
    echo "处理的总位点数: $(wc -l < "$OUTPUT_DIR/final_result.tsv")"
    echo "有rsID的位点数: $(awk 'NR>1 && $2 != "." {count++} END{print count+0}' "$OUTPUT_DIR/final_result.tsv")"
    echo "平均参考等位基因频率: $(awk 'NR>1 {sum+=$6} END{print sum/(NR-1)}' "$OUTPUT_DIR/final_result.tsv")"
else
    echo "错误：未能生成结果文件！"
    exit 1
fi
