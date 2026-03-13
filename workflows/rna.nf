/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { STAR_GENOME            } from '../subworkflows/local/star_genome'
include { SAMPLE                 } from '../modules/local/common/sample'
include { STARSOLO               } from '../modules/local/common/starsolo'
include { STARSOLO_SUMMARY       } from '../modules/local/common/starsolo_summary'
include { ANALYSIS               } from '../modules/local/common/analysis'
include { MULTIQC                } from '../modules/local/common/multiqc'

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nf-celescope_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow RNA {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // fastqc
    if (params.run_fastqc) {
        FASTQC (
            ch_samplesheet
        )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    }

    // STAR genome
    def star_genome = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    ch_gtf          = params.gtf   ? file(params.gtf, checkIfExists: true)   : []
    if (params.star_genome) {
        star_genome = params.star_genome ? file(params.star_genome, checkIfExists: true) : []
    } else {
        STAR_GENOME(
            ch_genome_fasta,
            ch_gtf,
            params.genome_name,
            params.star_cpus,
        )
        ch_versions = ch_versions.mix(STAR_GENOME.out.versions.first())
        star_genome = STAR_GENOME.out.index
    }

    // sample
    SAMPLE (
        ch_samplesheet,
        params.chemistry,
        params.assay,
    )
    ch_multiqc_files = ch_multiqc_files.mix(SAMPLE.out.json.collect{it[1]})
    ch_versions = ch_versions.mix(SAMPLE.out.versions.first())

    // starsolo
    ch_merge = ch_samplesheet.join(SAMPLE.out.data_sample).join(SAMPLE.out.metrics_sample)
    STARSOLO (
        ch_merge,
        star_genome,
        params.report_soloFeature,
        params.star_cpus,
    )
    ch_versions = ch_versions.mix(STARSOLO.out.versions.first())

    // statsolo summary
    ch_merge = STARSOLO.out.read_stats.join(STARSOLO.out.summary).join(STARSOLO.out.filtered_matrix).join(STARSOLO.out.counts_file)       
    STARSOLO_SUMMARY ( 
        ch_merge ,
        params.assay,
    )
    ch_multiqc_files = ch_multiqc_files.mix(STARSOLO_SUMMARY.out.json.collect{it[1]})

    // analysis
    ch_merge = STARSOLO.out.filtered_matrix
                .join(STARSOLO.out.data_starsolo).join(STARSOLO.out.metrics_starsolo)
    ANALYSIS (
        ch_merge,
        star_genome,
    )
    ch_versions = ch_versions.mix(ANALYSIS.out.versions.first())

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config/rna_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        "${projectDir}/modules/local/multiqc_sgr/singleron_logo.png",
        "${projectDir}/modules/local/multiqc_sgr/",
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
