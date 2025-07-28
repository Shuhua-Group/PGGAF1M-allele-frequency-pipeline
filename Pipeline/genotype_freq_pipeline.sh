#!/bin/bash
# Genotype Frequency Processing Pipeline
# 使用方法：bash genotype_freq_pipeline.sh [输入VCF] [输出目录]
#af_processing_pipeline当中的genotype仅为占位符，需要额外计算genotype frequency

# ====================== 用户配置区域 ======================
VCF_FILE=""                      # 输入VCF文件路径
OUTPUT_DIR=""                    # 输出目录路径

# ========================================================
module load plink
module load vcftools

#plink验证frequency数据
# 1. 转换为 plink 格式（bed/bim/fam）
plink --vcf "$VCF_FILE" --make-bed --out "$OUTPUT_DIR/tmp_plink"

# 2. 计算 allele frequency
plink --bfile "$OUTPUT_DIR/tmp_plink" --freq --out "$OUTPUT_DIR/plink_af"

# 3. 计算 genotype frequency
plink --bfile "$OUTPUT_DIR/tmp_plink" --hardy --out "$OUTPUT_DIR/plink_geno"


#vcftools验证frequency数据(根据扩展名选择--vcf/--gzvcf)
# 1. 计算 allele frequency
vcftools --vcf "$VCF_FILE" --freq --out "$OUTPUT_DIR/output_prefix"

# 2. 计算 genotype frequency
vcftools --vcf "$VCF_FILE" --counts --out "$OUTPUT_DIR/output_geno"
