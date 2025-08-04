#!/bin/bash
# ==============================================
# 群体频率计算流程（单VCF文件版本）
# ==============================================

module load bcftools
module load plink
module load plink2

# ==============================================
# 输入文件设置
    # 注意：samples_province_pop.txt 文件格式要求：
    # 第一列：样本ID
    # 第二列：省份信息
    # 第三列：population信息
    # 例如 WGC022072D   Xizang  Sherpa
# ==============================================
input_vcf="/home/SNP_filtered_variants.vcf.gz"  # 替换为您的单文件VCF路径
sample_info="samples_province_pop.txt"  # 样本信息文件

# ==============================================
# 1. 预处理VCF文件
# ==============================================
# 添加变异ID（格式：染色体_位置）
bcftools annotate --threads 12 --set-id +'%CHROM\_%POS' ${input_vcf} -Oz -o all_chr.updateID.vcf.gz

# 转换为PLINK二进制格式
plink --memory 12000 --threads 12 --vcf all_chr.updateID.vcf.gz --real-ref-alleles --make-bed --double-id --out all_chr

# ==============================================
# 2. 创建样本映射文件
# ==============================================
awk '{print $1, $2}' all_chr.fam > all_chr.fid_iid_mapping.txt

# ==============================================
# 3. 计算整体频率
# ==============================================
plink --bfile all_chr --freq --out all_chr_all
plink2 --bfile all_chr --geno-counts --out all_chr_all_genocounts

# ==============================================
# 4. 分层计算频率（省份→民族）
# ==============================================
# 获取所有省份列表
provinces=$(cut -f2 ${sample_info} | sort | uniq)

for province in ${provinces}; do
    echo "Processing province: ${province}"
    
    # 4.1 提取该省份样本
    grep -w "${province}" ${sample_info} | cut -f1 > tmp_province.iids
    awk 'NR==FNR {a[$2]=$1; next} $1 in a {print a[$1], $1}' all_chr.fid_iid_mapping.txt tmp_province.iids > ${province}_samples.txt
    
    # 4.2 计算该省份整体频率
    plink --bfile all_chr --keep ${province}_samples.txt --freq --out all_chr_${province}
    plink2 --bfile all_chr --keep ${province}_samples.txt --geno-counts --out all_chr_${province}_genocounts
    
    # 4.3 获取该省份下的所有民族
    pops=$(grep -w "${province}" ${sample_info} | cut -f3 | sort | uniq)
    
    for pop in ${pops}; do
        echo "  Processing population: ${pop}"
        
        # 提取该民族样本
        grep -w "${pop}" ${sample_info} | cut -f1 > tmp_pop.iids
        awk 'NR==FNR {a[$2]=$1; next} $1 in a {print a[$1], $1}' all_chr.fid_iid_mapping.txt tmp_pop.iids > ${province}_${pop}_samples.txt
        
        # 计算该民族频率
        plink --bfile all_chr --keep ${province}_${pop}_samples.txt --freq --out all_chr_${province}_${pop}
        plink2 --bfile all_chr --keep ${province}_${pop}_samples.txt --geno-counts --out all_chr_${province}_${pop}_genocounts
        
        # 清理临时文件
        rm tmp_pop.iids
    done
    
    # 清理临时文件
    rm tmp_province.iids ${province}_samples.txt
done

# ==============================================
# 5. 可选：计算特定民族的全国频率
# ==============================================
# 获取所有民族列表
pops=$(cut -f3 ${sample_info} | sort | uniq)

for pop in ${pops}; do
    echo "Processing nationwide population: ${pop}"
    
    # 提取该民族样本
    grep -w "${pop}" ${sample_info} | cut -f1 > tmp_pop.iids
    awk 'NR==FNR {a[$2]=$1; next} $1 in a {print a[$1], $1}' all_chr.fid_iid_mapping.txt tmp_pop.iids > ${pop}_samples.txt
    
    # 计算该民族全国频率
    plink --bfile all_chr --keep ${pop}_samples.txt --freq --out all_chr_nationwide_${pop}
    plink2 --bfile all_chr --keep ${pop}_samples.txt --geno-counts --out all_chr_nationwide_${pop}_genocounts
    
    # 清理临时文件
    rm tmp_pop.iids ${pop}_samples.txt
done

echo "All frequency calculations completed!"
