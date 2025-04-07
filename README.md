Here’s a professional English translation of your README for the **PGG.AF1M Frequency Data Pipeline**:

---

# **Version: PGG.AF1M Frequency Data Pipeline**

## **1. Preprocessing** 
Perform joint calling and VQSR filtering using GATK. 
Before calculating allele frequencies, ensure the data has undergone **quality control (QC)** and preprocessing.  

```bash
# Quality Control
bcftools view -f PASS -m 2 -M 2 -v snps NGS2144.jointcalling.VQSR.variants.vcf.gz |bgzip -@ 16 -c > NGS2144.jointcalling.VQSR.variants.PASS.biallelic.SNPs.vcf.gz 
tabix -p vcf NGS2144.jointcalling.VQSR.variants.PASS.biallelic.SNPs.vcf.gz
```

1.Prepare Working Directory
```bash
# Create project directory and navigate into it
mkdir PGG_allele_frequency_pipeline
cd PGG_allele_frequency_pipeline
```
2.Prepare Input Files
Place the following files in their respective directories:
Input VCF file (gzip-compressed format) → Save to /PGG_allele_frequency_pipeline/input/

⚠️ **Note:**  
Most downstream population genetic analyses use **biallelic SNPs** after QC. If your data is already filtered, skip this step.  

---

## **2. Calculating Allele Frequencies**  
This pipeline guides you through:  
- Extracting genomic regions from VCF files  
- Computing allele frequencies for different populations  
- Using only **command-line tools** (`bcftools`, `vcftools`,`plink`)  

### **A. Prerequisites**  
Here's how to install bcftools, vcftools, and PLINK for bioinformatics analysis:

### **1. bcftools Installation**
**Recommended method (via conda):**
```bash
conda install -c bioconda bcftools
```

**Alternative methods:**
```bash
# Ubuntu/Debian
sudo apt-get install bcftools

# CentOS/RHEL
sudo yum install bcftools

# From source
wget https://github.com/samtools/bcftools/releases/download/1.17/bcftools-1.17.tar.bz2
tar -xjf bcftools-1.17.tar.bz2
cd bcftools-1.17
make
sudo make install
```

---

### **2. vcftools Installation**
**Recommended method (via conda):**
```bash
conda install -c bioconda vcftools
```

**Alternative methods:**
```bash
# Ubuntu/Debian
sudo apt-get install vcftools

# From source
wget https://github.com/vcftools/vcftools/releases/download/v0.1.16/vcftools-0.1.16.tar.gz
tar -xzf vcftools-0.1.16.tar.gz
cd vcftools-0.1.16
./configure
make
sudo make install
```

---

### **3. PLINK Installation**
**Recommended method (via conda):**
```bash
conda install -c bioconda plink
```

**Alternative methods:**
```bash
# Ubuntu/Debian
sudo apt-get install plink

# Mac (Homebrew)
brew install plink

# Direct download (Linux/Mac)
wget http://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20231017.zip  # Linux
unzip plink_linux_x86_64_20231017.zip
chmod +x plink
sudo mv plink /usr/local/bin/

# PLINK 2 (newer version)
wget https://s3.amazonaws.com/plink2-assets/plink2_linux_avx2_20231017.zip
unzip plink2_linux_avx2_20231017.zip
```

---

### **4. Verify Installations**
```bash
bcftools --version
vcftools --version
plink --version
conda create -n genomics bcftools vcftools plink -c bioconda
conda activate genomics
```

---

### **B. Pipeline Steps**  
1. **Prepare input files**  
   - Place the **gzipped VCF file** in `input/`  

2. **Compute allele frequencies**  
```bash
# Calculating Allele Frequencies Using vcftools
vcftools --vcf your_file.vcf --freq --out output_frequency
``` 

3. **Performance optimization**  
   - `vcftools` may consume high memory for large files.  
```bash
# Compress VCF file first
bgzip your_file.vcf
tabix -p vcf your_file.vcf.gz

# Then run using compressed file
vcftools --gzvcf your_file.vcf.gz --freq --out output_frequency

# For extremely large files:
# Process by Chromosome
for chr in {1..22} X Y; do
  vcftools --vcf your_file.vcf --chr $chr --freq --out output_chr${chr}
done
```
---

## **3. Processing Frequency Data**  
After generating `.frq` files using `vcftools`/`bcftools`:  
- Reformat the frequency data  
- Calculate **genotype frequencies**  
- Add metadata (sample size, dataset name)  
- Convert to the required database format  

🔹 **For large joint-called files:**  
Use Linux `awk` for efficient processing.  
```bash
# AF-based Frequency Processing Pipeline Usage: 
bash af_processing_pipeline.sh [input_VCF] [output_directory]

# Simply run this shell script directly, and edit the input/output paths inline using vim as required.
```
---

## **4. Multi-Population/Cross-Region Analysis**  
If the dataset contains **multiple populations/provinces** (e.g., Han, Balti, Tibetan), compute frequencies separately.  

### **Example: Population ID List (`Population.pop`)**  
```
Han	HG00123
Han	HG00124
Han	HG00125
Han	HG00126
...  
```

### **Example: Province ID List (`Province.pop`)**  
```
Shanghai	HG00123
Shanghai	HG00124
Beijing	HG00125
Xizang	HG00126
...  
```

```bash
# Simplified Population-specific Frequency Calculation Usage:
bash pop_freq_pipeline.sh
# Simply run this shell script directly, and edit the input/output paths inline using vim as required.
```

---


## **5. Troubleshooting**  
⚠️ **Windows/Linux Line Ending Issues:**  
If scripts fail after downloading via GitHub on Windows:  
- Convert line endings to Unix format:  
  ```bash
      vim pipeline.sh
      #Switch the shell panel
      :set ff=unix
      :wq
  ```

---

## **6. Output Validation**  
### **A. Frequency File (`result.tsv`)**  
```bash
less result.tsv  
```  
**Example Output:**  
| chr | rs_id | pos | ref | alt | ref_freq | alt_freq | dataset | sample_size | ... |  
|-----|-------|-----|-----|-----|----------|----------|---------|-------------|-----|  
| chr1 | rs12345 | 100 | A | G | 0.75 | 0.25 | MyDataset | 100 | ... |  

### **The output files generated by PLINK (output prefix):**  
- `.fam/.bam/.bed/.bim `  
- `.frq`   


--- 