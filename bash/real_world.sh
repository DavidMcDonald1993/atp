#!/bin/bash

#SBATCH --job-name=ATPembeddingsREALWORLD
#SBATCH --output=ATPembeddingsREALWORLD_%A_%a.out
#SBATCH --error=ATPembeddingsREALWORLD_%A_%a.err
#SBATCH --array=0-1499
#SBATCH --time=10-00:00:00
#SBATCH --ntasks=1
#SBATCH --mem=25G

datasets=(cora_ml citeseer pubmed wiki_vote email)
dims=(2 5 10 25 50)
seeds=({00..29})
exps=(lp_experiment recon_experiment)

num_datasets=${#datasets[@]}
num_dims=${#dims[@]}
num_seeds=${#seeds[@]}
num_exps=${#exps[@]}

dataset_id=$((SLURM_ARRAY_TASK_ID / (num_exps * num_seeds * num_dims) % num_datasets))
dim_id=$((SLURM_ARRAY_TASK_ID / (num_exps * num_seeds) % num_dims))
seed_id=$((SLURM_ARRAY_TASK_ID / num_exps % num_seeds))
exp_id=$((SLURM_ARRAY_TASK_ID % num_exps))

dataset=${datasets[$dataset_id]}
dim=${dims[$dim_id]}
seed=${seeds[$seed_id]}
exp=${exps[$exp_id]}

data_dir=../HEDNet/datasets/${dataset}
if [ $exp == "recon_experiment" ]
then 
    edgelist=${data_dir}/edgelist.tsv
else
    edgelist=$(printf ../HEDNet/edgelists/${dataset}/seed=%03d/training_edges/edgelist.tsv ${seed})
fi
echo edgelist is $edgelist
embedding_dir=embeddings/${dataset}/${exp}
embedding_dir=$(printf "${embedding_dir}/seed=%03d/dim=%03d" ${seed} ${dim})

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

embed_args=$(echo --dag ${output}/edgelist_DAG.edges \
    --rank ${dim} --using_SVD )


for method in ( linear ln harmonic )
do

    if [ ! -f ${embedding_dir}/${method}/source.csv.gz ]
    then  

        if [ ! -f ${embedding_dir}/${method}/source.csv ]
        then

        
            echo performing ln embedding
            # perform embedding
            args=$(echo --strategy ${method} --output ${embedding_dir}/${method})
            python main_atp.py ${embed_args} ${args}
        fi

        echo ${embedding_dir}/${method}/source.csv exists -- compressing 
        gzip ${embedding_dir}/${method}/source.csv
        gzip ${embedding_dir}/${method}/target.csv

    fi 

done

# if [ ! -f ${embedding_dir}/ln/source.csv.gz ]
# then  
    
#     echo performing ln embedding
#     # perform embedding (ln)
#     ln_args=$(echo --strategy ln --output ${embedding_dir}/ln)
#     python main_atp.py ${embed_args} ${ln_args}

#     gzip ${embedding_dir}/ln/source.csv
#     gzip ${embedding_dir}/ln/target.csv

# fi 

# if [ ! -f ${embedding_dir}/harmonic/source.csv.gz ]
# then

#     echo performing harmonic embedding
#     # perform embedding (harmonic)
#     harmonic_args=$(echo --strategy harmonic \
#         --output ${embedding_dir}/harmonic)
#     python main_atp.py ${embed_args} ${harmonic_args}

#     gzip ${embedding_dir}/harmonic/source.csv
#     gzip ${embedding_dir}/harmonic/target.csv
# fi