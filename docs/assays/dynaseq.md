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
| `background_snp` | Optional. Full path to background SNP file. Multiple files can be provided, separated by whitespace. |
| `is_control` | Optional. `Boolean`. Whether the sample is a control. Default: `false`. |

> [!NOTE]
> fastq_1 and fastq_2 must be full path. Relative path are not allowed.

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
 -profile dynaseq,docker
```

### Dynaseq-specific parameters

The dynaseq assay includes several parameters for controlling the analysis:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `basequalilty` | integer | 20 | Base quality threshold for variant calling |
| `snp_threshold` | number | 0.5 | SNP frequency threshold for SNP filtering |
| `snp_min_depth` | integer | 10 | Minimum depth for SNP calling |
| `all_type_plot` | boolean | false | Plot subsititution rate for all conversion type |

Example with dynaseq-specific parameters:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir path_to_genomeDir \
 --basequalilty 20 \
 --snp_threshold 0.5 \
 --snp_min_depth 10 \
 --all_type_plot true \
 -profile dynaseq,docker
```

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

### Dynaseq workflow

The dynaseq workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **starsolo**: Demultiplexing and alignment using STARsolo
- **analysis**: Calculate the marker gene of each cluster.
- **conversion**: Get conversion for each read and add tags.
- **substitution**: Computes the overall conversion rates in reads.
- **replacement**: Quantify unlabeled and labeled RNA. (Labeled samples only)

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
