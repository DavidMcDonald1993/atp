#!/bin/bash

# experiments
for dataset in cora_ml citeseer pubmed wiki_vote email
do
	for dim in 5 10 25 50
	do	
		for seed in {0..29}
		do
			for method in ln harmonic
			do 
				for exp in recon_experiment lp_experiment
				do
					embedding_dir=$(printf \
					"embeddings/${dataset}/${exp}/seed=%03d/dim=%03d/${method}" ${seed} ${dim})

					for emb in "source" "target"
					do 

						if [ -f ${embedding_dir}/${emb}.csv.gz ] 
						then 
							continue
						elif [ -f ${embedding_dir}/${emb}.csv ]
						then 
							gzip ${embedding_dir}/${emb}.csv
						else 
							echo no embedding at ${embedding_dir}/${emb}.csv
						fi

					done 
				done
			done
		done
	done
done