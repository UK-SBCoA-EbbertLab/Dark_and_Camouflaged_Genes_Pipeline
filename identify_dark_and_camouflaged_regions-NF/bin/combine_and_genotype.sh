#!/bin/usr bash

TMP_DIR="tmp/${JOB_ID}"
mkdir -p $TMP_DIR

variant_list=$1
region=$2
result_dir=$3
referenceFasta=$4
GATK_JAR=$5

GATK="java -Xmx40G -Xms40G -jar $GATK_JAR"
echo "Combining all variants in $1 for the region $region"
echo "writing results to $result_dir"

tmp_combined="${TMP_DIR}/full_cohort.combined.${region}.g.vcf"
result="${result_dir}/full_cohort.genotyped.${region//:/_}.vcf"

$GATK \
 	-T CombineGVCFs \
	-R $referenceFasta \
	-L $region \
	-o $tmp_combined \
	--variant $variant_list

$GATK \
	-T GenotypeGVCFs \
	-R $referenceFasta \
	-L $region \
	-o $result \
	-A GenotypeSummaries \
	--variant $tmp_combined 

rm -rfv ${TMP_DIR}
echo "-------------"
echo "`date` DONE"
