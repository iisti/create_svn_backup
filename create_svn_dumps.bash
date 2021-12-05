#!/usr/bin/env bash

# Script for creating SVN dumps of repos

arr_repos=()
arr_repos+=(reponame1)
arr_repos+=(reponame2)
arr_repos+=(reponame3)

repo_path="/opt/storage/svn_repos/"
dump_path="/opt/storage/svn_dumps/"

datefile=$(date +"%Y-%m-%d_%H-%M")

for repo in "${arr_repos[@]}"
do
    echo ""
    echo "###################################"
    echo "svnadmin dump $repo_path$repo > $dump_path$repo_$datefile.dump"
    svnadmin dump "$repo_path""$repo" > "$dump_path""$repo"_"$datefile".dump
done
