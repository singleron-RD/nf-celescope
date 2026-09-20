# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- **13 new assays** with complete Nextflow workflows, assay-specific configs, schema definitions, and documentation:
  - `vdj` — Single-cell immune repertoire profiling 
  - `bulk_vdj` — Bulk immune repertoire profiling (AccuraCode® TCR)
  - `citeseq` — Cellular Indexing of Transcriptomes and Epitopes by Sequencing
  - `fusion` — Gene fusion detection in single cells
  - `tag` — CLindex® Single-cell Multiplexing
  - `space` — Spatial transcriptomics
  - `space_tag` — Spatial transcriptomics with tag barcoding
  - `sweetseq` — ProMoSCOPE® Single Cell Glycosylation
  - `capture_virus` — FocuSCOPE® mRNA × EBV Library
  - `pathseq` — Microbial detection in single cells
  - `bulk_rna` — Sample barcoding technology with bulk RNA-seq
  - `probe` — Probe-based targeted sequencing

- **Schema architecture refactor** (`nextflow_schema.json`):
  - `allOf` now uses `if/then` conditional references keyed on the `assay` parameter, so each assay's `$defs` block (including its `required` fields) only applies when that assay's profile is active. This fixes cross-assay parameter validation pollution (e.g. `pathseq`'s `microbe_taxonomy_file` no longer fails `bulk_rna` runs).
  - Per-assay `required` fields restored (`bulk_rna.well_sample`, `pathseq.microbe_taxonomy_file`, `bulk_vdj.ref_path`).


### Changed

- Update to celescope v2.15.0.
- Updated `conf/assay/*.config`, `nextflow_schema.json`, and `docs/assays/*.md` for all assays to stay in sync with the corresponding `.nf` workflows.
- Updated `main.nf` to dispatch the new assay workflows.
- Updated `subworkflows/local/utils_nf-celescope_pipeline/main.nf` to classify all assays into `wo_matched_assays` (3-column samplesheet) and `wt_matched_assays` (4-column samplesheet with `match_dir`).

### Removed

- `--assay` command-line parameter is no longer supported; assay type must be specified via `-profile <assay_name>` (enforced in `main.nf`).

---