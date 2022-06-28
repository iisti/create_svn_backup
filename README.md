# Scripts for creating a mirror backup of SVN server
* Project for creating a backup of old or new SVN repository.
* Originally these scripts were used to migrate from SVN 1.5 to SVN 1.14.
* Tested with Debian 11.

## Usage
### Initial configurations
* Create *svnsync* Linux user.

## Some basic SVN commands
* These commands are not restricted for this script!

* If the mirror destination repo is not empty

      svnsync init --allow-non-empty --sync-username svnsync file:///var/svn/repos-mirror https://svn.domain.com/svn/project --source-username <backupuser_which_has_access_to_source>

* Check from where synching

      svnsync info file:///var/svn/repos-mirror
      
* Verify the data stored in the repository

      svnadmin verify /var/svn/repos/

* Start synching

      svnsync sync file:///var/svn/repos-mirror

* Create SVN dump
  * http://svnbook.red-bean.com/en/1.7/svn.ref.svnadmin.c.dump.html
  
        svnadmin dump REPO_PATH > name.dump

## Running svnsync in cronjob

    # Add to crontab, REMEMBER to escape % characters!
    sudo vim /etc/crontab
    20 11 * * * root /opt/scripts/svn/svnsync_all_from_path.bash | sudo tee /opt/scripts/svn/log/svnsync_all_"$(date +"\%Y-\%m-\%d_\%H-\%M")".log
