# usage

## Create genome index

When running the data of a certain species for the first time, you can provide `fasta`, `gtf` and `genome_name` instead of `star_genome`. For example,

```yaml
fasta: "https://raw.githubusercontent.com/singleron-RD/test_genome/master/human.GRCh38.99.MT/human.GRCh38.99.MT.fasta"
gtf: "https://raw.githubusercontent.com/singleron-RD/test_genome/master/human.GRCh38.99.MT/human.GRCh38.99.MT.gtf"
genome_name: "human.GRCh38.99.MT"
```

The STAR index files will be saved in `{outdir}/star_index/{genome_name}/`.
When running data from the same genome later, you can provide `star_genome` to skip the indexing:

```yaml
star_genome: "/workspaces/test/outs/star_genome/human.GRCh38.99.MT/"
```

## Cell-calling algorithm

STARsolo implements two [cell-calling algorithms](https://github.com/alexdobin/STAR/blob/master/docs/STARsolo.md#cell-filtering-calling): Knee filtering(`cellranger2.2`) and EmptyDrop-like filtering(`EmptyDrops_CR`). EmptyDrop-like filtering considers more barcodes with low UMI as real cells, which helps to recover immune cells with low RNA content, but there is also a risk of including more background barcodes.

The cell-calling algorithm is controlled by the `soloCellFilter` parameter, for example
```yaml
soloCellFilter: EmptyDrops_CR
```

## Full samplesheet

There is a strict requirement for the first 3 columns to match those defined in the table below.

| Column           | Description    |
| ---------------- | -------------- |
| `sample`  | Required. Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Required. Full path to FastQ file reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |
| `fastq_2` | Required. Full path to FastQ file reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                                                |                                                                                 
| `expected_cells` | Optional. Number of cells expected for a sample. Must be an integer. If multiple rows are provided for the same sample, this must be the same number for all rows, i.e. the total number of expected cells for the sample.                                                                             |

An [example samplesheet](../../assets/samplesheet.csv) has been provided with the pipeline.

## Running the pipeline with test data

This pipeline contains a small test data. The test config file can be found [here](../conf/assays/test_rna.config).
Run the following command to test

```
nextflow run singleron-RD/nf-celescope -profile test_rna,docker --outdir results
```


# parameters

## rna_reference_genome_options

Reference parameters for RNA-related assays.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| star_genome | `string` |  | Format: [`directory-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | Path to STAR genome directory. Required if fasta and gtf are not provided. |  |
| fasta | `string` |  | string |  |  | Path to FASTA genome file. |  |
| gtf | `string` |  | Format: [`file-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | Reference GTF annotation file. |  |
| genome_name | `string` |  | string |  | `"star_genome"` | Specify the reference name. It is recommended to use the format species_version. The generated STAR genome index will be saved under this folder. It can then be used for future pipeline runs, reducing processing times. |  |
| mt_gene_list | `string` |  | Format: [`file-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | Mitochondria gene list file name. This file is a plain text file with one gene per line. |  |
| keep_attributes | `string` |  | string |  | `gene_biotype=protein_coding,lncRNA,antisense,IG_LV_gene,IG_V_gene,IG_V_pseudogene,IG_D_gene,IG_J_gene,IG_J_pseudogene,IG_C_gene,IG_C_pseudogene,TR_V_gene,TR_V_pseudogene,TR_D_gene,TR_J_gene,TR_J_pseudogene,TR_C_gene;` | Attributes to keep. |  |
| skip_intron | `boolean` |  | boolean |  |  | Do not add intron to gtf. |  |
| dry_run | `boolean` |  | boolean |  |  | Only write config file and exit when `mkref`. |  |


## starsolo_options

Same as the argument in STARsolo. All options have default values in Celescope.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| soloFeatures | `string` |  |  |  | `GeneFull_Ex50pAS Gene` | Quantification of different transcriptomic features. <details><summary>Help</summary><small>https://github.com/alexdobin/STAR/issues/1460  <br>--soloFeatures SJ quantifies splice junctions by calculating per-cell counts ofreads that are spliced across junctions. It will count spliced reads across annotatedand unannotated junctions, thus allowing analysis of inter-cell alternative splicing and detection of novel splice isoforms.  <br>--soloFeatures Velocyto performs separate counting for spliced, unsplicedand ambiguous reads, similar to the Velocyto tool . Its output can be usedin the RNA-velocity analyses to dissect the transcriptional dynamics of the cells.  </small></details> |  |
| soloCellFilter | `string` |  |  |  | `EmptyDrops_CR 3000 0.99 10 45000 90000 500 0.01 20000 0.001 10000` | Cell-calling method. <details><summary>Help</summary><small>https://github.com/alexdobin/STAR/blob/master/docs/STARsolo.md#cell-filtering-calling</small></details> |  |
| SAM_attributes | `string` |  | string |  |  | Additional attributes (other than NH HI nM AS CR UR CB UB GX GN ) to be added to SAM file. <details><summary>Help</summary><small>https://github.com/alexdobin/STAR/blob/master/docs/STARsolo.md#bam-tags</small></details> | `MD` |
| outFilterMatchNmin | `string` |  | string |  | `50` | Alignment will be output only if the number of matched bases is higher than or equal to this value. |  |
| soloCBmatchWLtype | `string` |  | string |  | `EditDist_2` | Matching the Cell Barcodes to the WhiteList. Please note `EditDist_2` only works with `--soloType CB_UMI_Complex`. |  |
| outSAMtype | `string` |  | string |  | `BAM SortedByCoordinate` | type of SAM/BAM output |  |
| limitBAMsortRAM | `string` |  | string |  | `32000000000` | Maximum available RAM (bytes) for sorting BAM. |  |
| STAR_param | `string` |  | string |  |  | Additional parameters for starsolo. Need to be enclosed in quotation marks. |  |
| adapter_3p | `string` |  | string |  | `AAAAAAAAAAAA` | Adapter sequence to clip from 3 prime. Multiple sequences are seperated by space. |  |
| report_soloFeature | `string` |  | string |  | `GeneFull_Ex50pAS` | Specify which soloFeatures to use in the HTML report and the outs directory. |  |
| star_cpus | `integer` |  | integer |  | `16` | Max cpus to run STAR. |  |


# output

- [Main Output](#main-output)
- [modules](#modules)
  - [filter\_gtf](#filter_gtf)
  - [star\_index](#star_index)
  - [sample](#sample)
  - [starsolo](#starsolo)
  - [analysis](#cell_calling)
  - [starsolo\_summary](#starsolo_summary)
  - [multiqc](../output.md#multiqc)
  - [pipeline\_info](../output.md#pipeline_info)
  - [fastqc(Optional)](../output.md#fastqcoptional)

## Main Output

- `multiqc/multiqc_report.html` HTML report containing QC metrics across all samples.
- `released/{sample}.out/filtered` Gene expression matrix file contains only cell barcodes. This file should be used as input to downstream analysis tools such as Seurat and Scanpy.
- `released/{sample}_report.html` CeleScope report.


## modules

### filter_gtf

This module has the same functionality as [`cellranger mkgtf`](https://kb.10xgenomics.com/hc/en-us/articles/360002541171-What-criteria-should-I-use-with-the-mkgtf-tool-when-making-a-custom-reference-for-Cell-Ranger)

> GTF files can contain entries for non-polyA transcripts that overlap with protein-coding gene models. These entries can cause reads to be flagged as mapped to multiple genes (multi-mapped) because of the overlapping annotations. In the case where reads are flagged as multi-mapped, they are not counted.

> We recommend filtering the GTF file so that it contains only gene categories of interest by using the cellranger mkgtf tool. Which genes to filter depends on your research question.

The filtering criteria is controlled by the argument `--keep_attributes`. The default value of this argument is the same as the [reference used by cellranger](https://support.10xgenomics.com/single-cell-gene-expression/software/release-notes/build#grch38_3.0.0)

> [!NOTE]
> gtf files from [genecode](https://www.gencodegenes.org/) use `gene_type` instead of `gene_biotype`.
>
> ```
> --keep_attributes "gene_type=protein_coding,lncRNA..."
> ```

**Output files**

- `*.filtered.gtf` GTF file after filtering.


### star_index

Generate STAR genome index. Detailed documents can be found in the [STAR Manual](https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf).

> [!TIP]
> Once you have the indices from a workflow run you should save them somewhere central and reuse them in subsequent runs using custom config files or command line parameters.

**Output files**

- `{genome_name}/` STAR genome index folder.

### sample

Automatically detect GEXSCOPE kit version from R1 reads.

**Output files**

- `{sample}.{assay}.chemistry.stats.json` Detected protocol.

### starsolo

Descriptions of parameters and files can be found in [STARSolo documents](https://github.com/alexdobin/STAR/blob/master/docs/STARsolo.md) and [STAR Manual](https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf).
When you have questions, [STAR’s github issue](https://github.com/alexdobin/STAR/issues) is also a great place to find answers and help.

> [!NOTE]
> The command line arguments in this STARsolo documentation may not be up to date. For the latest STARSolo arguments, please refer to The STAR Manual.

**Output files**

- `{sample}.outs/{sample}.Aligned.sortedByCoord.out.bam` Bam file contains coordinate-sorted reads aligned to the genome.

### analysis
Calculate the marker gene of each cluster.

**Output files**
- `{sample}.outs/markers.tsv` Marker genes of each cluster.
- `{sample}.outs/tsne_coord.tsv` t-SNE coordinates and clustering information.

### starsolo_summary

Extract data for visualization from starsolo result files.

