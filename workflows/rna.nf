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
process MKGTF {
    tag "${gtf.BaseName}"
    label 'process_single'

    container "${params.container}"

    input:
    path gtf

    output:
    path "${gtf.BaseName}.filtered.gtf", emit: filtered_gtf
    path "mt_gene_list.txt", emit: mt_gene_list

    script:
    def output_gtf = "${gtf.BaseName}.filtered.gtf"
    def keep_attributes = params.keep_attributes ? "--keep_attributes ${params.keep_attributes.join(',')}" : ''

    """
    celescope utils mkgtf \\
        ${gtf} \\
        ${output_gtf} \\
        ${keep_attributes}
    """
}

process MKREF {
    tag "${params.genome_name}"
    label 'process_medium'

    container "${params.container}"

    input:
    path fasta
    path gtf
    path default_mt_gene_list

    output:
    path "${params.genome_name}"   , emit: index

    script:
    def mt_gene_list = params.mt_gene_list ? ${params.mt_gene_list} : default_mt_gene_list

    """
    set -e
    celescope rna mkref \\
        --genome_name ${params.genome_name} \\
        --thread ${params.max_thread} \\
        --fasta ${fasta} \\
        --gtf ${gtf} \\
        --mt_gene_list ${mt_gene_list}

    mkdir ${params.genome_name}
    find . -maxdepth 1 -not -name "${params.genome_name}" -not -name ".*" -exec mv {} ${params.genome_name} \\;
    """
}


process CELESCOPE_RNA {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)
    path(genomeDir)

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
    def pattern = params.pattern ? '--pattern ${params.pattern}' : ''
    def whitelist = params.whitelist ? '--whitelist ${params.whitelist}' : ''

    """
    # sample step
    celescope rna sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # starsolo step
    celescope rna starsolo \\
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
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # analysis step
    celescope rna analysis \\
        --outdir ./${sample}/02.analysis \\
        --sample ${sample} \\
        --genomeDir ${genomeDir} \\
        --matrix_file ./${sample}/outs/filtered

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
    def genomeDir = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    ch_gtf          = params.gtf   ? file(params.gtf, checkIfExists: true)   : []
    if (params.genomeDir) {
        genomeDir = file(params.genomeDir, checkIfExists: true)
    } else {
        MKGTF(
            params.gtf,
        )
        MKREF(
            ch_genome_fasta,
            MKGTF.out.filtered_gtf,
            MKGTF.out.mt_gene_list,
        )
        genomeDir = MKREF.out.index
    }

    // celescope_rna
    CELESCOPE_RNA (
        ch_samplesheet,
        genomeDir,
    )
    ch_versions = ch_versions.mix(CELESCOPE_RNA.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_RNA.out.data_json)

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
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
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
