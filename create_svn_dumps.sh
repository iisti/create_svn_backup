#!/usr/bin/env bash

# Script for creating SVN dumps of repos

repo_path="/opt/storage/svn_repos/"
dump_path="/opt/storage/svn_dumps/"

# Define repos separately or load all repos from certain path.
arr_repos=()

# Add repos separately if required
#arr_repos+=(reponame1)
#arr_repos+=(reponame2)
#arr_repos+=(reponame3)

# Or extract repo names from repo_path. Uncomment "repos_multiline" and "mapfile"

# Explanation of command:
#   find only depth 1 directories
#   reverse paths, so that the last dir (=repo) is the first
#   cut with / as delimiter and select 1st field (=repo dir)
#   reverse again, so that repo names are correct
# The repos are saves as multiline string.
#repos_multiline=$(find $repo_path -mindepth 1 -maxdepth 1 -type d | rev | cut -d'/' -f 1 | rev)

# Convert multiline string to array
#mapfile -t arr_repos <<< "$repos_multiline"

datefile=$(date +"%Y-%m-%d_%H-%M")

for repo in "${arr_repos[@]}"
do
    echo ""
    echo "###################################"
    echo "svnadmin dump $repo_path$repo > $dump_path$repo_$datefile.dump"
    svnadmin dump "$repo_path""$repo" > "$dump_path""$repo"_"$datefile".dump
done
