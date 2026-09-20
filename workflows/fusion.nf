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
    tag "${params.genome_name}"
    label 'process_medium'

    container "${params.container}"

    input:
    path fasta
    path fusion_pos

    output:
    path "${params.genome_name}"   , emit: index

    script:
    """
    set -e
    celescope fusion mkref \\
        --genome_name ${params.genome_name} \\
        --fasta ${fasta} \\
        --fusion_pos ${fusion_pos}

    mkdir ${params.genome_name}
    find . -maxdepth 1 -not -name "${params.genome_name}" -not -name ".*" -exec mv {} ${params.genome_name} \\;
    """
}


process CELESCOPE_FUSION {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)
    path(fusion_genomeDir)

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
    def minimum_length = params.minimum_length ? "--minimum_length ${params.minimum_length}" : ''
    def nextseq_trim = params.nextseq_trim ? "--nextseq_trim ${params.nextseq_trim}" : ''
    def overlap = params.overlap ? "--overlap ${params.overlap}" : ''
    def cutadapt_param = params.cutadapt_param ? "--cutadapt_param \"${params.cutadapt_param}\"" : ''
    def outFilterMatchNmin = params.outFilterMatchNmin ? "--outFilterMatchNmin ${params.outFilterMatchNmin}" : ''
    def out_unmapped = params.out_unmapped ? "--out_unmapped" : ''
    def STAR_param = params.STAR_param ? "--STAR_param \"${params.STAR_param}\"" : ''
    def outFilterMultimapNmax = params.outFilterMultimapNmax ? "--outFilterMultimapNmax ${params.outFilterMultimapNmax}" : ''
    def starMem = params.starMem ? "--starMem ${params.starMem}" : ''
    def flanking_base = params.flanking_base ? "--flanking_base ${params.flanking_base}" : ''
    def min_query_length = params.min_query_length ? "--min_query_length ${params.min_query_length}" : ''
    def not_correct_UMI = params.not_correct_UMI ? "--not_correct_UMI" : ''
    def read_threshold_method = params.read_threshold_method ? "--read_threshold_method ${params.read_threshold_method}" : ''
    def read_hard_threshold = params.read_hard_threshold ? "--read_hard_threshold ${params.read_hard_threshold}" : ''
    def umi_threshold_method = params.umi_threshold_method ? "--umi_threshold_method ${params.umi_threshold_method}" : ''
    def umi_hard_threshold = params.umi_hard_threshold ? "--umi_hard_threshold ${params.umi_hard_threshold}" : ''
    def auto_coef = params.auto_coef ? "--auto_coef ${params.auto_coef}" : ''
    def otsu_log_base = params.otsu_log_base ? "--otsu_log_base ${params.otsu_log_base}" : ''

    """
    # sample step
    celescope fusion sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # barcode step
    celescope fusion barcode \\
        --outdir ./${sample}/01.barcode \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # cutadapt step
    celescope fusion cutadapt \\
        --outdir ./${sample}/02.cutadapt \\
        --sample ${sample} \\
        ${minimum_length} \\
        ${nextseq_trim} \\
        ${overlap} \\
        ${cutadapt_param} \\
        --fq ./${sample}/01.barcode/${sample}_2.fq

    # star_fusion step
    celescope fusion star_fusion \\
        --outdir ./${sample}/03.star_fusion \\
        --sample ${sample} \\
        --fusion_genomeDir ${fusion_genomeDir} \\
        ${outFilterMatchNmin} \\
        ${outFilterMultimapNmax} \\
        ${out_unmapped} \\
        ${STAR_param} \\
        ${starMem} \\
        --fq ./${sample}/02.cutadapt/${sample}_clean_2.fq

    # count_fusion step
    celescope fusion count_fusion \\
        --outdir ./${sample}/04.count_fusion \\
        --sample ${sample} \\
        --fusion_genomeDir ${fusion_genomeDir} \\
        ${flanking_base} \\
        ${min_query_length} \\
        --match_dir ${meta.match_dir} \\
        --capture_bam ./${sample}/03.star_fusion/${sample}_Aligned.out.bam

    # filter_fusion step
    celescope fusion filter_fusion \\
        --outdir ./${sample}/05.filter_fusion \\
        --sample ${sample} \\
        ${not_correct_UMI} \\
        ${read_threshold_method} \\
        ${read_hard_threshold} \\
        ${umi_threshold_method} \\
        ${umi_hard_threshold} \\
        ${auto_coef} \\
        ${otsu_log_base} \\
        --match_dir ${meta.match_dir} \\
        --raw_read_count_file ./${sample}/04.count_fusion/${sample}_raw_read_count.json

    # analysis_fusion step
    celescope fusion analysis_fusion \\
        --outdir ./${sample}/06.analysis_fusion \\
        --sample ${sample} \\
        --fusion_genomeDir ${fusion_genomeDir} \\
        --match_dir ${meta.match_dir} \\
        --filter_umi_file ./${sample}/05.filter_fusion/${sample}_filtered_UMI.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope --version | sed 's/celescope //')
        cutadapt: \$(cutadapt --version 2>&1)
        star: \$( STAR --version | head -n 1 | sed 's/STAR //g' )
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

workflow FUSION {

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

    // fusion genome
    def fusion_genomeDir = null
    if (params.fusion_genomeDir) {
        fusion_genomeDir = file(params.fusion_genomeDir, checkIfExists: true)
    } else {
        ch_fusion_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
        ch_fusion_pos    = params.fusion_pos ? file(params.fusion_pos, checkIfExists: true) : []
        MKREF(
            ch_fusion_fasta,
            ch_fusion_pos,
        )
        fusion_genomeDir = MKREF.out.index
    }

    CELESCOPE_FUSION (
        ch_samplesheet,
        fusion_genomeDir,
    )
    ch_versions = ch_versions.mix(CELESCOPE_FUSION.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_FUSION.out.data_json)

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