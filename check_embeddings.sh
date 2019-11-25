#!/bin/bash

# experiments
for dataset in {cora_ml,citeseer,pubmed,wiki_vote,email}
do
	for dim in 2 5 10 25 50
	do	
		for seed in {00..29}
		do
			for method in ln harmonic
			do 
				for exp in recon_experiment lp_experiment
				do
					embedding_dir=$(printf \
					"embeddings/${dataset}/${exp}/seed=%03d/dim=%03d/${method}" ${seed} ${dim})

					if [ -f ${embedding_dir}/source.csv ] 
					then
						if [ ! -f ${embedding_dir}/source.csv.gz ]
						then 
							gzip ${embedding_dir}/source.csv
						fi
					else
						echo no embedding at ${embedding_dir}/source.csv
					fi

					if [ -f ${embedding_dir}/target.csv ]
					then 
						if [ ! -f ${embedding_dir}/target.csv.gz ]
						then 
							gzip ${embedding_dir}/target.csv
						fi
					else
						echo no embedding at ${embedding_dir}/target.csv
					fi
				done
			done
		done
	done
done