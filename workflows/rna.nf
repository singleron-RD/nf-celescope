/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'

include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nf-celescope_pipeline'

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

    output:
    path "${params.genome_name}"   , emit: index

    script:
    def mt_gene_list = params.mt_gene_list ? "--mt_gene_list ${params.mt_gene_list}" : ''

    """
    set -e
    celescope rna mkref \\
        --genome_name ${params.genome_name} \\
        --thread ${params.max_thread} \\
        --fasta ${fasta} \\
        --gtf ${gtf} \\
        ${mt_gene_list}

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
        )
        genomeDir = MKREF.out.index
    }

    // celescope_rna
    CELESCOPE_RNA (
        ch_samplesheet,
        genomeDir,
    )
    ch_versions = ch_versions.mix(CELESCOPE_RNA.out.versions.first())

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
