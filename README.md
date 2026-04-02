## Introduction

**nf-celescope** is a nextflow wrapper for [CeleScope](https://github.com/singleron-RD/CeleScope).


## Quick start

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
testX,prefixX_001_R1.fq.gz,prefixX_001_R1.fq.gz
```

Each row represents a pair of fastq files. fastq_1 and fastq_2 must be full path. Relative path are not allowed.

Now, you can run the pipeline(using the single-cell rna as an example):

```bash
nextflow run singleron-RD/nf-celescope \
   -profile docker \
   --assay rna \
   --input samplesheet.csv \
   --fasta mmu_ensembl_110.fasta \
   --gtf mmu_ensembl_110.gtf \
   --genome_name mmu_ensembl_110 \
   --outdir outs
```

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run singleron-RD/nf-celescope -profile docker -params-file params.yaml
```


## Usage

Detailed usage for each assay are provided as follows.

|Assay|Kit|Description of data|Doc|
|-----|---|-------------------|---|
|rna|GEXSCOPE® Single Cell RNA Library Kit, GEXSCOPE® Single Nuclei RNA Library Kit|single-cell/single-nucleus RNA-seq|[rna](./docs/assays/rna.md)|



## Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull singleron-RD/nf-celescope
```

> [!NOTE]
> This command might fail if you have trouble connecting to github. In this case, you can manually git clone the master branch and run with the path to the folder.
> ```
> git clone https://github.com/singleron-RD/nf-celescope.git
> nextflow run /workspace/pipeline/nf-celescope ...
> ```

## Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [singleron-RD/nf-celescope releases page](https://github.com/singleron-RD/nf-celescope/releases) and find the latest pipeline version - numeric only (eg. `v2.11.3`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r v2.11.3`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

This pipeline has been developed and tested using Docker. While other execution profiles (such as Apptainer, Singularity, or Podman) are supported by Nextflow and may work, they have not been explicitly tested for this pipeline. Users are encouraged to try these alternatives based on their environment, but compatibility is not guaranteed.

- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-bg`

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
