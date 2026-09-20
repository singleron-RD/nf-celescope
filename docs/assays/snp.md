## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 4 columns, and a header row as shown in the examples below. 

```bash
--input '[path to samplesheet file]'
```

| Column      | Description   |
| ----------- | -------------- |
| `sample`    | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1`   | Full path to FastQ file reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".  |
| `fastq_2`   | Full path to FastQ file reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".   |
| `match_dir` | Full path to match celescope scRNA-Seq directory.  |

> [!NOTE]
> fastq_1, fastq_2, and match_dir must be full path. Relative path are not allowed.

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis. 

### Create `samplesheet.csv` using helper script

When you have many samples, manually creating `samplesheet.csv` can be tedious and error-prone. There is a python script [manifest.py](https://github.com/singleron-RD/sccore/blob/main/sccore/cli/manifest.py) that can help you create a `samplesheet.csv` file.

```
pip install sccore
manifest -m manifest.csv -f /workspaces/scrna_test_data/GEXSCOPE-V3
```

Recursively search the specified folders for fastq files and (optional) matched barcode files.

`-m --manifest` Path to the manifest CSV file containing mappings between fastq file prefixes and sample names. An example `manifest.csv` can be found in the [test data repository](https://github.com/singleron-RD/scrna_test_data/tree/master/GEXSCOPE-V2-human).

`-f --folders` Comma-separated paths to folders to search for fastq files. 

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir path_to_genomeDir \
 -profile snp,docker
```

### SNP-specific parameters

The snp assay includes several parameters for controlling the analysis:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `panel` | string | null | Target gene panel. Options: `blood_1`, `CHIP`, `lung_1` |
| `gene_list` | string | null | Path to gene list file (one gene per line). |
| `bed` | string | null | Path to BED file defining target regions |
| `database` | string | `GRCh38.mane.1.0.ensembl` | SnpEff database. Common choices are `GRCh38.mane.1.0.ensembl`(human) and `GRCm38.99`(mouse). |

> [!NOTE]
> At least one of these three parameters - `panel`, `gene_list`, or `bed` - must be provided. For their logic and impact priority levels, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope/blob/master/doc/assay/multi_snp.md).

### Create genome index

Since indexing is an expensive process in time and resources you should ensure that it is only done once, by retaining the indices generated from each batch of reference files.

When running the data of a certain species for the first time, you can provide `fasta`, `gtf` and `genome_name` instead of `genomeDir`. For example,

```yaml
fasta: "/genome/human.GRCh38.110.fasta"
gtf: "/genome//human.GRCh38.110.gtf"
genome_name: "human.GRCh38.110"
```

The STAR index files will be saved in `{outdir}/mkref/{genome_name}/`.
When running data from the same genome later, you can provide `genomeDir` to skip the indexing:

```yaml
genomeDir: "/workspaces/test/outs/mkref/human.GRCh38.110/"
```

### SNP workflow

The snp workflow consists of the following steps:

- **sample**: Detect GEXSCOPE kit version
- **starsolo**: Mapping & Demultiplexing
- **target_metrics**: Filtering & Enrichment
- **variant_calling**: SNP Identification
- **filter_snp**: Quality Control
- **analysis_snp**: Annotation & Visualization

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
