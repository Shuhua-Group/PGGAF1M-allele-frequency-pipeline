#!/bin/bash
# Genotype Frequency Processing Pipeline
# 使用方法：bash genotype_freq_pipeline.sh [输入VCF] [输出目录]
#af_processing_pipeline当中的genotype仅为占位符，需要额外计算genotype frequency

# ====================== 用户配置区域 ======================
VCF_FILE=""                      # 输入VCF文件路径
OUTPUT_DIR=""                    # 输出目录路径

# ========================================================
module load plink
module load bcftools
module load vcftools

#plink验证frequency数据
# ========= 步骤 1：为没有 rsID 的 SNP 添加唯一 ID（使用 chr:pos） =========
bcftools annotate -x ID -I +'%CHROM:%POS' "$VCF_FILE" -Oz -o "$OUTPUT_DIR/updated.vcf.gz"
tabix -p vcf "$OUTPUT_DIR/updated.vcf.gz"
# ========= 步骤 2：转换为 Plink 格式（.bed/.bim/.fam） =========
plink --vcf "$OUTPUT_DIR/updated.vcf.gz" --make-bed --out "$OUTPUT_DIR/tmp_plink"
# ========= 步骤 3：计算等位基因频率（allele frequency） =========
plink --bfile "$OUTPUT_DIR/tmp_plink" --freq --out "$OUTPUT_DIR/plink_af"
# ========= 步骤 4：计算基因型频率（genotype frequency） =========
plink --bfile "$OUTPUT_DIR/tmp_plink" --hardy --out "$OUTPUT_DIR/plink_geno"

#vcftools验证frequency数据(根据扩展名选择--vcf/--gzvcf)
# 1. 计算 allele frequency
vcftools --vcf "$VCF_FILE" --freq --out "$OUTPUT_DIR/output_prefix"
