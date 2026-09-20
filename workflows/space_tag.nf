/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'

include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nf-celescope_pipeline'
include { paramsSummaryMap          } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
process CELESCOPE_SPACE_TAG {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)

    output:
    path "${meta.id}/"   , emit: sample_out
    path "${meta.id}/.data.json", emit: data_json
    path "versions.yml"  , emit: versions

    script:
    def args = task.ext.args ?: ''
    def sample = "${meta.id}"
    def (fq1, fq2) = reads.collate(2).transpose()
    def fq1_str = fq1.join(',')
    def fq2_str = fq2.join(',')
    def pattern = params.pattern ? "--pattern ${params.pattern}" : ''
    def whitelist = params.whitelist ? "--whitelist ${params.whitelist}" : ''
    def barcode_fasta = params.barcode_fasta ? "--barcode_fasta ${params.barcode_fasta}" : ''
    def fq_pattern = params.fq_pattern ? "--fq_pattern ${params.fq_pattern}" : ''
    def linker_fasta = params.linker_fasta ? "--linker_fasta ${params.linker_fasta}" : ''

    """
    # sample step
    celescope space_tag sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # barcode step
    celescope space_tag barcode \\
        --outdir ./${sample}/01.barcode \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # mapping_tag step
    celescope space_tag mapping_tag \\
        --outdir ./${sample}/02.mapping_tag \\
        --sample ${sample} \\
        ${barcode_fasta} \\
        ${linker_fasta} \\
        ${fq_pattern} \\
        --fq ./${sample}/01.barcode/${sample}_2.fq

    # count_tag step
    celescope space_tag count_tag \\
        --outdir ./${sample}/03.count_tag \\
        --sample ${sample} \\
        --match_dir ${meta.match_dir} \\
        --read_count_file ./${sample}/02.mapping_tag/${sample}_read_count.tsv

    # analysis_tag step
    celescope space_tag analysis_tag \\
        --outdir ./${sample}/04.analysis_tag \\
        --sample ${sample} \\
        --match_dir ${meta.match_dir} \\
        --umi_tag_file ./${sample}/03.count_tag/${sample}_umi_tag.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope --version | sed 's/celescope //')
    END_VERSIONS
    """
}

process MULTIQC {
    tag "multiqc-celescope"
    label 'process_single'

    container "quay.io/singleron-rd/multiqc-celescope:1.34dev1"

    input:
    path  multiqc_files, stageAs: "?/*"
    path(multiqc_config)
    path(extra_multiqc_config)
    path(multiqc_logo)


    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ? "--filename ${task.ext.prefix}.html" : ''
    def config = multiqc_config ? "--config $multiqc_config" : ''
    def extra_config = extra_multiqc_config ? "--config $extra_multiqc_config" : ''
    def logo = multiqc_logo ? "--cl-config 'custom_logo: \"${multiqc_logo}\"'" : ''
    """
    multiqc \\
        --force \\
        $args \\
        $config \\
        $prefix \\
        $extra_config \\
        $logo \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}

workflow SPACE_TAG {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    if (params.run_fastqc) {
        FASTQC (
            ch_samplesheet
        )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    }

    CELESCOPE_SPACE_TAG (
        ch_samplesheet,
    )
    ch_versions = ch_versions.mix(CELESCOPE_SPACE_TAG.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_SPACE_TAG.out.data_json)

    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
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
        ch_multiqc_logo.toList(),
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList()
    versions       = ch_versions

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
