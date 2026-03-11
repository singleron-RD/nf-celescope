process STARSOLO {

    //
    // This module executes STAR align quantification
    //

    tag "$meta.id"
    label 'process_high'

    // conda 'singleronbio::celescope==v2.10.3'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
            'https://depot.galaxyproject.org/singularity/celescope:v2.10.3' :
            'quay.io/singleron-rd/celescope:v2.10.3' }"

    input:
    //
    // Input reads are expected to come as: [ meta, [ pair1_read1, pair1_read2, pair2_read1, pair2_read2 ] ]
    // Input array for a sample is created in the same order reads appear in samplesheet as pairs from replicates are appended to array.
    //
    tuple val(meta), path(reads), path(data_json), path(metrics_json)
    path index
    val report_solo
    val cpu

    output:
    tuple val(meta), path('*outs/*d.out.bam')                                   , emit: bam
    tuple val(meta), path('*outs/raw')                                          , emit: raw_matrix
    tuple val(meta), path('*outs/filtered')                                     , emit: filtered_matrix
    tuple val(meta), path('*outs/counts.tsv')                                   , emit: counts_file
    tuple val(meta), path("*starsolo/*Solo.out/${report_solo}/Summary.csv")     , emit: summary
    tuple val(meta), path("*starsolo/*Solo.out/${report_solo}/CellReads.stats") , emit: read_stats
    tuple val(meta), path('*starsolo/*Log.final.out')                           , emit: log_final
    tuple val(meta), path('*starsolo/*Log.out')                                 , emit: log_out
    tuple val(meta), path('*starsolo/*Log.progress.out')                        , emit: log_progress
    tuple val(meta), path("*starsolo/stat.txt")                                 , emit: stat_starsolo
    tuple val(meta), path("*starsolo.data.json")                                , emit: data_starsolo
    tuple val(meta), path("*starsolo.metrics.json")                             , emit: metrics_starsolo
    tuple val(meta), path("*_report.html")                                      , emit: report_starsolo
    path  "versions.yml"                                                        , emit: versions
    tuple val(meta), path('*starsolo/*toTranscriptome.out.bam')     , emit: bam_transcript   , optional:true
    tuple val(meta), path('*starsolo/*Aligned.unsort.out.bam')      , emit: bam_unsorted     , optional:true
    tuple val(meta), path('*starsolo/*fastq.gz')                    , emit: fastq            , optional:true
    tuple val(meta), path('*starsolo/*.tab')                        , emit: tab              , optional:true


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def (forward, reverse) = reads.collate(2).transpose()

    """
    set -e
    cp ${data_json} .data.json
    cp ${metrics_json} .metrics.json

    celescope rna starsolo \\
    --outdir ${meta.id}.starsolo \\
    --sample ${meta.id} \\
    --thread ${cpu} \\
    --genomeDir ${index} \\
    --fq1 ${forward.join( "," )} \\
    --fq2 ${reverse.join( "," )} \\
    $args

    mv .data.json ${meta.id}.starsolo.data.json
    mv .metrics.json ${meta.id}.starsolo.metrics.json
    mv outs ${meta.id}.outs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$(STAR --version | sed -e "s/STAR_//g")
    END_VERSIONS
    """
}
