#!/usr/bin/env bash

# A script for migrating SVN 1.5.1 to SVN 1.10

# Version history:
# 0.1 First version with non positional arguments
# 0.2 Added option "prompt" for no questions
script_version="0.2"

# Example of Bash arguments:
# https://stackoverflow.com/a/6310937/3498768
function help_usage() {
    cat <<EOF
Version: "$script_version"
Usage: $0 [options]

Arguments:

  -h, --help
    Display this usage message and exit.

  -r <val>, --remote_src <val>, --remote_src=<val>
    # Remote source for final sync
    # E.g. https://svn.com/repo

  -l <val>, --local_src <val>, --local_src=<val>
    # Local source if synching local repo
    # E.g. /svn/repos/source_repo

  -n <val>, --name <val>, --name=<val>
    # New repo
    # E.g. /svn/repos/my_repo

  -u <val>, --user <val>, --user=<val>
    # User who has access to remote repo

  -d <val>, --dump <val>, --dump=<val>
    # SVN dump file for loading
  
  -p <val>, --prompt <val>, --prompt=<val>
    # Give value yes/no
    # Yes = script will prompt questions
    # No = script run defaults

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

# handy logging and error handling functions
function log() { printf '%s\n' "$*"; }
function error() { log "ERROR: $*" >&2; }
function fatal() { error "$*"; exit 1; }
function usage_fatal() { error "$*"; help_usage >&2; exit 1; }

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

# Prompt questions or run defaults
prompt="yes"

while [ "$#" -gt 0 ]; do
    arg=$1
    case $1 in
        # convert "--opt=the value" to --opt "the value".
        # the quotes around the equals sign is to work around a
        # bug in emacs' syntax parsing
        --*'='*) shift; set -- "${arg%%=*}" "${arg#*=}" "$@"; continue;;
        -r|--remote_source) shift; remote_src=$1;;
        -l|--local_source) shift; local_src=$1;;
        -n|--name) shift; new_repo=$1;;
        -u|--user) shift; bkuser=$1;;
        -d|--dump) shift; dump=$1;;
        -p|--prompt) shift; prompt=$1;; 
        -h|--help) help_usage; exit 0;;
        --) shift; break;;
        -*) usage_fatal "unknown option: '$1'";;
        *) break;; # reached the list of file names
    esac
    shift || usage_fatal "option '${arg}' requires a value"
done

function create_repo() {
	# Parameter 1 = repo name with path
	if [ "$1" != "" ]; then
		# Create variables for easier code reading.
        # f means function in the variable name
        frepo="$1"
		svnadmin create "$frepo"
		# Create hook
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
		usage_fatal "function $0 requires repository name as an argument"
	fi
}

# Check that there's at least --name and one source given
if [ "$new_repo" = "empty_new_repo" ]
then
    usage_fatal "No new repository name -n/--name was given"
elif [ "$local_src" = "empty_local_src" ] && \
    [ "$remote_src" = "empty_remote_src" ] && \
    [ "$dump" = "empty_dump" ]
then
    usage_fatal "No source -r/-l/-d for creating a new repository was given"
fi


# Check and show parameters
    echo "New repo will be:         $new_repo"
if [ "$dump" != "empty_dump" ]; then
    echo "SVN dump file is:         $dump"
fi
if [ "$local_src" != "empty_local_src" ]; then
    echo "Local source repo is:     $local_src"
fi
if [ "$remote_src" != "empty_remote_src" ]; then
    echo "Remote source repo is:    $remote_src"
fi
if [ "$bkuser" != "empty_user" ]; then
    echo "Backup user is:           $bkuser"
fi
echo "Prompt questions:           $prompt"

# Create new repo
create_repo "$new_repo"

# Load dump file if needed
if [ "$dump" != "empty_dump" ]
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
        create_repo "$new_repo"-fixing
        svnadmin load "$new_repo"-fixing < $dump --bypass-prop-validation

        # Sync local repos
        svnsync init --sync-username svnsync file://"$new_repo" \
            file://"$new_repo"-fixing/
        svnsync sync file://"$new_repo"
    # If 2nd option, load dump to the new repo
    elif [[ $REPLY =~ ^2$ ]]
    then
        svnadmin load "$new_repo" < $dump
    elif [[ $REPLY =~ ^3$ ]]
    then
        echo "Continuing script without loading SVN dump file."
    else
        fatal "No valid option given!"
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


echo "Remember to remove obsolete files (dump, $new_repo-fixing)..."
exit 0
