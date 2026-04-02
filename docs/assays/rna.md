## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row as shown in the examples below. An example `samplesheet.csv` can be found in the [test data repository](https://github.com/singleron-RD/nf-celescope_test_data/tree/master/GEXSCOPE-V2-human).

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

### Create `samplesheet.csv` using helper script

When you have many samples, manually creating `samplesheet.csv` can be tedious and error-prone. There is a python script [manifest.py](https://github.com/singleron-RD/sccore/blob/main/sccore/cli/manifest.py) that can help you create a `samplesheet.csv` file.

```
pip install sccore
manifest -m manifest.csv -f /workspaces/scrna_test_data/GEXSCOPE-V2
```

Recursively search the specified folders for fastq files and (optional) matched barcode files.

`-m --manifest` Path to the manifest CSV file containing mappings between fastq file prefixes and sample names. An example `manifest.csv` can be found in the [test data repository](https://github.com/singleron-RD/scrna_test_data/tree/master/GEXSCOPE-V2-human).

`-f --folders` Comma-separated paths to folders to search for fastq files. If `--match` is used, all `barcode.tsv.gz` files with sample name in the full path will also be searched.

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run singleron-RD/scrna \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --genomeDir path_to_genomeDir \
 -profile docker
```

### Create genome index

Since indexing is an expensive process in time and resources you should ensure that it is only done once, by retaining the indices generated from each batch of reference files.

When running the data of a certain species for the first time, you can provide `fasta`, `gtf` and `genome_name` instead of `genomeDir`. For example,

```yaml
fasta: "/genome/human.GRCh38.110.fasta"
gtf: "/genome//human.GRCh38.110.gtf"
genome_name: "human.GRCh38.110"
```

The STAR index files will be saved in `{outdir}/star_index/{genome_name}/`.
When running data from the same genome later, you can provide `genomeDir` to skip the indexing:

```yaml
genomeDir: "/workspaces/test/outs/mkref/human.GRCh38.110/"
```

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).

