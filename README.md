## Introduction

**nf-celescope** is [CeleScope](https://github.com/singleron-RD/CeleScope) Nextflow pipeline.


## Documents

- [Usage](./docs/usage.md)
- [Output](./docs/output.md)
- [Parameters](./docs/parameters.md)
<br>
Detailed usage instructions for each assay are provided in their respective section.

|Assay|Kit|Description of data|Doc|
|-----|---|-------------------|---|
|rna|GEXSCOPE® Single Cell RNA Library Kit, GEXSCOPE® Single Nuclei RNA Library Kit|single-cell/single-nucleus RNA-seq|[rna](./docs/assays/rna.md)|


## Quick start

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,fastq_1,fastq_2
testX,prefixX_001_R1.fq.gz,prefixX_001_R1.fq.gz
```

Each row represents a fastq file (single-end) or a pair of fastq files (paired end).

Now, you can run the pipeline using (using the rna assay as an example):

```bash
nextflow run singleron-RD/nf-celescope \
   -profile docker \
   --assay rna \
   --input samplesheet.csv \
   --fasta mmu_ensembl_99.19.MT.fasta \
   --gtf mmu_ensembl_99.19.MT.gtf \
   --outdir <OUTDIR>
```


## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

