#!/usr/bin/env bash

# Script for synching all SVN repositories in certain path

# Retrieve from which folder the script is run
# Source: https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself
func_get_script_source_dir () {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        # if $SOURCE was a relative symlink, we need to resolve it relative
        # to the path where the symlink file was located
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    local DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    echo $DIR
}

# Create directory for logging
mkdir -p "$(func_get_script_source_dir)"/logs

# Variable for adding date into file names
datefile=$(date +"%Y-%m-%d_%H-%M")
logfile="$(func_get_script_source_dir)"/logs/svnsync_all_"$datefile".log

# Logging
# Example https://serverfault.com/a/103569/323362
# Example 2: https://unix.stackexchange.com/a/67658/375094
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 2> >(tee -a "$logfile" >&2) \
    > >(tee -a "$logfile")

echo "$(date --iso-8601=seconds) #### Script started #### "

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
