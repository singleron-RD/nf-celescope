/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { STAR_GENOME            } from '../subworkflows/local/star_genome'

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nf-celescope_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
process CELESCOPE_RNA {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(fq1), path(fq2)

    output:
    path "versions.yml"        , emit: versions

    script:
    def args = task.ext.args ?: ''
    def sample = "${meta.id}"
    def fq1_str = fq1.join(',')
    def fq2_str = fq2.join(',')

    """
    # sample step
    celescope rna sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --thread ${params.thread} \\
        --chemistry ${params.chemistry} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # starsolo step
    celescope rna starsolo \\
        --outdir ./${sample}/01.starsolo \\
        --sample ${sample} \\
        --thread ${params.thread} \\
        --chemistry ${params.chemistry} \\
        --adapter_3p ${params.adapter_3p} \\
        --genomeDir ${params.genomeDir} \\
        --outFilterMatchNmin ${params.outFilterMatchNmin} \\
        --soloCellFilter "${params.soloCellFilter}" \\
        --limitBAMsortRAM ${params.limitBAMsortRAM} \\
        --STAR_param "${params.STAR_param}" \\
        --outSAMtype "${params.outSAMtype}" \\
        --soloFeatures "${params.soloFeatures}" \\
        --soloCBmatchWLtype ${params.soloCBmatchWLtype} \\
        --report_soloFeature ${params.report_soloFeature} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # analysis step
    celescope rna analysis \\
        --outdir ./${sample}/02.analysis \\
        --sample ${sample} \\
        --thread ${params.thread} \\
        --genomeDir ${params.genomeDir} \\
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
    def star_genome = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    ch_gtf          = params.gtf   ? file(params.gtf, checkIfExists: true)   : []
    if (params.star_genome) {
        star_genome = file(params.star_genome, checkIfExists: true)
    } else {
        STAR_GENOME(
            ch_genome_fasta,
            ch_gtf,
            params.genome_name,
            params.star_cpus,
        )
        ch_versions = ch_versions.mix(STAR_GENOME.out.versions.first())
        star_genome = STAR_GENOME.out.index

    // celescope_rna
    CELESCOPE_RNA (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(CELESCOPE_RNA.out.versions.first())

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
