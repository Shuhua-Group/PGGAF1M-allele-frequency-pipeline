#!/bin/bash
# ==============================================
# 群体频率计算流程教学（保持原始代码格式）
# ==============================================

module load bcftools
module load plink
module load plink/2.0 

# ==============================================
# 添加vcf路径
# ==============================================
vcf_path="" 
vcf_header=""

for K in {1..22} X Y M; do
    # 1. 用bcftools添加变异ID（格式：染色体_位置）
    bcftools annotate --threads 12 --set-id +'%CHROM\_%POS' ${vcf_path}/${vcf_header}.chr${K}.vcf.gz -Oz -o chr${K}.updateID.vcf.gz

    # 2. 转换为PLINK二进制格式
    plink --memory 12000 --threads 12 --vcf chr${K}.updateID.vcf.gz --real-ref-alleles --make-bed --double-id --out chr${K}

    # 3. 添加群体信息（民族）到fam文件
    awk 'NR==FNR{a[$2]=$1; next} {print a[$2], $2, $3, $4, $5, $6}' Population.pop chr${K}.fam > tmp.fam && mv tmp.fam chr${K}.fam

    # 4. 计算民族分层的等位基因频率
    plink --memory 12000 --threads 12 --bfile chr${K} --real-ref-alleles --freq --family --out population_chr${K}

    # 4.1 计算民族分层的基因型频率
    plink --threads 12 --memory 12000 --bfile chr${K} --hardy --out genotype_population_chr${K}

    # 5. 添加群体信息（省份）到fam文件
    awk 'NR==FNR{a[$2]=$1; next} {print a[$2], $2, $3, $4, $5, $6}' Province.pop chr${K}.fam > tmp.fam && mv tmp.fam chr${K}.fam

    # 6. 计算省份分层的等位基因频率
    plink --memory 12000 --threads 12 --bfile chr${K} --real-ref-alleles --freq --family --out province_chr${K}

    # 6.1 计算省份分层的基因型频率（使用 plink2）
    plink --threads 12 --memory 12000 --bfile chr${K} --hardy --out genotype_province_chr${K}

    # ==============================================
    # 内存不足时可降低--memory参数
done






# ==============================================
# 另外，如果样本内有不同的地区和population，请使用如下脚本独立计算每个省份对应的民族频率信息
# ==============================================

    # 注意：samples_province_pop.txt 文件格式要求：
    # 第一列：样本ID
    # 第二列：省份信息
    # 第三列：population信息
    # 例如 WGC022072D   Xizang  Sherpa

module load plink

# 首先转换为PLINK格式(确认vcf文件位置)
plink --vcf /home/PGGAF1M/data/SNP_filtered_variants.vcf.gz --make-bed --out output

# 创建FID-IID映射文件(从fam文件中提取)
awk '{print $1, $2}' output.fam > fid_iid_mapping.txt

# 按省份分割
for province in $(cut -f2 samples_province_pop.txt | sort | uniq); do
    # 提取该省份样本IID
    grep -w "$province" samples_province_pop.txt | cut -f1 > ${province}.iids

    # 通过IID查找对应的FID，生成两列样本列表
    awk 'NR==FNR {a[$2]=$1; next} $1 in a {print a[$1], $1}' fid_iid_mapping.txt ${province}.iids > ${province}.samples

    # 删除临时文件
    rm ${province}.iids

    # 提取该省份数据
    plink --bfile output --keep ${province}.samples --make-bed --out ${province}

    # 在该省份内按population计算频率
    for pop in $(grep -w "$province" samples_province_pop.txt | cut -f3 | sort | uniq); do
        # 提取该population样本IID
        grep -w "$pop" samples_province_pop.txt | cut -f1 > ${province}_${pop}.iids

        # 通过IID查找对应的FID，生成两列样本列表
        awk 'NR==FNR {a[$2]=$1; next} $1 in a {print a[$1], $1}' fid_iid_mapping.txt ${province}_${pop}.iids > ${province}_${pop}.samples

        # 删除临时文件
        rm ${province}_${pop}.iids

        # 计算等位基因频率
        plink --bfile ${province} --keep ${province}_${pop}.samples --freq --out ${province}_${pop}_freq

        # 计算基因型频率
        plink --bfile ${province} --keep ${province}_${pop}.samples --hardy --out ${province}_${pop}_genocounts
    done
done


