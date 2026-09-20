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
| `match_dir` | Full path to match celescope scRNA-Seq directory. Required for CITE-seq assay. |

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
 --barcode_fasta ./TotalSeqA_mouse_barcode.fasta \
 --fq_pattern L25C15 \
 -profile citeseq,docker
```

### CITE-seq-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `barcode_fasta` | string | null | Required. Tag barcode fasta file. |
| `fq_pattern` | string | `L25C15` | R2 read pattern. The number after the letter represents the number of bases. L: linker, C: tag barcode . |
| `linker_fasta` | string | null | Optional. Linker fasta file. If provided, it will check the mismatches between linker sequence in R2 reads with all linker sequence in linker_fasta. |



### Barcode fasta file format

The barcode fasta file contains barcode sequences:

```
>Ms.CD4
AACAAGACCCTTGAG
>Ms.CD8a
TACCCGTAATAGCGT
>Ms.CD366
ATTGGCACTCAGATG
```

### Linker fasta file format

The linker fasta file contains linker sequences:

```
>linker
CCTTGGCACCCGAGAATTCCA
```

### CITE-seq workflow

The CITE-seq workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **barcode**: Demultiplex barcodes from R1 reads.
- **mapping_tag**: Map R2 reads to tag barcode sequences and count reads per tag.
- **count_cite**: Count tag UMI matrix.
- **analysis_cite**: Generate visualization plots.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
