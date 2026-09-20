## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |
| `fastq_2` | Full path to FastQ file reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |

> [!NOTE]
> fastq_1 and fastq_2 must be full path. Relative path are not allowed.

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir /path/to/genomeDir \
 --well_sample ./well_sample.tsv \
 -profile bulk_rna,docker
```

### Bulk RNA-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `fasta` | string | null | Path to genome fasta file. |
| `gtf` | string | null | Path to genome GTF file. |
| `genomeDir` | string | null | Path to genome directory. |
| `genome_name` | string | genomeDir | Genome name for mkref. |
| `mt_gene_list` | string | null | Path to mitochondrial gene list file. Used to mark MT genes in the GTF during mkref. |
| `keep_attributes` | string | null | GTF attributes to keep when running mkgtf. |
| `well_sample` | string | null | **Required**. TSV file containing well numbers (1st column) and corresponding sample names (2nd column). Used for bulk RNA demultiplexing. |
| `split_fastq` | boolean | false | Split FASTQ file according to well barcodes. Appends UMI to read name with separator `:`. |
| `split_bam` | boolean | false | Split BAM file according to well barcodes. |
| `soloFeatures` | string | `GeneFull_Ex50pAS Gene` | STARsolo features to quantify. |
| `outFilterMatchNmin` | integer | 50 | STAR alignment filter: minimum matching nucleotides per read. |
| `soloCellFilter` | string | `EmptyDrops_CR ...` | STARsolo cell filter parameters. |
| `outSAMtype` | string | `BAM SortedByCoordinate` | STAR SAM output type. |
| `soloCBmatchWLtype` | string | `EditDist_2` | STARsolo barcode-whitelist matching type. |
| `limitBAMsortRAM` | integer | 32000000000 | Maximum RAM (bytes) for STAR BAM sorting. |
| `adapter_3p` | string | `AAAAAAAAAAAA` | 3' adapter sequence to trim. |
| `report_soloFeature` | string | `GeneFull_Ex50pAS` | STARsolo feature to include in the report. |
| `STAR_param` | string | "" | Additional STAR parameters. |

> [!NOTE]
> `well_sample` is required for the bulk RNA workflow. It must be a tab-separated file with two columns: well numbers and the corresponding sample names.

Example `well_sample.tsv`:

```tsv
1	control1
2	control2
3	treatment1
4	treatment2
```

### Create genome index

Since indexing is an expensive process in time and resources you should ensure that it is only done once, by retaining the indices generated from each batch of reference files.

When running the data of a certain species for the first time, you can provide `fasta`, `gtf` and `genome_name` instead of `genomeDir`:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --fasta /genome/human.GRCh38.110.fasta \
 --gtf /genome/human.GRCh38.110.gtf \
 --genome_name human.GRCh38.110 \
 --well_sample ./well_sample.tsv \
 -profile bulk_rna,docker
```

The STAR index files will be saved in `{outdir}/mkref/{genome_name}/`.

When running data from the same genome later, you can provide `genomeDir` to skip the indexing:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir /workspaces/test/outs/mkref/human.GRCh38.110/ \
 --well_sample ./well_sample.tsv \
 -profile bulk_rna,docker
```

### Bulk RNA workflow

The bulk RNA workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version (chemistry) from R1 reads.
- **starsolo**: Read mapping and gene expression quantification using STARsolo. Barcodes are converted to sample names based on the `well_sample` file.
- **split**: Split FASTQ / BAM file according to well barcodes. Optionally split FASTQ when `--split_fastq` is set, and split BAM when `--split_bam` is set.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
