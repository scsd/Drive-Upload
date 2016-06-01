# Drive-Upload
Script to send a user's home directory to Google Drive.

## Installation Notes
###GAM
This script uses the [GAM](https://github.com/jay0lee/GAM) software to upload the files and to check for users. This software **must** be installed first and be working before this script will do anything. There is a variable at the top of the script of where it thinks it should be.

###AnyEvent
This script also requires the [AnyEvent](https://metacpan.org/pod/AnyEvent) Perl module to work. This module is used for running multiple GAM uploads at a time.

###Variable Configuration
The top half of the script consists of configuration items and default values for variables. Most of these have an option to set them on the command line, but some do not. The two that do not and that may need to configured based on preference/restrictions are the variables:
* `$errLog` - The location to write the error logs
* `$gamLoc` - The location of the `gam.py` file in the GAM installation

###Testing
This script has a directory called 't' that stores tests for the script. If you would like to use these scripts, please change the variables found inside of the file called 'config'. Run the script 'bench.sh' to begin the tests, and an email report should be sent to the address listed in the 'config' file.

## Usage
USAGE: `./driveUpload.pl [OPTIONS] [HOMES]`

###Options
* `-h | --help` - Using this option will display a short help message similar to this.
* `-q | --quiet` - This option will make the script output very little text, instead of everything that it is doing.
* `-u | --user` - Option to have the folders to go to a specific user instead of the owner of the home directory.
* `-m | --max` - Sets the max number of files to upload at one time.
* `-a | --address` - This option will set the email address that error logs should send messages to. If left blank, no emails will be sent.

###Home Directories
This is a list of all of the directories that will be uploaded to Google drive. If any files are passed, this script will skip them. For example, if I passed `/dir/dummy_dir` and `/dir/file.txt` to the script, the directory `/dir/dummy_dir` will be uploaded and `/dir/file.txt` will be skipped. Because of how this script handles directories, this script can actually be used to upload a directory (and any files within) to a person's Google Drive account, while maintaining the file structure.
