## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with at least 4 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |
| `fastq_2` | Full path to FastQ file reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |
| `spatial` | Full path to spatial directory, which can be generated using [AtlasXbrowser](https://github.com/singleron-RD/AtlasXbrowser). |

> [!NOTE]
> fastq_1, fastq_2, and spatial must be full path. Relative path are not allowed.

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir /path/to/genomeDir \
 -profile space,docker
```

If you have miRNA reference data, you can provide the `mirna_genomeDir` parameter.
```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir /path/to/genomeDir \
 --mirna_genomeDir /path/to/mirna_genomeDir \
 -profile space,docker
```

Alternatively, you can build the genome and miRNA indices on the fly by providing fasta/gtf files:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --fasta ./genome.fa \
 --gtf ./genome.gtf \
 --mirna_fasta ./mirna.fa \
 --mirna_gtf ./mirna.gtf \
 --genome_name genome \
 --mirna_name mirna \
 -profile space,docker
```

### Space-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fasta` | string | null | Genome FASTA file. Required if `genomeDir` is not provided. |
| `gtf` | string | null | Genome GTF file. Required if `genomeDir` is not provided. |
| `genomeDir` | string | null | Pre-built genome index directory. If not provided, the pipeline will build it from `fasta` and `gtf`. |
| `genome_name` | string | genomeDir | Name for the genome index built by MKREF. |
| `mirna_fasta` | string | null | miRNA FASTA file. Required if `mirna_genomeDir` is not provided. |
| `mirna_gtf` | string | null | miRNA GTF file. Required if `mirna_genomeDir` is not provided. |
| `mirna_genomeDir` | string | null | Pre-built miRNA index directory. If not provided, the pipeline will build it from `mirna_fasta` and `mirna_gtf`. |
| `mirna_name` | string | mirnaDir | Name for the miRNA index built by MKREF. |
| `min_genes` | integer | 1 | Minimum number of genes per cell for analysis. |
| `soloFeatures` | string | GeneFull_Ex50pAS Gene | Features to be quantified by STARsolo. |
| `outFilterMatchNmin` | integer | 30 | Minimum alignment match length for STAR. |
| `soloCellFilter` | string | None | Cell filtering method. |
| `outSAMtype` | string | BAM SortedByCoordinate | Output SAM/BAM type. |
| `soloCBmatchWLtype` | string | EditDist_2 | Cell barcode matching method. |
| `limitBAMsortRAM` | integer | 32000000000 | Maximum memory for BAM sorting (bytes). |
| `adapter_3p` | string | AAAAAAAAAAAA | 3' adapter sequence. |
| `report_soloFeature` | string | GeneFull_Ex50pAS | Feature for STARsolo report. |
| `STAR_param` | string | null | Additional STAR parameters. |

### Create genome index

The genomeDir for spatial data differs from the one used for regular single-cell RNA-seq. Since spatial analysis needs to include some short non-coding RNAs, the GTF file used is unfiltered.

**Human:**
```bash
mkdir hs_ensembl_110
cd hs_ensembl_110

wget https://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
wget https://ftp.ensembl.org/pub/release-110/gtf/homo_sapiens/Homo_sapiens.GRCh38.110.gtf.gz

gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
gunzip Homo_sapiens.GRCh38.110.gtf.gz

celescope rna mkref \
 --genome_name Homo_sapiens_ensembl_110 \
 --fasta Homo_sapiens.GRCh38.dna.primary_assembly.fa \
 --gtf Homo_sapiens.GRCh38.110.gtf
```

**Mouse:**
```bash
mkdir mmu_ensembl_110
cd mmu_ensembl_110

wget https://ftp.ensembl.org/pub/release-110/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz
wget https://ftp.ensembl.org/pub/release-110/gtf/mus_musculus/Mus_musculus.GRCm39.110.gtf.gz

gunzip Mus_musculus.GRCm39.dna.primary_assembly.fa.gz
gunzip Mus_musculus.GRCm39.110.gtf.gz

celescope rna mkref \
 --genome_name Mus_musculus_ensembl_110 \
 --fasta Mus_musculus.GRCm39.dna.primary_assembly.fa \
 --gtf Mus_musculus.GRCm39.110.gtf
```

### Space workflow

The space workflow consists of the following steps:

- **sample**: Parse FASTQ files and generate sample metrics.
- **starsolo**: Demultiplexing and alignment using STARsolo.
- **mirna** (optional): Align reads to miRNA reference and count.
- **analysis**: Calculate the marker gene of each cluster.

### Main Output

In the outs folder, there is a `filtered_feature_bc_matrix.h5` file and a `spatial` directory. This format is consistent with [10X Visium output](https://www.10xgenomics.com/support/software/space-ranger/latest/analysis/outputs/spatial-outputs) and can be directly loaded into Seurat.

**Seurat v5:**
```R
library(Seurat)
obj <- Load10X_Spatial(data.dir = "./outs")
obj@meta.data$orig.ident = 'sample1'
```

**Seurat v4:**
```bash
mv outs/spatial/tissue_positions.parquet outs/spatial/parquet.bak
mv outs/spatial/positions_list.csv outs/spatial/tissue_positions_list.csv
```

```R
library(Seurat)
obj <- Load10X_Spatial(data.dir = "./outs")
obj@meta.data$orig.ident = 'sample1'
```

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
