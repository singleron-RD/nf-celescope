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
| `match_dir` | Full path to match celescope scRNA-Seq directory. Required for path-seq assay. |

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
 --genomeDir /path/to/genomeDir \
 --filter_bwa_image ./mm10.fasta.img \
 --kmer_file ./mm10.bfi \
 --microbe_bwa_image ./pathseq_microbe.fa.img \
 --microbe_dict ./pathseq_microbe.dict \
 --microbe_taxonomy_file ./pathseq_taxonomy.db \
 -profile pathseq,docker
```

Alternatively, you can build the genome and microbe indices on the fly by providing fasta/gtf files:

```bash
nextflow run singleron-RD/nf-celescope \
 --input ./samplesheet.csv \
 --outdir ./outs \
 --fasta ./mm10.fa \
 --gtf ./mm10.gtf \
 --genome_name mm10 \
 --microbe_fasta ./pathseq_microbe.fa \
 --microbe_name microbe \
 --microbe_taxonomy_file ./pathseq_taxonomy.db \
 -profile pathseq,docker
```

### Path-seq-specific parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `genomeDir` | string | null | Pre-built host genome index directory. |
| `filter_bwa_image` | string | null | Pre-built host BWA image file. If not provided, the pipeline will build it from `fasta`. |
| `kmer_file` | string | null | Pre-built host k-mer bloom filter file. If not provided, the pipeline will build it from `fasta`. |
| `microbe_bwa_image` | string | null | Pre-built microbe BWA image file. If not provided, the pipeline will build it from `microbe_fasta`. |
| `microbe_dict` | string | null | Pre-built microbe dictionary file. If not provided, the pipeline will build it from `microbe_fasta`. |
| `microbe_taxonomy_file` | string | **required** | Microbe taxonomy database file. **Required parameter.** |
| `soloFeatures` | string | GeneFull_Ex50pAS Gene | Features to be quantified by STARsolo. |
| `outFilterMatchNmin` | integer | 50 | Minimum alignment match length for STAR. |
| `soloCellFilter` | string | EmptyDrops_CR 3000 0.99 10 45000 90000 500 0.01 20000 0.001 10000 | Cell filtering method and parameters. |
| `outSAMtype` | string | BAM SortedByCoordinate | Output SAM/BAM type. |
| `soloCBmatchWLtype` | string | EditDist_2 | Cell barcode matching method. |
| `limitBAMsortRAM` | integer | 32000000000 | Maximum memory for BAM sorting (bytes). |
| `adapter_3p` | string | AAAAAAAAAAAA | 3' adapter sequence. |
| `report_soloFeature` | string | GeneFull_Ex50pAS | Feature for STARsolo report. |
| `STAR_param` | string |  | Additional STAR parameters. |
| `SAM_attributes` | string | null | SAM attributes for STARsolo. |
| `fasta` | string | null | Host genome FASTA file. Required if `genomeDir`, `filter_bwa_image` or `kmer_file` is not provided. |
| `gtf` | string | null | Host genome GTF file. Required if `genomeDir` is not provided. |
| `mt_gene_list` | string | null | Mitochondrial gene list file for index building. |
| `genome_name` | string | genomeDir | Name for the host genome index. |
| `keep_attributes` | string | null | GTF attributes to keep when filtering with MKGTF. |
| `microbe_fasta` | string | null | Microbe FASTA file. Required if `microbe_bwa_image` and `microbe_dict` are not provided. |
| `microbe_name` | string | microbe | Name for the microbe index. |
| `min_score_identity` | number | 0.7 | Minimum score identity for pathseq alignment. |
| `min_clipped_read_length` | integer | 60 | Minimum clipped read length for pathseq. |
| `downsample_reads` | integer | 10000000 | Number of reads to downsample to. |
| `bloom_false_positive_probability` | number | 0.001 | Bloom filter false positive probability. |
| `kmer_size` | integer | 31 | K-mer size for `PathSeqBuildKmers`. |
| `kmer_mask` | string | null | K-mer mask for `PathSeqBuildKmers`. |
| `java_options` | string | -Xmx30G | Java options for GATK. Increase this value for larger genomes. |

### Obtain reference files

Users can download pre-built host and microbe reference files from Google Cloud bucket:

```bash
gsutil -m cp -r "gs://gatk-best-practices/pathseq/resources" .
```

### Path-seq workflow

The path-seq workflow consists of the following steps:

- **sample**: Parse FASTQ files and generate sample metrics.
- **starsolo**: Align reads to the host genome using STARsolo, extract cell barcodes and UMIs.
- **pathseq**: Align unaligned reads to the microbial reference database using PathSeq.
- **count_pathseq**: Count microbial UMIs and reads, cross-reference with scRNA-seq data.
- **analysis_pathseq**: Analyze microbial UMI matrix and generate plots.

### Main Output Files

- `outs/{sample}_raw_UMI_matrix.tsv.gz`: The unfiltered microbial detection matrix containing UMI counts for every barcode where at least one microbial read was detected.

- `outs/{sample}_filtered_UMI_matrix.tsv.gz`: The cell-matched matrix intended for downstream biological analysis. It is cross-referenced with the scRNA-seq data.

An example of downstream analysis using Seurat can be found at [github](https://github.com/singleron-RD/analysis_guide/blob/main/PathSeq_analysis.ipynb).

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).


---

# Troubleshooting

## Out-of-Memory Failure in GATK

The `pathseq` step runs GATK's `PathSeqPipelineSpark`, which internally uses BWA for host/microbe alignment. BWA allocates memory **off-heap** (outside the JVM heap), while the Java heap size is hard-coded to `-Xmx100g` inside the celescope container and cannot be changed through the pipeline parameters.

On machines where total memory is limited (e.g. ~128 GB), the combination of a 100 GB JVM heap plus BWA's off-heap allocation can exhaust available memory and cause the process to be killed by the OS. This typically shows up as an exit code `247` (or `137`) with an error like:

```
subprocess.CalledProcessError: Command 'gatk PathSeqPipelineSpark ...' returned non-zero exit status 247.
```

To work around this, constrain the memory available to the Docker container so that the JVM heap and the off-heap allocation together stay within safe bounds.

### Solution: Set a container memory limit

Edit the `docker` profile in `nextflow.config` and add the `-m` option to `docker.runOptions`:

```groovy
docker {
    docker.enabled    = true
    conda.enabled     = false
    singularity.enabled = false
    podman.enabled    = false
    shifter.enabled   = false
    charliecloud.enabled = false
    apptainer.enabled = false
    docker.runOptions = '-u $(id -u):$(id -g) -m 110g'
}
```

The `-m 110g` value sets a hard memory limit for the container. Adjust this number based on your host's total memory and the size of the reference indices. As a rule of thumb, leave at least **60–70 GB** of headroom for BWA's off-heap usage when the JVM heap is fixed at 100 GB.

For a host with ~128 GB of RAM, `-m 110g` is a reasonable starting point. If the process still fails, lower the value further (e.g. `-m 90g`).

### Adjusting the limit

| Host RAM | Suggested `-m` value | Notes |
|----------|---------------------|-------|
| 128 GB   | 110g                | Leaves ~18 GB for OS and other processes |
| 256 GB   | 200g                | Plenty of headroom |

If the problem persists even after setting a container memory limit, the recommended approach is to reduce the number of microbial reads using `--downsample_reads`.


## User Identity Resolution in GATK

The `pathseq` step invokes GATK's `PathSeqPipelineSpark`, which initializes a Spark context at startup. During initialization, Hadoop's `UserGroupInformation` attempts to resolve the current user through `UnixLoginModule.login()`. If the container process runs under a UID that has **no corresponding entry in the container's `/etc/passwd`**, this lookup fails and the process aborts with a stack trace like:

```
at jdk.security.auth/com.sun.security.auth.module.UnixLoginModule.login(UnixLoginModule.java:134)
...
at org.apache.hadoop.security.UserGroupInformation.doSubjectLogin(UserGroupInformation.java:2001)
...
at org.broadinstitute.hellbender.engine.spark.SparkContextFactory.createSparkContext(SparkContextFactory.java:185)
```

By default, Nextflow runs container processes under the **host user's UID/GID**. However, the container image typically only contains its own users, so the host UID is unknown inside the container, and the login step fails.

### Solution: Bind-mount the host's user database into the container

Edit the `docker` profile in `nextflow.config` and add mount options for `/etc/passwd` and `/etc/group` to `docker.runOptions`:

```groovy
docker {
    docker.enabled    = true
    conda.enabled     = false
    singularity.enabled = false
    podman.enabled    = false
    shifter.enabled   = false
    charliecloud.enabled = false
    apptainer.enabled = false
    docker.runOptions = '-u $(id -u):$(id -g) -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro'
}
```

With these mounts, the container can resolve the host UID to a real username, and `UnixLoginModule` completes successfully.

> **Note:** If you are also applying the container memory limit described in the [Memory Configuration](#out-of-memory-failure-in-gatk) section, combine both options into a single `runOptions` string:
>
> ```groovy
> docker.runOptions = '-u $(id -u):$(id -g) -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro -m 110g'
> ```
