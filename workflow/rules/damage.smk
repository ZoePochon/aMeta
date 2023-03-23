rule MapDamage:
    output:
        dir=directory("results/MAPDAMAGE/{sample}"),
    input:
        pathogen_tax_id=ancient("results/KRAKENUNIQ/{sample}/taxID.pathogens"),
        bam=ancient("results/BOWTIE2/{sample}/AlignedToPathogenome.bam"),
        bai=ancient("results/BOWTIE2/{sample}/AlignedToPathogenome.bam.bai"),
    params:
        pathogenome_path=os.path.dirname(config["pathogenomesFound"]),
        PATHO_DB=config["bowtie2_patho_db"],
        options=config["options"].get("MapDamage", ""),
    threads: 10
    log:
        "logs/MAPDAMAGE/{sample}.log",
    conda:
        "../envs/mapdamage.yaml"
    envmodules:
        *config["envmodules"]["mapdamage"],
    benchmark:
        "benchmarks/MAPDAMAGE/{sample}.benchmark.txt"
    message:
        "MapDamage: RUNNING MAPDAMAGE ON PATHOGENS IDENTIFIED IN SAMPLE {input.bam}"
    shell:
        "mkdir {output.dir}; "
        "if [ -s {input.pathogen_tax_id} ]; then "
        'cat {input.pathogen_tax_id} | parallel -j {threads} "grep -w {{}} {params.pathogenome_path}/seqid2taxid.pathogen.map | cut -f1 > {output.dir}/{{}}.seq_ids" ; '
        "for i in $(cat {input.pathogen_tax_id}); do xargs --arg-file={output.dir}/${{i}}.seq_ids samtools view -bh {input.bam} --write-index -@ {threads} -o {output.dir}/${{i}}.tax.bam; done >> {log} 2>&1; "
        "find {output.dir} -name '*.tax.bam' | parallel -j {threads} \"mapDamage {params.options} -i {{}} -r {params.PATHO_DB} --merge-reference-sequences -d {output.dir}/mapDamage_{{}}\" >> {log} 2>&1 || true; "
        "for filename in {output.dir}/*.tax.bam; do newname=`echo $filename | sed 's/tax\.//g'`; mv $filename $newname; done >> {log} 2>&1; "
        "mv {output.dir}/mapDamage_{output.dir}/* {output.dir} >> {log} 2>&1; "
        "rm -r {output.dir}/mapDamage_results >> {log} 2>&1; "
        "else echo NO MICROBES TO AUTHENTICATE > {output.dir}/README.txt; fi"
