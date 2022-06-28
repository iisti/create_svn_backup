#!/usr/bin/env bash

# A script for migrating SVN 1.5.1 to SVN 1.10

# Version history:
# 0.1 First version with non positional arguments
# 0.2 Added option "prompt" for no questions
# 0.3 Changed functionality that one can run the script without any user input.
script_version="0.3"


#####################################
##### SCRIPT INIT AND CHECKS
#####################################

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
logfile="$(func_get_script_source_dir)"/logs/create_svn_backup_log_"$datefile".log


# Logging
# Example https://serverfault.com/a/103569/323362 
# Example 2: https://unix.stackexchange.com/a/67658/375094
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 2> >(tee -a "$logfile" >&2) \
    > >(tee -a "$logfile")

echo "$(date --iso-8601=seconds) #### Script started #### "


#####################################
##### FUNCTIONS
#####################################

# Help message function
# Example of Bash arguments:
# https://stackoverflow.com/a/6310937/3498768
function help_usage() {
    cat <<EOF
Version: "$script_version"
Usage: $0 [options]

Attention write the arguments in the order that they're in the list below!

Arguments:

  -h, --help
    Display this usage message and exit.

  -n <val>, --name <val>, --name=<val>
    # New repo, the destination
    # E.g. /svn/repos/my_repo
  
  -d <val>, --dump <val>, --dump=<val>
    # A SVN dump file which should be loaded to the new repo

  -r <val>, --remote_src <val>, --remote_src=<val>
    # Remote source for final sync
    # E.g. https://svn.com/repo
  
  -l <val>, --local_src <val>, --local_src=<val>
    # Local source if synching local repo
    # E.g. /svn/repos/source_repo

  -u <val>, --user <val>, --user=<val>
    # A user who has read access to remote repo.

  -f <val>, --fix_ends <val>, --fix_ends=<val>
    # Choose if the line endings, should be fixed.
    # Default is "no"

  -p <val>, --prompt <val>, --prompt=<val>
    # Give value yes/no
    # Yes = script will prompt questions
    # No = script run defaults
    # Default is "no"


  #### This was something which was in the example
  --
    Treat the remaining arguments as file names.  Useful if the first
    file name might begin with '-'.

  file...
    Optional list of file names.  If the first file name in the list
    begins with '-', it will be treated as an option unless it comes
    after the '--' option.
EOF
}

function func_create_repo() {
    # Parameter 1 = repo name with path
    if [ "$1" != "" ]; then
        # Create variables for easier code reading.
        # f means function in the variable name
        frepo="$1"
        svnadmin create "$frepo"
        # Create hook.
        # By default SVN doesn't allow revprops to be create or modified.
        # Therefore the destination repository must be configured to permit those operations.
        # Here's hardcoded user "svnsync" which is only user allowed to change the revops.
        pre_revrop="$frepo""/hooks/pre-revprop-change"
        cat >> "$pre_revrop" <<EOL
#!/bin/bash

USER="\$3"
backup_user=svnsync

if [ "\$backup_user" = "\$USER" ]; then exit 0; fi

echo "ERROR: Only user \"$backup_user\" can change revision properties!" >&2
exit 1
EOL

        # Change owner of the files
        chown -R svnsync "$frepo"
        # Make that file executable
        chmod u+x "$pre_revrop"
    else
        # https://stackoverflow.com/questions/2990414/echo-that-outputs-to-stderr
        func_usage_fatal "function $0 requires repository name as an argument"
    fi
}


# Fix line ending errors by loading the dump to $new_repo-fixing
# and then synchronize the $new_repo-fixing with $new_repo.
# This should fix any Line Ending Errors between different SVN
# between different SVN versions.
# Source:
# https://stackoverflow.com/questions/10279222/how-can-i-fix-the-svn-import-line-endings-error

function func_fix_ends () {
# Create a "repo_name"-fixing repo and sync new_repo with it.
func_create_repo "$new_repo"-fixing
svnadmin load "$new_repo"-fixing < $dump --bypass-prop-validation

# Create initial sync
svnsync init --sync-username \
    svnsync file://"$new_repo" \
    file://"$new_repo"-fixing/
# Start syncing
svnsync sync file://"$new_repo"
}

# handy logging and error handling functions
function log() { printf '%s\n' "$*"; }
function func_error() { log "ERROR: $*" >&2; }
function func_fatal() { error "$*"; exit 1; }
function func_usage_fatal() { error "$*"; help_usage >&2; exit 1; }

# parse default options
# Remote source for final sync
# E.g. https://svn.com/repo
remote_src="empty_remote_src"

# Local source if synching local repo
# E.g. /svn/repos/source_repo
local_src="empty_local_src"

# Destination repo
# E.g. /svn/repos/my_repo
new_repo="empty_new_repo"

# User who has access to remote repo
bkuser="empty_user"

# SVN dump file for loading
dump="empty_dump"

# If the line endings should be fixed or not.
fix_ends="no" 

# Prompt questions or run defaults
prompt="no"

