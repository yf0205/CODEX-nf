#! /usr/bin/env nextflow
// usage : ./CODEX.nf --input_folder input/ --cpu 8 --mem 32 
/*
vim: syntax=groovy
-*- mode: groovy;-*- */

// requirement:
// - Rscript

//default values
params.dirNormal    = "Normal"
params.dirTumor     = "Tumor"
params.outdir       = "."
params.bedFile      = "positions.bed"
params.rem_from_bed = "_random|chrUn|GL000209R|GL000191R|GL000194R"
params.project      = "codex"
params.help         = null
params.mem          = 5
params.cpus         = 1
params.seg_mode     = "fraction"
params.Kmax         = 10
params.covmin       = 0

if (params.help) {
    log.info ''
    log.info '-------------------------------------------------------------'
    log.info 'NEXTFLOW COPY NUMBER VARIATION CALLING FROM WHOLE EXOME PIPELINE'
    log.info '-------------------------------------------------------------'
    log.info ''
    log.info 'Usage: '
    log.info 'nextflow run CODEX-nf --input_folder input/ [--cpus 8] [--mem 32] [--RG "PL:ILLUMINA"] [--fastq_ext fastq.gz] [--suffix1 _1] [--suffix2 _2] [--out_folder output/]'
    log.info ''
    log.info 'Mandatory arguments:'
    log.info '    --input_folder   FOLDER                  Folder containing BAM or fastq files to be aligned.'
    log.info 'Optional arguments:'
    log.info '    --Kmax	10                   Maximum number of latent factors to be tested. '
    log.info ''
    exit 1
}

//create channel
chrs  = Channel.from( 'chr1','chr2','chr3','chr4','chr5','chr6','chr7','chr8','chr9','chr10','chr11','chr12','chr13','chr14','chr15','chr16','chr17','chr18','chr19','chr20','chr21','chr22','chrX','chrY' )

process CODEX_normalize_perchr {
        cpus params.cpus
        memory params.mem+'G'
        tag { chr_tag }
        
        input:
	val chr from chrs
     
        output:
	file("*Y_qc.txt") into Y_qc_files
	file("*Yhat.txt") into Yhat_files
	file("*optK.txt") into optK_files
	file("*qcmat.txt") into qcmat_files
	file("*ref_qc.txt") into ref_qc_files
	file("*sampname_qc.txt") into sampname_qc_files
	val chr into chr_tag
	
        shell:
        chr_tag = chr
        '''
	Rscript !{baseDir}/bin/codex_run.R !{params.dirNormal} !{params.dirTumor} !{params.bedFile} "!{params.rem_from_bed}" !{params.project} !{chr} !{params.Kmax} !{params.covmin}
        '''
}

process CODEX_findoptK_allchr {
    cpus params.cpus
    memory params.mem+'G'
    tag { chr}
        
    input:
    val chr from chr_tag
    file optK from optK_files.toList()
    file Y_qc from Y_qc_files
    file Yhat from Yhat_files
    file qcmat from qcmat_files
    file ref_qc from ref_qc_files
    file sampname_qc from sampname_qc_files
	    
    output:
    file("optKallchr.txt") into optKallchr
    val chr into chr_list2
    file Y_qc into Y_qc_files2
    file Yhat into Yhat_files2
    file qcmat into qcmat_files2
    file ref_qc into ref_qc_files2
    file sampname_qc into sampname_qc_files2

    shell:
    '''
    cat *optK.txt | sort -g | head -n1 > optKallchr.txt
    '''
}

process CODEX_segmentation_perchr {
    cpus params.cpus
    memory params.mem+'G'
    tag { chr_tag }
        
    input:
    val chr from chr_list2
    file optKallchr from optKallchr
    file Y_qc from Y_qc_files2
    file Yhat from Yhat_files2
    file qcmat from qcmat_files2
    file ref_qc from ref_qc_files2
    file sampname_qc from sampname_qc_files2
	    
    output:
    file("*results*.txt") into outdir
    publishDir params.outdir, mode: 'move'

    shell:
    chr_tag = chr
    '''
    K=`cat !{optKallchr}`
    Rscript !{baseDir}/bin/segmentation_run.R !{params.seg_mode} !{Y_qc} !{Yhat} $K !{sampname_qc} !{ref_qc} !{params.project}
    '''
}

