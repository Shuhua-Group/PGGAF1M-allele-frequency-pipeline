Here’s a professional English translation of your README for the **PGG.AF1M Frequency Data Pipeline**:

---

# **Version: PGG.AF1M Frequency Data Pipeline**

## **1. Preprocessing**  
Before calculating allele frequencies, ensure the data has undergone **quality control (QC)** and preprocessing.  

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
   (See detailed commands in the scripts.)  

3. **Performance optimization**  
   - `vcftools` may consume high memory for large files.  

---

## **3. Processing Frequency Data**  
After generating `.frq` files using `vcftools`/`bcftools`:  
- Reformat the frequency data  
- Calculate **genotype frequencies**  
- Add metadata (sample size, dataset name)  
- Convert to the required database format  

🔹 **For large joint-called files:**  
Use Linux `awk` for efficient processing.  

---

## **4. Multi-Population/Cross-Region Analysis**  
If the dataset contains **multiple populations/provinces** (e.g., Han, Balti, Tibetan), compute frequencies separately.  

### **Example: Population ID List (`Han.txt`)**  
```
Sample1  
Sample2  
...  
```

---

## **5. Handling Non-Joint-Called GVCFs**  
If only **single-sample GVCFs** are available:  
- Extract **genotype/allele frequency** data per sample using `vcftools`  
- Merge results  

### **Pipeline 1: Genotype-Based**  
```bash
vcftools --gvcf ${sample}.gvcf --extract-FORMAT-info GT  
```

### **Pipeline 2: Allele Frequency-Based (Unphased Data)**  
(Same approach, slightly modified commands.)  

---

## **6. Troubleshooting**  
⚠️ **Windows/Linux Line Ending Issues:**  
If scripts fail after downloading via GitHub on Windows:  
- Convert line endings to Unix format:  
  ```bash
  sed -i 's/\r$//' script.sh  # Run on Linux  
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