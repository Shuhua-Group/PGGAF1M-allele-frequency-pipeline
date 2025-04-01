Here’s a professional English translation of your README for the **PGG.AF1M Frequency Data Pipeline**:

---

# **Version: PGG.AF1M Frequency Data Pipeline**

## **1. Preprocessing**  
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
- Using only **command-line tools** (`bcftools`, `vcftools`)  

### **A. Prerequisites**  
Install the following tools:  
```bash
# Install miniconda (in user directory)  
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh  
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda  
source $HOME/miniconda/bin/activate  

# Install tools via conda  
conda install -c bioconda bcftools vcftools -y  
```  
🔹 **Workaround for firewall restrictions:**  
If `wget` is blocked, download `Miniconda3-latest-Linux-x86_64.sh` locally and upload to the Linux server via:  
```bash
scp Miniconda3-latest-Linux-x86_64.sh username@cluster:/path/to/destination  
```

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

### **Example: Population ID List (`Han.txt`)**  
```
Sample1  
Sample2  
...  
```

```bash
# Simplified Population-specific Frequency Calculation Usage:
bash pop_freq_pipeline.sh [input_VCF] [Population List] [output]
# Simply run this shell script directly, and edit the input/output paths inline using vim as required.
```

---

## **5. Handling Non-Joint-Called GVCFs**  
If only **single-sample GVCFs** are available:  
- Extract **genotype/allele frequency** data per sample using `vcftools`  
- Merge results  

### **Pipeline 1: Genotype-Based**  
```bash
# GT-based Frequency Calculation Pipeline Usage
bash gt_freq_pipeline.sh [input_VCF_directory] [output_directory]
# Simply run this shell script directly, and edit the input/output paths inline using vim as required. 
```

### **Pipeline 2: Allele Frequency-Based (Unphased Data)**  
```bash
# AF-based Frequency Calculation Pipeline Usage
bash af_freq_pipeline.sh [input_VCF_directory] [output_directory]
# Simply run this shell script directly, and edit the input/output paths inline using vim as required. 
```
---

## **6. Troubleshooting**  
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

## **7. Output Validation**  
### **A. Frequency File (`result.tsv`)**  
```bash
less result.tsv  
```  
**Example Output:**  
| chr | rs_id | pos | ref | alt | ref_freq | alt_freq | dataset | sample_size | ... |  
|-----|-------|-----|-----|-----|----------|----------|---------|-------------|-----|  
| chr1 | rs12345 | 100 | A | G | 0.75 | 0.25 | MyDataset | 100 | ... |  

### **B. Population-Specific Files**  
- `Population1.frq`  
- `Shanghai.frq`  
- `Tibet.frq`  

**Final Output:** `final_result.tsv`  

--- 

### **Key Features**  
✅ Supports **joint-called VCFs** and **single-sample GVCFs**  
✅ Handles **multi-population** stratification  
✅ Optimized for **large datasets**  

Let me know if you'd like to refine any section further! 🚀