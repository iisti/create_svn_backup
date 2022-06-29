#!/usr/bin/env bash

# A script for comparing remote and local Last Changed Rev.
# Tells which if mirroring is synching correctly.

# A user which has read access to remote repository.
remote_user="svnbk"

# The URL of the remote SVN server without repository names.
remote_base_url="https://svn.domain.com/repo/"

# Repository path. This should include only repositories
# which are meant to be synched.
repo_path="/opt/storage/svn-repos/"

echo "### Configuration:"
echo "Remote user:      $remote_user"
echo "Remote base URL:  $remote_base_url"
echo "Remote path:      $repo_path"

# Create arreay for repositories
arr_repos=()

# Check repositories in the path
echo ""
echo "##############################"
echo "### Found repositories"
echo "##############################"
for f in "$repo_path"*; do
    if [ -d "$f" ]; then
        echo "$f"
        arr_repos+=($f)
    fi
done


echo ""
echo "##############################"
echo "### Compare repositories"
echo "##############################"
for repo in "${arr_repos[@]}"
do
    echo ""
    #echo "svnsync sync file://$repo"
    #svnsync sync file://"$repo"
    reponame=$(echo $repo | rev | cut -d'/' -f1 | rev)
    echo "Repository: $reponame"
    last_rev_remote=$(svn info "$remote_base_url""$reponame" --username "$remote_user" | grep "Last Changed Rev:")
    last_rev_local=$(svn info file://"$repo" | grep "Last Changed Rev:")

    if [[ "$last_rev_remote" == "$last_rev_local" ]]
    then
        echo "    Both have same: $last_rev_remote"
    else
        echo "    Last Changed Rev differs."
        echo "        Remote:   $last_rev_remote"
        echo "        Local:    $last_rev_local"
    fi
done