while [ "$#" -gt 0 ]; do
    arg=$1
    case $1 in
        # convert "--opt=the value" to --opt "the value".
        # the quotes around the equals sign is to work around a
        # bug in emacs' syntax parsing
        --*'='*) shift; set -- "${arg%%=*}" "${arg#*=}" "$@"; continue;;
        -n|--name) shift; new_repo=$1;;
        -d|--dump) shift; dump=$1;;
        -r|--remote_source) shift; remote_src=$1;;
        -l|--local_source) shift; local_src=$1;;
        -u|--user) shift; bkuser=$1;;
        -f|--fix_ends) shift; fix_ends=$1;;
        -p|--prompt) shift; prompt=$1;; 
        -h|--help) help_usage; exit 0;;
        --) shift; break;;
        -*) func_usage_fatal "unknown option: '$1'";;
        *) break;; # reached the list of file names
    esac
    shift || func_usage_fatal "option '${arg}' requires a value"
done


# Check that there's at least --name and one source given
if [ "$new_repo" = "empty_new_repo" ]
then
    func_usage_fatal "No new repository name -n/--name was given"
elif [ "$local_src" = "empty_local_src" ] && \
    [ "$remote_src" = "empty_remote_src" ] && \
    [ "$dump" = "empty_dump" ]
then
    func_usage_fatal "No source -r/-l/-d for creating a new repository was given"
fi


# Check and show parameters
echo "New repo will be:         $new_repo"

if [ "$dump" != "empty_dump" ]; then
    echo "SVN dump file is:         $dump"
else
    echo "SVN dump file is:         No SVN dump file defined."
fi

if [ "$local_src" != "empty_local_src" ]; then
    echo "Local source repo is:     $local_src"
else
    echo "Local source repo is:     No local repo defined."
fi

if [ "$remote_src" != "empty_remote_src" ]; then
    echo "Remote source repo is:    $remote_src"
else
    echo "Remote source repo is:    No remote repo defined."
fi

if [ "$bkuser" != "empty_user" ]; then
    echo "Backup user is:           $bkuser"
else
    echo "Backup user is:           No backup user defined."
fi

echo "Fix line endings:         $fix_ends"
echo "Prompt questions:         $prompt"

# Create new repo
func_create_repo "$new_repo"

# Load dump file if needed
if [ "$dump" != "empty_dump" ] && [ "$prompt" == "yes" ]
then
    echo "You have defined a SVN dump file. You have choices:

1) Fix line ending errors by loading the dump to $new_repo-fixing
   and then synchronize the $new_repo-fixing with $new_repo.
   This should fix any Line Ending Errors between different SVN
   between different SVN versions.
   Source:
   https://stackoverflow.com/questions/10279222/how-can-i-fix-the-svn-import-line-endings-error

2) Load the dump to $new_repo without creating fix repository.

3) Do not load dump, but continue the script.
"
    read -p "Your choice ( 1, 2, 3 ): " -n 1 -r
    echo    # (optional) move to a new line
    # If 1st option, create a -fixing repo and sync new_repo with it.
    if [[ $REPLY =~ ^1$ ]]
    then
    	func_fix_ends
	# If 2nd option, load dump to the new repo
    elif [[ $REPLY =~ ^2$ ]]
    then
        svnadmin load "$new_repo" < $dump
    elif [[ $REPLY =~ ^3$ ]]
    then
        echo "Continuing script without loading SVN dump file."
    else
        func_fatal "No valid option given!"
    fi
fi

if [ "$dump" != "empty_dump" ] && [ "$prompt" == "no" ]
then
    echo "A SVN dump file was defined."
    if [ "$fix_ends" == "yes" ]
    then
        echo "It was defined that the line endings should be fixed."
        cat << EOF
Fixig the line ending errors by loading the dump to $new_repo-fixing
and then synchronizing the $new_repo-fixing with $new_repo.
This should fix any Line Ending Errors between different SVN
between different SVN versions.
Source:
https://stackoverflow.com/questions/10279222/how-can-i-fix-the-svn-import-line-endings-error
EOF
        func_fix_ends
    else
        cat << EOF
There will be no attempt to fix line endings.
There might be errors with line endings if one is importing from
much older SVN version to a newer SVN server.
Source:
https://stackoverflow.com/questions/10279222/how-can-i-fix-the-svn-import-line-endings-error"   
EOF
        svnadmin load "$new_repo" < "$dump"
    fi
fi


if [ "$local_src" != "empty_local_src" ]
then
    echo "Local source $local_src was given."
    read -p "Sync $new_repo with local source?: " -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        svnsync init --sync-username svnsync \
            file://"$new_repo" \
            file://"$local_src"
        svnsync sync file://"$new_repo"
    fi
fi


if [ "$remote_src" != "empty_remote_src" ]
then
    # Set the sync source to remote
    echo "Remote source $remote_src was given."
    
    if [[ $prompt = "yes"  ]]
    then
        read -p "Sync $new_repo with remote source?: " -n 1 -r
        echo    # (optional) move to a new line
    else
        # Set REPLY y if prompt is "no"
        REPLY="y"
    fi

    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        svnsync init --allow-non-empty --sync-username svnsync \
            file://"$new_repo" \
            $remote_src \
            --source-username $bkuser
        svnsync sync --sync-username svnsync file://"$new_repo"
    fi
fi

#######################
### Reminders for user
#######################

echo "Remember to remove obsolete files:"
echo "    SVN dumps"

if [ "$fix_ends" == "yes" ]; then
    echo "    $new_repo-fixing"
fi

exit 0
