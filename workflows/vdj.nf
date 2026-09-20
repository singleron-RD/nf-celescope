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

process MKREF {
    tag "${species}_${imgt_type}"
    label 'process_medium'

    container "${params.container}"

    input:
    path vdj_ref_dir
    val species
    val imgt_type

    output:
    path "${species}_${imgt_type}"   , emit: index

    script:

    """
    set -e
    cp -r ${vdj_ref_dir}/* .
    celescope vdj mkref \\
        ${species} \\
        ${imgt_type}
    """
}

process CELESCOPE_VDJ {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)
    path ref_path_input

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
    def species = params.species ? "--species ${params.species}" : ''
    def vdj_type = params.vdj_type ? "--type ${params.vdj_type}" : ''
    def not_consensus = params.not_consensus ? "--not_consensus" : ''
    def threshold = params.threshold ? "--threshold ${params.threshold}" : ''
    def min_consensus_read = params.min_consensus_read ? "--min_consensus_read ${params.min_consensus_read}" : ''
    def split_fasta = params.split_fasta ? "--split_fasta" : ''
    def aux_file = params.aux_file ? "--aux_file ${params.aux_file}" : ''
    def UMI_min = params.UMI_min ? "--UMI_min ${params.UMI_min}" : ''
    def BCR_iUMI = params.BCR_iUMI ? "--BCR_iUMI ${params.BCR_iUMI}" : ''
    def TCR_iUMI = params.TCR_iUMI ? "--TCR_iUMI ${params.TCR_iUMI}" : ''
    def expected_target_cell_num = params.expected_target_cell_num ? "--expected_target_cell_num ${params.expected_target_cell_num}" : ''
    def target_cell_barcode = params.target_cell_barcode ? "--target_cell_barcode ${params.target_cell_barcode}" : ''
    def target_weight = params.target_weight ? "--target_weight ${params.target_weight}" : ''

    """
    # sample step
    celescope vdj sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # barcode step
    celescope vdj barcode \\
        --outdir ./${sample}/01.barcode \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # consensus step
    celescope vdj consensus \\
        --outdir ./${sample}/02.consensus \\
        --sample ${sample} \\
        ${not_consensus} \\
        ${threshold} \\
        ${min_consensus_read} \\
        --out_fasta \\
        --fq ./${sample}/01.barcode/${sample}_2.fq

    # mapping_vdj step
    celescope vdj mapping_vdj \\
        --outdir ./${sample}/03.mapping_vdj \\
        --sample ${sample} \\
        --thread ${params.max_thread} \\
        --ref_path ${ref_path_input} \\
        ${species} \\
        ${vdj_type} \\
        ${split_fasta} \\
        ${aux_file} \\
        --fasta ./${sample}/02.consensus/${sample}_consensus.fasta

    # count_vdj step
    celescope vdj count_vdj \\
        --outdir ./${sample}/04.count_vdj \\
        --sample ${sample} \\
        --match_dir ${meta.match_dir} \\
        ${vdj_type} \\
        ${target_weight} \\
        ${UMI_min} \\
        ${BCR_iUMI} \\
        ${TCR_iUMI} \\
        ${expected_target_cell_num} \\
        ${target_cell_barcode} \\
        --UMI_count_filter_file ./${sample}/03.mapping_vdj/${sample}_UMI_count_filtered.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope --version | sed 's/celescope //')
        igblast: \$(igblastn -version 2>&1 | head -n 1 | sed 's/igblastn: //')
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

workflow VDJ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // VDJ reference: use existing ref_path or build with MKREF
    def ref_path = null
    if (params.ref_path) {
        ref_path = file(params.ref_path, checkIfExists: true)
    } else if (params.vdj_ref_dir) {
        // Convert vdj_type (TCR/BCR) to imgt_type (TR/IG)
        def imgt_type = params.vdj_type == 'TCR' ? 'TR' : 'IG'
        ch_vdj_ref_dir = Channel.fromPath(params.vdj_ref_dir, checkIfExists: true)
        MKREF(
            ch_vdj_ref_dir,
            Channel.value(params.species),
            Channel.value(imgt_type),
        )
        ref_path = MKREF.out.index
    } else {
        error "Either --ref_path or --vdj_ref_dir must be provided for VDJ assay"
    }

    if (params.run_fastqc) {
        FASTQC (
            ch_samplesheet
        )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())
    }

    CELESCOPE_VDJ (
        ch_samplesheet,
        ref_path,
    )
    ch_versions = ch_versions.mix(CELESCOPE_VDJ.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_VDJ.out.data_json)

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