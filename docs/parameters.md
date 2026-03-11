# singleron-RD/nf-celescope pipeline parameters

This document describes the general parameters in this pipeline. For assay-specific parameters, please refer to the documentation for the individual assays


## input_output_options

Define where the pipeline should find input data and save output data.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| input | `string` | ✅ | [`^\S+\.csv$`](https://regex101.com/?regex=%5E%5CS%2B%5C.csv%24) |  |  | Path to comma-separated file containing information about the samples in the experiment. |  |
| outdir | `string` | ✅ | Format: [`directory-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure. |  |
| email | `string` |  | [`^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$`](https://regex101.com/?regex=%5E%28%5Ba-zA-Z0-9_%5C-%5C.%5D%2B%29%40%28%5Ba-zA-Z0-9_%5C-%5C.%5D%2B%29%5C.%28%5Ba-zA-Z%5D%7B2%2C5%7D%29%24) |  |  | Email address for completion summary. |  |
| multiqc_title | `string` |  | string |  |  | MultiQC report title. Printed as page header, used for filename if not otherwise specified. |  |

## mandatory_arguments

Specify run assay and kit chemistry.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| assay | `string` | ✅ | string |  |  | Specify which Celescope assay to run |  |
| chemistry | `string` |  | `auto` `customized` `GEXSCOPE-MicroBead` `GEXSCOPE-V1` `GEXSCOPE-V2` `GEXSCOPE-V3` `flv_rna` `flv_rna-V2` `flv` `flv-V2` `bulk_vdj` `bulk_rna-V1` `bulk_rna-V2` `bulk_rna-V3` `bulk_rna-bulk_vdj_match` `space-ffpe` `space-ff` |  | `auto` | chemistry version |  |
| whitelist | `string` |  | Format: [`file-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | Custom barcode whitelist file |  |
| pattern | `string` |  | string |  |  | A string to locate cell barcode and UMI in R1 read. | `C9L16C9L16C9L1U12` <details><summary>Help</summary><small>C: cell barcode<br>L: Linker sequence between segments<br>U: UMI<br>T: poly T</small></details> |


## optional_modules

This section can be used to enable certain tools in the pipeline

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| run_fastqc | `boolean` |  | boolean |  | `false` | FastQC of raw reads. |  |

## celescope_extra_options

No description provided for this model.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| debug_log | `boolean` |  | boolean |  | `false` | If this argument is used, celescope may output addtional file for debugging |  |

## generic_options

Less common options for the pipeline, typically set in a config file.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| help | `boolean` |  | boolean |  |  | Display help text. |  |
| version | `boolean` |  | boolean |  |  | Display version and exit. |  |
| publish_dir_mode | `string` |  | `symlink` `rellink` `link` `copy` `copyNoFollow` `move` |  | `"symlink"` | Method used to save pipeline results to output directory. |  |
| trace_report_suffix | `string` |  | string |  |  | Suffix to add to the trace report filename. Default is the date and time in the format yyyy-MM-dd_HH-mm-ss. |  |
| email_on_fail | `string` |  | [`^([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})$`](https://regex101.com/?regex=%5E%28%5Ba-zA-Z0-9_%5C-%5C.%5D%2B%29%40%28%5Ba-zA-Z0-9_%5C-%5C.%5D%2B%29%5C.%28%5Ba-zA-Z%5D%7B2%2C5%7D%29%24) |  |  | Email address for completion summary, only when pipeline fails. |  |
| plaintext_email | `boolean` |  | boolean |  |  | Send plain-text email instead of HTML. |  |
| max_multiqc_email_size | `string` |  | [`^\d+(\.\d+)?\.?\s*(K\|M\|G\|T)?B$`](https://regex101.com/?regex=%5E%5Cd%2B%28%5C.%5Cd%2B%29%3F%5C.%3F%5Cs%2A%28K%7CM%7CG%7CT%29%3FB%24) |  | `"25.MB"` | File size limit when attaching MultiQC reports to summary emails. |  |
| monochrome_logs | `boolean` |  | boolean |  |  | Do not use coloured log outputs. |  |
| hook_url | `string` |  | string |  |  | Incoming hook URL for messaging service |  |
| multiqc_config | `string` |  | Format: [`file-path`](https://json-schema.org/understanding-json-schema/reference/string#built-in-formats) |  |  | Custom config file to supply to MultiQC. |  |
| multiqc_logo | `string` |  | string |  |  | Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file |  |
| multiqc_methods_description | `string` |  | string |  |  | Custom MultiQC yaml file containing HTML including a methods description. |  |
| validate_params | `boolean` |  | boolean |  | `true` | Boolean whether to validate parameters against the schema at runtime |  |
| validationShowHiddenParams | `boolean` |  | boolean |  |  | Show all params when using `--help` |  |
| validationFailUnrecognisedParams | `boolean` |  | boolean |  |  | Validation of parameters fails when an unrecognised parameter is found. |  |
| validationLenientMode | `boolean` |  | boolean |  |  | Validation of parameters in lenient more. |  |

## institutional_config_options

Parameters used to describe centralised config profiles. These should not be edited.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| custom_config_version | `string` |  | string |  | `"master"` | Git commit id for Institutional configs. |  |
| custom_config_base | `string` |  | string |  |  | Base directory for Institutional configs. |  |
| config_profile_name | `string` |  | string |  |  | Institutional config name. |  |
| config_profile_description | `string` |  | string |  |  | Institutional config description. |  |
| config_profile_contact | `string` |  | string |  |  | Institutional config contact information. |  |
| config_profile_url | `string` |  | string |  |  | Institutional config URL link. |  |

## max_job_request_options

Set the top limit for requested resources for any single job.

#### Type: `object`

| Property | Type | Required | Possible values | Deprecated | Default | Description | Examples |
| -------- | ---- | -------- | --------------- | ---------- | ------- | ----------- | -------- |
| max_cpus | `integer` |  | integer |  | `16` | Maximum number of CPUs that can be requested for any single job. |  |
| max_memory | `string` |  | [`^\d+(\.\d+)?\.?\s*(K\|M\|G\|T)?B$`](https://regex101.com/?regex=%5E%5Cd%2B%28%5C.%5Cd%2B%29%3F%5C.%3F%5Cs%2A%28K%7CM%7CG%7CT%29%3FB%24) |  | `"128.GB"` | Maximum amount of memory that can be requested for any single job. |  |
| max_time | `string` |  | [`^(\d+\.?\s*(s\|m\|h\|d\|day)\s*)+$`](https://regex101.com/?regex=%5E%28%5Cd%2B%5C.%3F%5Cs%2A%28s%7Cm%7Ch%7Cd%7Cday%29%5Cs%2A%29%2B%24) |  | `"240.h"` | Maximum amount of time that can be requested for any single job. |  |
