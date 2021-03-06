# Drive-Upload
Script to send a user's home directory to Google Drive.

## Installation Notes
### GAM
This script uses the [GAM](https://github.com/jay0lee/GAM) software to upload the files and to check for users. This software **must** be installed first and be working before this script will do anything. There is a variable at the top of the script of where it thinks it should be.

### AnyEvent
This script also requires the [AnyEvent](https://metacpan.org/pod/AnyEvent) Perl module to work. This module is used for running multiple GAM uploads at a time.

### Variable Configuration
The top half of the script consists of configuration items and default values for variables. Most of these have an option to set them on the command line, but some do not. The variables that do not have a command line setting and that may need to configured based on preference/restrictions is the variable(s):
* `$gamLoc` - The location of the `gam.py` file in the GAM installation

### Testing
This script has a directory called 't' that stores tests for the script. If you would like to use these scripts, please change the variables found inside of the file called 'config'. Run the script 'bench.sh' to begin the tests, and an email report should be sent to the address listed in the 'config' file.
The options for the `config` file are in bash variable format and are as follows:

* `loc` - The folder that should be used for testing. This folder should have a fair amount of files in it (or however many you would like to test with), and will be uploaded to the user account that is specified.
* `user` - The user that should be used for testing. This user will have files and folders sent to it from the dir specified by the `loc` variable.
* `address` - The email address that the results and errors should be emailed to.
* `uploads` - The amount of uploads that should be run at once.

## Usage
USAGE: `./driveUpload.pl [OPTIONS] [HOMES]`

### Options
* `-h | --help` - Using this option will display a short help message similar to this.
* `-q | --quiet` - This option will make the script output very little text, instead of everything that it is doing.
* `-u | --user` - Option to have the folders to go to a specific user instead of the owner of the home directory.
* `-m | --max` - Sets the max number of files to upload at one time.
* `-a | --address` - This option will set the email address that error logs should send messages to. If left blank, no emails will be sent.
* `-e | --error` - Using this option will set the location of the error log.

### Home Directories
This is a list of all of the directories that will be uploaded to Google drive. If any files are passed, this script will skip them. For example, if I passed `/dir/dummy_dir` and `/dir/file.txt` to the script, the directory `/dir/dummy_dir` will be uploaded and `/dir/file.txt` will be skipped. Because of how this script handles directories, this script can actually be used to upload a directory (and any files within) to a person's Google Drive account, while maintaining the file structure.
