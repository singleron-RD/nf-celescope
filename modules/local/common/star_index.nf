process STAR_INDEX {
    tag "$genome_name"
    label 'process_medium'

    // conda 'singleronbio::celescope==v2.10.3'
    container "${params.container}"

    input:
    path fasta
    path gtf
    val genome_name
    val star_cpus

    output:
    path "$genome_name"   , emit: index
    path "versions.yml"   , emit: versions

    script:
    def args       = task.ext.args ?: ''

    """
    set -e
    celescope rna mkref \\
        --genome_name ${genome_name} \\
        --thread ${star_cpus} \\
        --fasta ${fasta} \\
        --gtf ${gtf} \\
        $args

    mkdir ${genome_name}
    find . -maxdepth 1 -not -name "${genome_name}" -not -name ".*" -exec mv {} ${genome_name} \\;

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$(STAR --version | sed -e "s/STAR_//g")
    END_VERSIONS
    """
}