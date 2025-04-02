#!/bin/bash
# AF-based Frequency Calculation Pipeline
# 使用方法：bash af_freq_pipeline.sh [输入VCF目录] [输出目录]

# --------------------------
# 用户配置区域（需修改）
# --------------------------
INPUT_DIR="$1"          # 输入目录（包含sample*.g.vcf.gz文件）
OUTPUT_DIR="$2"         # 输出目录
DATASET="MyDataset"     # 数据集名称
POPULATION="global"     # 群体标识
# --------------------------

module load bcftools
module load vcftools

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "AF-based Frequency Calculation Pipeline"
echo "输入目录: $INPUT_DIR"
echo "输出目录: $OUTPUT_DIR"
echo "========================================"

# 步骤1：提取所有样本的位点并集
echo "步骤1/4：提取所有样本的位点并集..."
while read vcf; do
    bcftools view -H "$vcf" | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5}'
done < <(find "$INPUT_DIR" -name "sample*.g.vcf.gz") | sort -u > "$OUTPUT_DIR/unique_positions.tsv"
echo " > 发现 $(wc -l < "$OUTPUT_DIR/unique_positions.tsv") 个唯一位点"

# 步骤2：提取每个样本的AF并匹配位点
echo "步骤2/4：提取样本AF数据..."
for vcf in "$INPUT_DIR"/sample*.g.vcf.gz; do
    sample=$(basename "$vcf" .g.vcf.gz)
    echo " > 处理样本: $sample"
    
    # 提取AF字段
    vcftools --gzvcf "$vcf" --extract-FORMAT-info AF --out "$OUTPUT_DIR/${sample}_temp"
    
    # 匹配到统一位点（缺失位点设为NA）
    awk -v samp="$sample" '
    BEGIN {OFS="\t"}
    NR==FNR {af[$1":"$2]=$5; next}
    {
        key=$1":"$2;
        if (FNR==1) print $1, $2, $3, $4, $5, samp"_AF";
        else print $1, $2, $3, $4, $5, (key in af ? af[key] : "NA")
    }' "$OUTPUT_DIR/${sample}_temp.AF.FORMAT" "$OUTPUT_DIR/unique_positions.tsv" > "$OUTPUT_DIR/${sample}_af_matched.tsv"
done

# 步骤3：合并所有样本AF数据
echo "步骤3/4：合并样本AF数据..."
# 获取样本列表
SAMPLES=($(ls "$OUTPUT_DIR"/*_af_matched.tsv | sed 's/.*\///;s/_af_matched\.tsv//'))
HEADER="CHROM\tPOS\tREF\tALT\tID"

for samp in "${SAMPLES[@]}"; do
    HEADER+="\t${samp}_AF"
done

echo -e "$HEADER" > "$OUTPUT_DIR/merged_af.tsv"

# 合并数据（跳过每个文件的头行）
paste "$OUTPUT_DIR/unique_positions.tsv" "$OUTPUT_DIR"/*_af_matched.tsv | \
awk 'BEGIN {OFS="\t"} NR>1 {print $1, $2, $3, $4, $5, $6, $12, $18}' >> "$OUTPUT_DIR/merged_af.tsv"

# 步骤4：计算频率
echo "步骤4/4：计算等位基因和基因型频率..."
awk -v dataset="$DATASET" -v population="$POPULATION" '
BEGIN {
    OFS="\t";
    print "CHROM", "rs_id", "POS", "REF", "ALT", "ref_allele_freq", "alt_allele_freq",
          "dataset", "sample_size", "homozygous_reference", "homozygous_reference_freq",
          "heterozygous", "heterozygous_freq", "homozygous_alternative", "homozygous_alternative_freq",
          "variant", "population";
}
NR > 1 {
    chrom = $1;
    pos = $2;
    ref = $3;
    alt = $4;
    rsid = ($5 == "." ? "NA" : $5);
    
    total_samples = 0;
    sum_af = 0;
    
    # 统计有效 AF 和样本数
    for (i = 6; i <= NF; i++) {
        if ($i != "NA") {
            sum_af += $i;
            total_samples++;
        }
    }
    
    if (total_samples == 0) next;
    
    # 计算等位基因频率
    alt_freq = sum_af / total_samples;
    ref_freq = 1 - alt_freq;
    
    # 计算基因型频率（Hardy-Weinberg 平衡）
    hom_ref_freq = ref_freq * ref_freq;       # AA 频率
    het_freq = 2 * ref_freq * alt_freq;       # AC 频率
    hom_alt_freq = alt_freq * alt_freq;       # CC 频率
    
    # 生成基因型字符串
    hom_ref_gt = ref ref;       # 如 AA
    het_gt = ref alt;            # 如 AC
    hom_alt_gt = alt alt;        # 如 CC
    
    # 生成variant ID
    variant = chrom ":" pos "_" ref "_" alt;
    
    # 输出结果
    print chrom, rsid, pos, ref, alt, ref_freq, alt_freq,
          dataset, total_samples,
          hom_ref_gt, hom_ref_freq,
          het_gt, het_freq,
          hom_alt_gt, hom_alt_freq,
          variant, population;
}
' "$OUTPUT_DIR/merged_af.tsv" > "$OUTPUT_DIR/final_af_frequencies.tsv"

echo "分析完成！结果文件: $OUTPUT_DIR/final_af_frequencies.tsv"
echo "前3行预览:"
head -n 3 "$OUTPUT_DIR/final_af_frequencies.tsv"
