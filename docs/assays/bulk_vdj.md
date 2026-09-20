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
 --ref_path /genome/vdj/human/human_TR \
 --species human \
 --vdj_type TCR \
 -profile bulk_vdj,docker
```

Alternatively, provide a directory of IMGT fasta files via `--vdj_ref_dir` and the pipeline will build the reference index automatically with the `mkref` step:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --vdj_ref_dir /genome/vdj/human \
 --species human \
 --vdj_type TCR \
 -profile bulk_vdj,docker
```

> [!NOTE]
> Either `--ref_path` (pre-built index) or `--vdj_ref_dir` (IMGT fasta directory) must be provided.

### Bulk VDJ-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ref_path` | string | null | Path to an existing VDJ reference index directory (e.g. `human_TR`). Either `ref_path` or `vdj_ref_dir` is required. |
| `vdj_ref_dir` | string | null | Directory containing IMGT fasta files; the pipeline builds the reference index via `mkref`. Either `ref_path` or `vdj_ref_dir` is required. |
| `species` | string | human | Species: human or mouse. |
| `vdj_type` | string | TCR | Receptor type: TCR or BCR. |
| `aux_file` | string | null | Aux file for igblastn. Required for customized species (not human or mouse). |

### Create VDJ reference

See [VDJ documentation](vdj.md) for reference creation instructions.

### Bulk VDJ workflow

The Bulk VDJ workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **barcode**: Demultiplex barcodes form R1 reads.
- **consensus**: Consensus reads of the same (barcode, UMI) combinations into one read.
- **mapping_vdj**: Align consensus sequences to IMGT (http://www.imgt.org/) database sequences using IgBLAST.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
