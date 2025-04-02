#!/bin/bash
# GT-based Frequency Calculation Pipeline
# 使用方法：bash gt_freq_pipeline.sh [输入VCF目录] [输出目录]

# --------------------------
# 用户配置区域（需修改）
# --------------------------
INPUT_DIR="$1"          # 输入目录（包含sample*.g.vcf.gz文件）
OUTPUT_DIR="$2"         # 输出目录
DATASET="MyDataset"     # 数据集名称
SAMPLE_SIZE=100         # 样本量（会自动计算覆盖）
POPULATION="global"     # 群体标识
# --------------------------

module load bcftools
module load vcftools

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

echo "========================================"
echo "GT-based Frequency Calculation Pipeline"
echo "输入目录: $INPUT_DIR"
echo "输出目录: $OUTPUT_DIR"
echo "========================================"

# 步骤1：提取所有样本的位点并集
echo "步骤1/4：提取所有样本的位点并集..."
find "$INPUT_DIR" -name "sample*.g.vcf.gz" | while read vcf; do
    bcftools view -H "$vcf" | awk '{print $1"\t"$2"\t"$3"\t"$4"\t"$5}'
done | sort -u > "$OUTPUT_DIR/unique_positions.tsv"

echo " > 发现 $(wc -l < "$OUTPUT_DIR/unique_positions.tsv") 个唯一位点"

# 步骤2：提取每个样本的GT并匹配位点
echo "步骤2/4：提取样本GT数据..."
for vcf in "$INPUT_DIR"/sample*.g.vcf.gz; do
    sample=$(basename "$vcf" .g.vcf.gz)
    echo " > 处理样本: $sample"
    
    # 提取GT字段
    vcftools --gzvcf "$vcf" --extract-FORMAT-info GT --out "$OUTPUT_DIR/${sample}_temp"
    
    # 匹配到统一位点（缺失位点设为./.）
    awk -v samp="$sample" '
    BEGIN {OFS="\t"}
    NR==FNR {gt[$1":"$2]=$5; next}
    {
        key=$1":"$2;
        if (FNR==1) print $1, $2, $3, $4, $5, samp"_GT";
        else print $1, $2, $3, $4, $5, (key in gt ? gt[key] : "./.")
    }' "$OUTPUT_DIR/${sample}_temp.GT.FORMAT" "$OUTPUT_DIR/unique_positions.tsv" > "$OUTPUT_DIR/${sample}_gt_matched.tsv"
done

# 步骤3：合并所有样本GT数据
echo "步骤3/4：合并样本GT数据..."
# 获取样本列表
SAMPLES=($(ls "$OUTPUT_DIR"/*_gt_matched.tsv | sed 's/.*\///;s/_gt_matched\.tsv//'))
HEADER="CHROM\tPOS\tREF\tALT\tID"

for samp in "${SAMPLES[@]}"; do
    HEADER+="\t${samp}_GT"
done

echo -e "$HEADER" > "$OUTPUT_DIR/merged_gt.tsv"

# 合并数据（跳过每个文件的头行）
paste "$OUTPUT_DIR/unique_positions.tsv" "$OUTPUT_DIR"/*_gt_matched.tsv | \
awk 'BEGIN {OFS="\t"} NR>1 {print $1, $2, $3, $4, $5, $6, $12, $18}' >> "$OUTPUT_DIR/merged_gt.tsv"

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
    ref_alleles = 0;
    alt_alleles = 0;
    hom_ref = 0;
    het = 0;
    hom_alt = 0;
    
    # 统计基因型（跳过前5列）
    for (i = 6; i <= NF; i++) {
        gt = $i;
        if (gt == "0/0") {
            hom_ref++;
            ref_alleles += 2;
            total_samples++;
        } else if (gt == "0/1" || gt == "1/0") {
            het++;
            ref_alleles++;
            alt_alleles++;
            total_samples++;
        } else if (gt == "1/1") {
            hom_alt++;
            alt_alleles += 2;
            total_samples++;
        }
    }
    
    if (total_samples == 0) next;
    
    # 计算频率
    total_alleles = ref_alleles + alt_alleles;
    ref_freq = ref_alleles / total_alleles;
    alt_freq = alt_alleles / total_alleles;
    
    hom_ref_freq = hom_ref / total_samples;
    het_freq = het / total_samples;
    hom_alt_freq = hom_alt / total_samples;
    
    # 生成基因型字符串
    hom_ref_gt = ref ref;
    het_gt = ref alt;
    hom_alt_gt = alt alt;
    
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
' "$OUTPUT_DIR/merged_gt.tsv" > "$OUTPUT_DIR/final_gt_frequencies.tsv"

echo "分析完成！结果文件: $OUTPUT_DIR/final_gt_frequencies.tsv"
echo "前3行预览:"
head -n 3 "$OUTPUT_DIR/final_gt_frequencies.tsv"
