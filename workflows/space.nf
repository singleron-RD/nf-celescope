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
    tag "${genome_name}"
    label 'process_medium'

    container "${params.container}"

    input:
    path fasta
    path gtf
    val genome_name

    output:
    path "${genome_name}"   , emit: index

    script:
    """
    set -e
    celescope rna mkref \\
        --genome_name ${genome_name} \\
        --fasta ${fasta} \\
        --gtf ${gtf}

    mkdir ${genome_name}
    find . -maxdepth 1 -not -name "${genome_name}" -not -name ".*" -exec mv {} ${genome_name} \\;
    """
}

process CELESCOPE_SPACE {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)
    path(genomeDir)
    path(mirna_genomeDir)

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
    def mirna_genomeDir_arg = mirna_genomeDir ? "--mirna_genomeDir ${mirna_genomeDir}" : ''
    def min_genes = params.min_genes ? "--min_genes ${params.min_genes}" : ''

    """
    # sample step
    celescope space sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # starsolo step
    celescope space starsolo \\
        --outdir ./${sample}/01.starsolo \\
        --sample ${sample} \\
        --thread ${params.max_thread} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --adapter_3p ${params.adapter_3p} \\
        --genomeDir ${genomeDir} \\
        --outFilterMatchNmin ${params.outFilterMatchNmin} \\
        --soloCellFilter "${params.soloCellFilter}" \\
        --limitBAMsortRAM ${params.limitBAMsortRAM} \\
        --STAR_param "${params.STAR_param}" \\
        --soloFeatures "${params.soloFeatures}" \\
        --soloCBmatchWLtype ${params.soloCBmatchWLtype} \\
        --report_soloFeature ${params.report_soloFeature} \\
        --spatial ${meta.spatial} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # mirna step
    celescope space mirna \\
        --outdir ./${sample}/02.mirna \\
        --sample ${sample} \\
        --thread ${params.max_thread} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --adapter_3p ${params.adapter_3p} \\
        --genomeDir ${genomeDir} \\
        --outFilterMatchNmin ${params.outFilterMatchNmin} \\
        --soloCellFilter "${params.soloCellFilter}" \\
        --limitBAMsortRAM ${params.limitBAMsortRAM} \\
        --STAR_param "${params.STAR_param}" \\
        --soloFeatures "${params.soloFeatures}" \\
        --soloCBmatchWLtype ${params.soloCBmatchWLtype} \\
        --report_soloFeature ${params.report_soloFeature} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}" \\
        ${mirna_genomeDir_arg}

    # analysis step
    celescope space analysis \\
        --outdir ./${sample}/03.analysis \\
        --sample ${sample} \\
        --genomeDir ${genomeDir} \\
        --raw ./${sample}/outs/raw \\
        --filtered ./${sample}/outs/filtered \\
        --spatial ${meta.spatial} \\
        ${min_genes}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope --version | sed 's/celescope //')
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

workflow SPACE {

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

    def genomeDir = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    ch_gtf          = params.gtf   ? file(params.gtf, checkIfExists: true)   : []
    if (params.genomeDir) {
        genomeDir = file(params.genomeDir, checkIfExists: true)
    } else {
        MKREF(
            ch_genome_fasta,
            ch_gtf,
            Channel.value(params.genome_name),
        )
        genomeDir = MKREF.out.index
    }

    def mirna_genomeDir = Channel.value([])
    ch_mirna_fasta = params.mirna_fasta ? file(params.mirna_fasta, checkIfExists: true) : []
    ch_mirna_gtf   = params.mirna_gtf   ? file(params.mirna_gtf, checkIfExists: true)   : []
    if (params.mirna_genomeDir) {
        mirna_genomeDir = Channel.value(file(params.mirna_genomeDir, checkIfExists: true))
    } else if (params.mirna_fasta && params.mirna_gtf) {
        MKREF(
            ch_mirna_fasta,
            ch_mirna_gtf,
            Channel.value(params.mirna_name),
        )
        mirna_genomeDir = MKREF.out.index
    }

    CELESCOPE_SPACE (
        ch_samplesheet,
        genomeDir,
        mirna_genomeDir,
    )
    ch_versions = ch_versions.mix(CELESCOPE_SPACE.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_SPACE.out.data_json)

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