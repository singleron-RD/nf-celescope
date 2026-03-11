process ANALYSIS {

    tag "$meta.id"
    label 'process_single'

    //conda 'singleronbio::celescope==v2.10.3'
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
            'https://depot.galaxyproject.org/singularity/celescope:v2.10.3' :
            'quay.io/singleron-rd/celescope:v2.10.3' }"

    input:
    tuple val(meta), path(matrix_dir)
    path index
    tuple val(meta), path(data_json), path(metrics_json)

    output:
    tuple val(meta), path('*outs/markers.tsv')          , emit: markers_file
    tuple val(meta), path('*outs/tsne_coord.tsv')       , emit: tsne_file
    tuple val(meta), path('*outs/rna.h5ad')             , emit: h5ad_rna
    tuple val(meta), path("*.analysis/markers_raw.tsv") , emit: markers_raw
    tuple val(meta), path("*.analysis/stat.txt")        , emit: stat_analysis
    tuple val(meta), path("*.analysis.data.json")       , emit: data_analysis
    tuple val(meta), path("*.analysis.metrics.json")    , emit: metrics_analysis
    tuple val(meta), path("${meta.id}_report.html")     , emit: report_analysis
    path  "versions.yml"                                , emit: versions
 
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''

    """
    set -e
    cp ${data_json} .data.json
    cp ${metrics_json} .metrics.json

    celescope rna analysis \\
        --outdir ${meta.id}.analysis \\
        --sample ${meta.id} \\
        --thread 1 \\
        --genomeDir ${index}  \\
        --matrix_file ${matrix_dir} \\
        ${args}

    mv .data.json ${meta.id}.analysis.data.json
    mv .metrics.json ${meta.id}.analysis.metrics.json
    mv outs ${meta.id}.outs

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scanpy: \$(python -c "import scanpy as sc; print(sc.__version__)")
    END_VERSIONS
    """
}
