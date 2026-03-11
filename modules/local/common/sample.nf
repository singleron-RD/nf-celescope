process SAMPLE {

    tag "$meta.id"
    label 'process_single'

    // conda 'singleronbio::celescope==v2.10.3'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
            'https://depot.galaxyproject.org/singularity/celescope:v2.10.3' :
            'quay.io/singleron-rd/celescope:v2.10.3' }"

    input:
    tuple val(meta), path(reads, stageAs: "?/*")
    val chemistry
    val assay

    output:
    tuple val(meta), path("*/stat.txt")     , emit: stat_sample
    tuple val(meta), path("*.data.json")    , emit: data_sample
    tuple val(meta), path("*.metrics.json") , emit: metrics_sample
    tuple val(meta), path("*_report.html")  , emit: report_sample
    tuple val(meta), path("*.stats.json")   , emit: json
    path  "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = "${meta.id}"
    def (forward, reverse) = reads.collate(2).transpose()
    def args = task.ext.args ?: ''

    """
    set -e 
    celescope ${assay} sample \\
        --outdir ${meta.id}.sample \\
        --sample ${meta.id} \\
        --thread 1 \\
        --chemistry ${chemistry}  \\
        --fq1 ${forward.join( "," )} \\
        ${args}

    mv .data.json sample.data.json
    mv .metrics.json sample.metrics.json
    grep -o '"Chemistry": "[^"]*"' sample.metrics.json | sed 's/.*/{&}/' > ${meta.id}.${assay}.chemistry.stats.json
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        celescope: \$(celescope -v)
    END_VERSIONS

    """
}
