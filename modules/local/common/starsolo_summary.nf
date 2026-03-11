process STARSOLO_SUMMARY {
    tag "$meta.id"
    label 'process_single'

    // conda 'singleronbio::celescope==v2.10.3'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
            'https://depot.galaxyproject.org/singularity/celescope:v2.10.3' :
            'quay.io/singleron-rd/celescope:v2.10.3' }"

    input:
    tuple val(meta), path(read_stats), path(summary), path(filtered_matrix), path(counts_file)
    val assay

    output:
    tuple val(meta), path("*.json"), emit: json

    script:

    """
    starsolo_summary.py \\
        --read_stats ${read_stats} \\
        --count ${counts_file} \\
        --filtered_matrix ${filtered_matrix} \\
        --summary ${summary} \\
        --sample ${meta.id} \\
        --assay ${assay}
    """
}