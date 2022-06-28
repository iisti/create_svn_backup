#!/usr/bin/env bash

# Script for synching all SVN repositories in certain path

# Repository path. This should include only repositories
# which are meant to be synched.
repo_path="/opt/storage/bk-disk-02/svn-repos/"

# Create arreay for repositories
arr_repos=()

# Check repositories in the path
echo "##############################"
echo "### Found repositories"
echo "##############################"
for f in "$repo_path"*; do
    if [ -d "$f" ]; then
        echo "$f"
        arr_repos+=($f)
    fi
done

# Synch repositories
echo ""
echo "##############################"
echo "### Synching repositories"
echo "##############################"
for repo in "${arr_repos[@]}"
do
    echo ""
    echo "###################################"
    echo "svnsync sync file://$repo"
    svnsync sync file://"$repo"
done
