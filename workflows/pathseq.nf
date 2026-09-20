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

process MK_IMG {
    tag "img_${genome_name}"
    label 'process_high'

    container "${params.container}"

    input:
    path fasta
    val genome_name

    output:
    path "*.img"   , emit: img

    script:
    """
    gatk BwaMemIndexImageCreator \\
        -I ${fasta} \\
        -O ${genome_name}.img
    """
}

process MK_IMG_MICROBE {
    tag "img_${genome_name}"
    label 'process_high'

    container "${params.container}"

    input:
    path fasta
    val genome_name

    output:
    path "*.img"   , emit: img

    script:
    """
    gatk BwaMemIndexImageCreator \\
        -I ${fasta} \\
        -O ${genome_name}.img
    """
}

process MK_DICT {
    tag "dict_${genome_name}"
    label 'process_high'

    container "${params.container}"

    input:
    path fasta
    val genome_name

    output:
    path "*.dict"   , emit: dict

    script:
    """
    gatk CreateSequenceDictionary \\
        -R ${fasta} \\
        -O ${genome_name}.dict
    """
}

process MK_BFI {
    tag "bfi_${genome_name}"
    label 'process_high'

    container "${params.container}"

    input:
    path fasta
    val genome_name

    output:
    path "*.bfi"   , emit: bfi

    script:
    def kmer_mask = params.kmer_mask ? "--kmer-mask ${params.kmer_mask}" : ''
    def java_options = params.java_options ? "--java-options \"${params.java_options}\""  : ''

    """
    gatk PathSeqBuildKmers \\
        --reference ${fasta} \\
        -O ${genome_name}.bfi \\
        --bloom-false-positive-probability ${params.bloom_false_positive_probability} \\
        --kmer-size ${params.kmer_size} \\
        ${kmer_mask} \\
        ${java_options}
    """
}

process CELESCOPE_PATHSEQ {

    tag "$meta.id"
    label 'process_high'

    container "${params.container}"

    input:
    tuple val(meta), path(reads)
    path(genomeDir)
    path(filter_bwa_image)
    path(kmer_file)
    path(microbe_bwa_image)
    path(microbe_dict)

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
    def min_score_identity = params.min_score_identity ? "--min_score_identity ${params.min_score_identity}" : ''
    def min_clipped_read_length = params.min_clipped_read_length ? "--min_clipped_read_length ${params.min_clipped_read_length}" : ''
    def downsample_reads = params.downsample_reads ? "--downsample_reads ${params.downsample_reads}" : ''

    """
    # sample step
    celescope pathseq sample \\
        --outdir ./${sample}/00.sample \\
        --sample ${sample} \\
        --chemistry ${params.chemistry} \\
        ${pattern} \\
        ${whitelist} \\
        --fq1 "${fq1_str}" \\
        --fq2 "${fq2_str}"

    # starsolo step
    celescope pathseq starsolo \\
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

    # pathseq step
    celescope pathseq pathseq \\
        --outdir ./${sample}/02.pathseq \\
        --sample ${sample} \\
        --thread ${params.max_thread} \\
        --filter_bwa_image ${filter_bwa_image} \\
        --kmer_file ${kmer_file} \\
        --microbe_bwa_image ${microbe_bwa_image} \\
        --microbe_dict ${microbe_dict} \\
        --microbe_taxonomy_file ${params.microbe_taxonomy_file} \\
        ${min_score_identity} \\
        ${min_clipped_read_length} \\
        ${downsample_reads} \\
        --input_bam ./${sample}/01.starsolo/${sample}_Aligned.sortedByCoord.out.bam

    # count_pathseq step
    celescope pathseq count_pathseq \\
        --outdir ./${sample}/03.count_pathseq \\
        --sample ${sample} \\
        --thread ${params.max_thread} \\
        --match_dir ${meta.match_dir} \\
        --pathseq_bam_file ./${sample}/02.pathseq/${sample}_pathseq.bam \\
        --pathseq_score_file ./${sample}/02.pathseq/${sample}_pathseq_score.txt \\
        --unmap_bam_file ./${sample}/02.pathseq/${sample}_unmapped.bam

    # analysis_pathseq step
    celescope pathseq analysis_pathseq \\
        --outdir ./${sample}/04.analysis_pathseq \\
        --sample ${sample} \\
        --match_dir ${meta.match_dir} \\
        --umi_matrix_file ./${sample}/outs/${sample}_filtered_UMI_matrix.tsv.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope --version | sed 's/celescope //')
        star: \$( STAR --version | head -n 1 | sed 's/STAR //g' )
        samtools: \$(samtools --version | head -n 1 | awk '{print \$2}')
        gatk: \$(gatk --version 2>&1 | grep 'The Genome Analysis Toolkit' | awk '{print \$NF}')
        picard: \$(picard AddOrReplaceReadGroups --version 2>&1 | grep -Eo '[0-9]+\\.[0-9]+\\.[0-9]+.*' | head -n 1)
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

workflow PATHSEQ {

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

    // genome index
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

    def filter_bwa_image = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    if (params.filter_bwa_image) {
        filter_bwa_image = file(params.filter_bwa_image, checkIfExists: true)
    } else {
        MK_IMG(
            ch_genome_fasta,
            Channel.value(params.genome_name),
        )
        filter_bwa_image = MK_IMG.out.img
    }

    def kmer_file = null
    ch_genome_fasta = params.fasta ? file(params.fasta, checkIfExists: true) : []
    if (params.kmer_file) {
        kmer_file = file(params.kmer_file, checkIfExists: true)
    } else {
        MK_BFI(
            ch_genome_fasta,
            Channel.value(params.genome_name),
        )
        kmer_file = MK_BFI.out.bfi
    }

    // microbe index
    def microbe_bwa_image = null
    ch_microbe_fasta = params.microbe_fasta ? file(params.microbe_fasta, checkIfExists: true) : []
    if (params.microbe_bwa_image) {
        microbe_bwa_image = file(params.microbe_bwa_image, checkIfExists: true)
    } else {
        MK_IMG_MICROBE(
            ch_microbe_fasta,
            Channel.value(params.microbe_name),
        )
        microbe_bwa_image = MK_IMG_MICROBE.out.img
    }

    def microbe_dict = null
    ch_microbe_fasta = params.microbe_fasta ? file(params.microbe_fasta, checkIfExists: true) : []
    if (params.microbe_dict) {
        microbe_dict = file(params.microbe_dict, checkIfExists: true)
    } else {
        MK_DICT(
            ch_microbe_fasta,
            Channel.value(params.microbe_name),
        )
        microbe_dict = MK_DICT.out.dict
    }

    // main process
    CELESCOPE_PATHSEQ (
        ch_samplesheet,
        genomeDir,
        filter_bwa_image,
        kmer_file,
        microbe_bwa_image,
        microbe_dict,
    )
    ch_versions = ch_versions.mix(CELESCOPE_PATHSEQ.out.versions.first())
    ch_multiqc_files = ch_multiqc_files.mix(CELESCOPE_PATHSEQ.out.data_json)

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