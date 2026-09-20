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
 --probe_fasta ./probe.fasta \
 --primer_fasta ./primer.fasta \
 -profile probe,docker
```

### Probe-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `probe_fasta` | string | null | Probe fasta file. |
| `primer_fasta` | string | null | Primer fasta file. |
| `max_mismatch` | integer | 2 | Maximum mismatch allowed in probe matching. |

### Probe workflow

The probe workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **barcode**: Demultiplex barcodes and identify probes using the probe/primer fasta files.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
