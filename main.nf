#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    singleron-RD/nf-celescope
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/singleron-RD/nf-celescope
----------------------------------------------------------------------------------------
*/
nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { RNA                     } from './workflows/rna'
include { DYNASEQ                 } from './workflows/dynaseq'
include { SNP                     } from './workflows/snp'
include { FFPE                    } from './workflows/ffpe'
include { VDJ                     } from './workflows/vdj'
include { CITESEQ                 } from './workflows/citeseq'
include { FUSION                  } from './workflows/fusion'
include { TAG                     } from './workflows/tag'
include { SPACE                   } from './workflows/space'
include { SWEETSEQ                } from './workflows/sweetseq'
include { CAPTURE_VIRUS           } from './workflows/capture_virus'
include { PATHSEQ                 } from './workflows/pathseq'
include { BULK_RNA                } from './workflows/bulk_rna'
include { BULK_VDJ                } from './workflows/bulk_vdj'
include { PROBE                   } from './workflows/probe'
include { SPACE_TAG               } from './workflows/space_tag'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nf-celescope_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nf-celescope_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of assay
//
workflow NF_CELESCOPE {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // check assay
    //
    if (!params.assay) {
        println "Please specify an assay with -profile <assay_name>"
        println "Available assays: rna, dynaseq, snp, ffpe, vdj, bulk_vdj, citeseq, fusion, tag, space, sweetseq, capture_virus, pathseq, bulk_rna, probe, space_tag"
        System.exit(1)
    }


    //
    // WORKFLOW: Run pipeline
    //
    switch (params.assay) {
        case 'rna':
            result = RNA (samplesheet)
            break
        case 'dynaseq':
            result = DYNASEQ (samplesheet)
            break
        case 'snp':
            result = SNP (samplesheet)
            break
        case 'ffpe':
            result = FFPE (samplesheet)
            break
        case 'vdj':
            result = VDJ (samplesheet)
            break
        case 'citeseq':
            result = CITESEQ (samplesheet)
            break
        case 'fusion':
            result = FUSION (samplesheet)
            break
        case 'tag':
            result = TAG (samplesheet)
            break
        case 'space':
            result = SPACE (samplesheet)
            break
        case 'sweetseq':
            result = SWEETSEQ (samplesheet)
            break
        case 'capture_virus':
            result = CAPTURE_VIRUS (samplesheet)
            break
        case 'pathseq':
            result = PATHSEQ (samplesheet)
            break
        case 'bulk_rna':
            result = BULK_RNA (samplesheet)
            break
        case 'bulk_vdj':
            result = BULK_VDJ (samplesheet)
            break
        case 'probe':
            result = PROBE (samplesheet)
            break
        case 'space_tag':
            result = SPACE_TAG (samplesheet)
            break
        default:
            error "Unknown assay type: ${params.assay}"
    }

    emit:
    multiqc_report = result.multiqc_report // channel: /path/to/multiqc_report.html
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
    NF_CELESCOPE (
        PIPELINE_INITIALISATION.out.samplesheet,
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NF_CELESCOPE.out.multiqc_report
    )
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
