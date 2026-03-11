def multiqc_sgr_config():
    from multiqc import config

    """ Set up MultiQC config defaults for this package """
    sgr_search_patterns = {
        "rna/stats": {"fn": "*rna.*stats.json"},
        "rna/umi_count": {
            "fn": "*rna.umi_count.json",
        },
        "rna/saturation": {
            "fn": "*rna.saturation.json",
        },
        "rna/median_gene": {
            "fn": "*rna.median_gene.json",
        },
    }
    config.update_dict(config.sp, sgr_search_patterns)
