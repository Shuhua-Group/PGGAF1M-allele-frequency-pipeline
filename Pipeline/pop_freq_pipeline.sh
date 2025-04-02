#!/bin/bash
# ==============================================
# 群体频率计算流程教学（保持原始代码格式）
# ==============================================

module load bcftools
module load plink

# 1. 用bcftools添加变异ID（格式：染色体_位置）
# 参数说明：
# --threads 12    : 使用12线程
# --set-id        : 设置ID格式为"染色体_位置"
# -Oz            : 输出压缩vcf
bcftools annotate --threads 12 --set-id +'%CHROM\_%POS' ${vcf_path}/${vcf_header}.chr${K}.vcf.gz -Oz -o chr${K}}.updateID.vcf.gz

# 2. 转换为PLINK二进制格式
# --memory 12000  : 分配12GB内存
# --vcf          : 输入vcf文件
# --real-ref-alleles : 保持参考等位基因
# --make-bed      : 生成bed/bim/fam三件套
plink --memory 12000 --threads 12 --vcf chr${K}.updateID.vcf.gz --real-ref-alleles -make-bed --double-id --out chr${K}

# 3. 添加群体信息到fam文件
# 注意：your.id.pop文件格式要求：
# 第一列：群体ID（如Han）
# 第二列：样本ID
# 其他列：忽略
awk 'NR==FNR{a[$2]=$1; next} {print a[$2], $2, $3, $4,$5, $6}' Population.pop chr${K}.fam > tmp.fam && mv tmp.fam chr${K}.fam

# 4. 计算群体分层频率
# --bfile         : 输入PLINK二进制文件
# --freq          : 计算等位基因频率
# --family        : 按fam文件中的FID分组计算
plink --memory 12000 --threads 12 --bfile chr${K} --real-ref-alleles --freq --family --out population_chr${K}

# 5. 添加群体信息到fam文件
# 注意：your.id.pop文件格式要求：
# 第一列：群体ID（如Han）
# 第二列：样本ID
# 其他列：忽略
awk 'NR==FNR{a[$2]=$1; next} {print a[$2], $2, $3, $4,$5, $6}' Province.pop chr${K}.fam > tmp.fam && mv tmp.fam chr${K}.fam

# 6. 计算群体分层频率
# --bfile         : 输入PLINK二进制文件
# --freq          : 计算等位基因频率
# --family        : 按fam文件中的FID分组计算
plink --memory 12000 --threads 12 --bfile chr${K} --real-ref-alleles --freq --family --out province_chr${K}


# ==============================================
# 内存不足时可降低--memory参数
