#!/usr/bin/env bash

# Script for mirroring repos

# Add repository names which should be synched.
# These repositories should in the path defined in repo_path.
arr_repos=()
arr_repos+=(reponame)
arr_repos+=(reponame2)

repo_path="/opt/storage/repos_svnsync/"

for repo in "${arr_repos[@]}"
do
    echo ""
    echo "###################################"
    echo "svnsync sync file://$repo_path$repo"
    svnsync sync file://"$repo_path""$repo"
done
