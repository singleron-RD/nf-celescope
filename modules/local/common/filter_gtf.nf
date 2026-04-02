process FILTER_GTF {
    tag "${gtf.BaseName}"
    label 'process_single'

    //conda 'singleronbio::celescope==v2.10.3'
    container "${params.container}"

    input:
    path gtf

    output:
    path "*.filtered.gtf", emit: filtered_gtf

    script:
    def args = task.ext.args ?: ''
    def output_gtf = "${gtf.BaseName}.filtered.gtf"

    """
    celescope utils mkgtf \\
        ${gtf} \\
        ${output_gtf} \\
        $args
    """
}
