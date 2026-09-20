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
| `match_dir` | Full path to match celescope scRNA-Seq directory. Required for sweet-seq assay. |

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
 --barcode_fasta ./sweet_tag_barcode.fasta \
 --linker_fasta ./sweet_tag_linker.fasta \
 --fq_pattern L23C15 \
 -profile sweetseq,docker
```

### Sweet-seq-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `barcode_fasta` | string | null | Tag barcode fasta file. |
| `linker_fasta` | string | null | Optional. Linker fasta file. |
| `fq_pattern` | string | null | R2 read pattern. Sweet-seq default is L23C15. |

> [!NOTE]
> You can find the barcode fasta file under `celescope/data/sweetseq`.

### Sweet-seq workflow

Before running sweet-seq, you need to run scRNA-Seq data with CeleScope first.

The sweet-seq workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **barcode**: Demultiplex barcodes.
- **mapping_tag**: Align R2 reads to the tag barcode fasta.
- **count_tag**: Assign tag to each cell barcode and summarize.
- **analysis_tag**: Combine scRNA-Seq clustering information with tag assignment.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
