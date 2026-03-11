/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FILTER_GTF } from '../../modules/local/common/filter_gtf'
include { STAR_INDEX } from '../../modules/local/common/star_index'

workflow STAR_GENOME {
    take:
    fasta 
    gtf
    genome_name
    cpus

    main:
    //assert fasta : "Fasta file required for genome indexing"
    //assert gtf   : "GTF file required for genome indexing"
    FILTER_GTF(gtf)
    STAR_INDEX(fasta, FILTER_GTF.out.filtered_gtf, genome_name, cpus)

    emit:
    index    = STAR_INDEX.out.index
    versions = STAR_INDEX.out.versions
}