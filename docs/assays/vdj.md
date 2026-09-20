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
| `match_dir` | Full path to match celescope scRNA-Seq directory. Required for VDJ assay. |

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
 --ref_path /genome/vdj/human/human_TR \
 --species human \
 --vdj_type TCR \
 -profile vdj,docker
```

### VDJ-specific parameters

The VDJ assay includes several parameters for controlling the analysis:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ref_path` | string | null | Reference path for igblast. |
| `vdj_ref_dir` | string | null | VDJ fasta directory. |
| `species` | string | `human` | Required. Species: human or mouse. |
| `vdj_type` | string | `TCR` | Required. Receptor type: TCR or BCR. |
| `threshold` | number | `0.5` | Valid base threshold for consensus. |
| `not_consensus` | boolean | `false` | Skip the consensus step. |
| `min_consensus_read` | integer | `2` | Minimum number of reads to support a base. |
| `split_fasta` | boolean | `false` | Split fasta file to map to avoid running out of memory. |
| `aux_file` | string | null | Aux file for igblastn. Required for customized species (not human or mouse). |
| `UMI_min` | integer | `3` | Minimum number of chain UMI to consider as a cell. |
| `BCR_iUMI` | integer | `2` | Minimum UMI of identical receptor type and CDR3 for BCR. |
| `TCR_iUMI` | integer | `2` | Minimum UMI of identical receptor type and CDR3 for TCR. |
| `expected_target_cell_num` | integer | `3000` | Expected T or B cell number. |
| `target_cell_barcode` | string | null | Barcode of target cells (plain text file, one barcode per line). |
| `target_weight` | number | `3.0` | UMIs of the target cells are multiplied by this factor. Only used when `--target_cell_barcode` is provided. |


> [!NOTE]

> `ref_path` or `vdj_ref_dir` is required to be specified.

> If `target_cell_barcode` is provided, `expected_target_cell_num` is ignored.


### Prepare VDJ reference

If you do not have a VDJ IMGT reference index directory, you can download the VDJ reference from IMGT database.

**Human:**
```bash
mkdir -p /genome/vdj/human
cd /genome/vdj/human
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Homo_sapiens/TR/TR{A,B}{V,J}.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Homo_sapiens/TR/TRBD.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Homo_sapiens/IG/IG{H,K,L}{V,J}.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Homo_sapiens/IG/IGHD.fasta
```

**Mouse:**
```bash
mkdir -p /genome/vdj/mouse
cd /genome/vdj/mouse
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Mus_musculus/TR/TR{A,B}{V,J}.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Mus_musculus/TR/TRBD.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Mus_musculus/IG/IG{H,K,L}{V,J}.fasta
wget https://www.imgt.org/download/V-QUEST/IMGT_V-QUEST_reference_directory/Mus_musculus/IG/IGHD.fasta
```

Then specify the `vdj_ref_dir` in the parameter file.

```bash
vdj_ref_dir: /genome/vdj/human
```


### VDJ workflow

The VDJ workflow consists of the following steps:

- **sample**: Automatically detect GEXSCOPE kit version from R1 reads.
- **barcode**: Demultiplex barcodes form R1 reads.
- **consensus**: Consensus reads of the same (barcode, UMI) combinations into one read.
- **mapping_vdj**: Align R2 reads or consensus sequences to IMGT (http://www.imgt.org/) database sequences using IgBLAST.
- **count_vdj**: Cell-calling based on barcode-UMI rank and summarize clonetypes information.

For detailed descriptions of outputs and the full list of available parameters, please refer to the [CeleScope documentation](https://github.com/singleron-RD/CeleScope).
