#!/bin/bash
# AF-based Frequency Processing Pipeline
# 使用方法：bash af_processing_pipeline.sh [输入VCF] [输出目录]

# ====================== 用户配置区域 ======================
VCF_FILE="/home/shenzhuoyang/PGHAdatabase/SNP_filtered_variants.vcf.gz"                      # 输入VCF文件路径
OUTPUT_DIR="/home/shenzhuoyang/PGHAdatabase"                    # 输出目录路径
DATASET="MyDataset"                # 数据集名称
POPULATION="global1"                # 群体标识,更改成你样本的族群
# ========================================================
module load vcftools
module load bcftools
module load plink/2.0

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
# 步骤1.1：使用 plink2 计算实际基因型频率
echo "步骤1.1：使用 plink2.0 计算基因型频率..."
plink --vcf "$VCF_FILE" --geno-counts --out "$OUTPUT_DIR/genotype_counts"

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

# 步骤4：处理频率和基因型数据
echo "步骤4/4：处理频率数据并合并基因型频率..."

awk -v dataset="'$DATASET'" -v population="'$POPULATION'" '
BEGIN {
    OFS = "\t";
    print "chr", "rs_id", "pos", "ref", "alt", "ref_allele_freq", "alt_allele_freq",
          "dataset", "sample_size", "homozygous_reference", "homozygous_reference_freq",
          "heterozygous", "heterozygous_freq", "homozygous_alternative",
          "homozygous_alternative_freq", "variant", "population";
}
FNR==NR && $1 !~ /^#/ {
    key = $1 "_" $2;
    ref_allele = $4;
    alt_allele = $5;
    ref_count = $6;
    het_count = $7;
    alt_count = $8;
    total = ref_count + het_count + alt_count;
    if (total > 0) {
        gcount_map[key] = ref_count "\t" het_count "\t" alt_count "\t" total "\t" ref_allele "\t" alt_allele;
    }
    next;
}
FNR>1 {
    key = $1 "_" $2;
    rsid = $3;
    if (key in gcount_map) {
        split(gcount_map[key], gc, "\t");
        ref_gt = gc[5] gc[5];
        het_gt = gc[5] gc[6];
        alt_gt = gc[6] gc[6];
        hom_ref = gc[1];
        het = gc[2];
        hom_alt = gc[3];
        total = gc[4];
        ref_freq = hom_ref / total;
        alt_freq = hom_alt / total;
        variant = $1 ":" $2 "-" gc[5] "-" gc[6];
        print $1, rsid, $2, gc[5], gc[6], ref_freq, alt_freq, dataset, total,
              ref_gt, hom_ref / total,
              het_gt, het / total,
              alt_gt, hom_alt / total,
              variant, population;
    }
}
' "$OUTPUT_DIR/genotype_counts.gcount" "$OUTPUT_DIR/rsid_map.tsv" > "$OUTPUT_DIR/final_result.tsv"

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
