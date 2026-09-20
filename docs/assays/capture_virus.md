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
| `match_dir` | Full path to match celescope scRNA-Seq directory. Required for capture virus assay. |

> [!NOTE]
> fastq_1, fastq_2, and match_dir must be full path. Relative path are not allowed.

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --virus_genomeDir /path/to/virus_genomeDir \
 --not_consensus \
 -profile capture_virus,docker
```

Alternatively, you can build the virus genome index on the fly by providing a fasta file:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --fasta ./virus_genome.fasta \
 --genome_name virus_reference \
 -profile capture_virus,docker
```

### Capture Virus-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `virus_genomeDir` | string | null | Pre-built virus genome index directory. If not provided, the pipeline will build it from `fasta`. |
| `fasta` | string | null | Virus genome FASTA file. Required if `virus_genomeDir` is not provided. |
| `genome_name` | string | genomeDir | Name for the virus genome index built by MKREF. |
| `gtf` | string | null | GTF file for featureCounts. |
| `minimum_length` | integer | 20 | Minimum length of reads after trimming for cutadapt. |
| `nextseq_trim` | integer | 20 | NextSeq trim for cutadapt. |
| `overlap` | integer | 10 | Overlap for cutadapt. |
| `cutadapt_param` | string |  | Additional cutadapt parameters. |
| `skip_cutadapt` | boolean | false | Skip the cutadapt step. |
| `threshold` | number | 0.5 | Valid base threshold for consensus. |
| `not_consensus` | boolean | false | Skip the consensus step. |
| `min_consensus_read` | integer | 2 | Minimum number of reads to support a base. |
| `outFilterMatchNmin` | integer | 50 | Minimum alignment match length for STAR. |
| `out_unmapped` | boolean | false | Output unmapped reads. |
| `STAR_param` | string |  | Additional STAR parameters. |
| `outFilterMultimapNmax` | integer | 1 | Maximum number of loci a read can map to. |
| `starMem` | integer | 30 | Maximum memory that STAR can use (GB). |
| `min_query_length` | integer | null | Minimum query length for count_virus. |
| `not_correct_UMI` | boolean | false | Do not perform UMI correction. |
| `read_threshold_method` | string | otsu | Method to find read threshold: auto, otsu, or hard. |
| `read_hard_threshold` | integer | null | User provided read threshold. |
| `umi_threshold_method` | string | otsu | Method to find UMI threshold: auto, otsu, or hard. |
| `umi_hard_threshold` | integer | null | User provided UMI threshold. |
| `auto_coef` | integer | 3 | Threshold coefficient for auto method. |
| `otsu_log_base` | number | 10 | Log base for Otsu's method. |
| `featureCounts_param` | string |  | Additional featureCounts parameters for featureCounts step. |

### Create virus genome reference

```bash
celescope capture_virus mkref \
 --genome_name virus_reference \
 --fasta virus_genome.fasta
```

### Capture Virus workflow

The capture virus workflow consists of the following steps:

- **sample**: Parse FASTQ files and generate sample metrics.
- **barcode**: Demultiplex barcodes and filter invalid R1 reads.
- **cutadapt**: Trim adapters in R2 reads.
- **consensus**: Consensus reads of the same (barcode, UMI) combinations into one read.
- **star_virus**: Map reads to the viral genome using STAR.
- **count_virus**: Count UMIs and reads mapped to the viral genome.
- **filter_virus**: Correct UMI errors and filter background UMIs.
- **analysis_virus**: Analyze virus UMI counts and generate plots.
- **featureCounts**: Count reads per gene using featureCounts.
- **count**: Generate final count matrix.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
