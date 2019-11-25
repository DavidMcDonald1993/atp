#!/bin/bash

#SBATCH --job-name=ATPembeddingsLP
#SBATCH --output=ATPembeddingsLP_%A_%a.out
#SBATCH --error=ATPembeddingsLP_%A_%a.err
#SBATCH --array=0-749
#SBATCH --time=10:00:00
#SBATCH --ntasks=1
#SBATCH --mem=20G

datasets=({cora_ml,citeseer,pubmed,wiki_vote,email})
dims=(2 5 10 25 50)
seeds=({0..29})

num_datasets=${#datasets[@]}
num_dims=${#dims[@]}
num_seeds=${#seeds[@]}

dataset_id=$((SLURM_ARRAY_TASK_ID / (num_seeds * num_dims) % num_datasets))
dim_id=$((SLURM_ARRAY_TASK_ID / num_seeds % num_dims))
seed_id=$((SLURM_ARRAY_TASK_ID % num_seeds))

dataset=${datasets[$dataset_id]}
dim=${dims[$dim_id]}
seed=${seeds[$seed_id]}

data_dir=../HEDNet/datasets/${dataset}
# edgelist=${data_dir}/edgelist.tsv
edgelist=$(printf ../HEDNet/edgelists/${dataset}/seed=%03d/training_edges/edgelist.tsv ${seed})
embedding_dir=embeddings/${dataset}/lp_experiment
embedding_dir=$(printf "${embedding_dir}/seed=%03d/dim=%03d" ${seed} ${dim})

if [ ! -f ${embedding_dir}/ln/source.csv.gz ]
then

    module purge
    module load bluebear
    module load Python/2.7.15-GCCcore-8.2.0

    # install required packages
    pip install --user numpy==1.13.3 pandas trueskill networkx==1.10

    output=$(printf "datasets/${dataset}/lp_experiment/seed=%03d" ${seed})

    python convert_edgelist.py --edgelist ${edgelist} --output ${output} 

    # determine with edges to remove
    cd ../breaking_cycles_in_noisy_hierarchies

    break_cycles_args=$(echo -g ../atp/${output}/edgelist.edges )
    python break_cycles.py ${break_cycles_args}

    # remove chosen edges 
    cd ../atp

    remove_edges_args=$(echo --original_graph ${output}/edgelist.edges \
        --deleted_edges ${output}/edgelist_removed_by_H-Voting.edges )

    python remove_cycle_edges_to_DAGs.py ${remove_edges_args}

    embed_args=$(echo --dag ${output}/edgelist_DAG.edges \
        --rank ${dim} --using_SVD )
    
    # perform embedding (ln)
    ln_args=$(echo --strategy ln --output ${embedding_dir}/ln)
    python main_atp.py ${embed_args} ${ln_args}

    # perform embedding (harmonic)
    harmonic_args=$(echo --strategy harmonic \
        --output ${embedding_dir}/harmonic)
    python main_atp.py ${embed_args} ${harmonic_args}
fi