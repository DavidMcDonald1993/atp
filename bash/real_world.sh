#!/bin/bash

#SBATCH --job-name=ATPREALWORLD
#SBATCH --output=ATPREALWORLD_%A_%a.out
#SBATCH --error=ATPREALWORLD_%A_%a.err
#SBATCH --array=0-299
#SBATCH --time=10-00:00:00
#SBATCH --ntasks=1
#SBATCH --mem=5G

datasets=(cora_ml citeseer pubmed wiki_vote cora)
seeds=({0..29})
exps=(lp_experiment recon_experiment)

num_datasets=${#datasets[@]}
num_seeds=${#seeds[@]}
num_exps=${#exps[@]}

dataset_id=$((SLURM_ARRAY_TASK_ID / (num_exps * num_seeds) % num_datasets))
seed_id=$((SLURM_ARRAY_TASK_ID / num_exps % num_seeds))
exp_id=$((SLURM_ARRAY_TASK_ID % num_exps))

dataset=${datasets[$dataset_id]}
seed=${seeds[$seed_id]}
exp=${exps[$exp_id]}

echo $dataset $seed $exp

data_dir=../HEADNET/datasets/${dataset}
if [ $exp == "recon_experiment" ]
then 
    edgelist=${data_dir}/edgelist.tsv.gz
else
    edgelist=$(printf ../HEADNET/edgelists/${dataset}/seed=%03d/training_edges/edgelist.tsv.gz ${seed})
fi
echo edgelist is $edgelist

module purge
module load bluebear
module load Python/2.7.15-GCCcore-8.2.0

# install required packages
pip install --user numpy==1.13.3 pandas trueskill networkx==1.10

output=$(printf "datasets/${dataset}/${exp}/seed=%03d" ${seed})

if [ ! -f ${output}/edgelist.edges ]
then 

    echo generating ${output}/edgelist.edges

    python convert_edgelist.py --edgelist ${edgelist} --output ${output} 

fi 

if [ ! -f ${output}/edgelist_removed_by_H-Voting.edges ]
then 

    echo generating ${output}/edgelist_removed_by_H-Voting.edges

    # determine with edges to remove
    cd ../breaking_cycles_in_noisy_hierarchies

    break_cycles_args=$(echo -g ../atp/${output}/edgelist.edges )
    python break_cycles.py ${break_cycles_args}

    cd ../atp
fi 

if [ ! -f ${output}/edgelist_DAG.edges ] 
then 

    echo generating ${output}/edgelist_DAG.edges
    # remove chosen edges 
    remove_edges_args=$(echo --original_graph ${output}/edgelist.edges \
        --deleted_edges ${output}/edgelist_removed_by_H-Voting.edges )

    python remove_cycle_edges_to_DAGs.py ${remove_edges_args}

fi

for dim in 5 10 25 50
do

    embedding_dir=embeddings/${dataset}/${exp}
    embedding_dir=$(printf "${embedding_dir}/seed=%03d/dim=%03d" ${seed} ${dim})

    embed_args=$(echo --dag ${output}/edgelist_DAG.edges \
        --rank ${dim} --using_SVD )

    for method in ln harmonic
    do

        if [ ! -f ${embedding_dir}/${method}/source.csv.gz ]
        then  

            if [ ! -f ${embedding_dir}/${method}/source.csv ]
            then

            
                echo performing ${method} embedding dim ${dim}
                # perform embedding
                args=$(echo --strategy ${method} --output ${embedding_dir}/${method} )
                python main_atp.py ${embed_args} ${args}
            fi

            echo ${embedding_dir}/${method}/source.csv exists -- compressing 
            gzip ${embedding_dir}/${method}/source.csv
            gzip ${embedding_dir}/${method}/target.csv

        else 
            echo ${embedding_dir}/${method}/source.csv.gz already exists
        fi 

    done
done