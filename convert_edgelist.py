# try:
#   from pathlib import Path
# except ImportError:
#   from pathlib2 import Path  # python 2 backport

import os

import networkx as nx 

import argparse 

def parse_args():

    parser = argparse.ArgumentParser(description="convert weighted tab-separated edgelist to ATP format")

    parser.add_argument("--edgelist", dest="edgelist", 
        type=str, default=None,
        help="edgelist to load.")

    parser.add_argument("--output", dest="output", 
        type=str, default=None,
        help="directory of edgelist to save.")


    return parser.parse_args()

def main ():

    args = parse_args()

    print ("reading edgelist", args.edgelist)
    g = nx.read_weighted_edgelist(args.edgelist, nodetype=int, 
        create_using=nx.DiGraph())
    if not os.path.exists(args.output):
        print ("making directory", args.output)
        try:
            os.makedirs(args.output)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise

    nx.write_edgelist(g, os.path.join(args.output, "edgelist.edges" ), 
        data=[])


if __name__ == "__main__":
    main()