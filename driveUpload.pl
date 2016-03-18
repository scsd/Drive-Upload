#!/usr/bin/env perl

#This will upload a user's home folder to Google Drive using the 'GAM' command
#line software (https://github.com/jay0lee/GAM).

use strict;
use warnings;
use Data::Dumper;



#Make some vars
my @homes;			#Holds the home directories to be synced.
my $user;
my @ban = (			#Holds a list of files and directories to be skipped.
	qr/^Library/,
	qr/^\.(\w+)?/,
	qr/\w+\.plist/,
	qr/\w+\.dmg/,
	qr/\w+\.app/
);



#Go through the args given and change any settings specified by the user and
#build the list of users to upload. Don't forget to add a description for any
#new options that are added to this list into the 'dispHelp' function.
&dispHelp() if (@ARGV < 1);

while (@ARGV) {
	#Print help message.
	if ($ARGV[0] =~ m/^--?h(elp)?/i) {&dispHelp(); exit 0;}
	
	#Set a folder to go to a specific username.
	if ($ARGV[0] =~ m/^--?u(ser)?/i) {shift; $user = shift;}
	
	
	#Invaild argument
	elsif ($ARGV[0] =~ m/^(--?\w+)/i) {die "'$1' if not a valid option\n";}
	
	#This should be a user.
	else {
		#Check if the item passed is a directory.
		if (-f $ARGV[0]) {
			print "'" . shift . "' is a file, skipping...\n";
		}
		else {
			#Add arg to the 'homes' list.
			push @homes, shift;
		}
	}
}



#Now that the user homes have been listed, all that needs to be done is to send
#the user's account into Google Drive.
my $count = 1;
foreach my $home (@homes) {
	#Check if the 'user' variable is set. If not, set it to the user assosciaded
	#with the current home directory.
	if (! $user) {
		my @tmp = split '/', $home;
		my $i = 0;
		$user = $tmp[--$i] while (!$user);
	}
	
	
	#Check if the user exists. If the user does not exist, skip them.
	if (! userExists( $user )) {
		print "'$user' is not a valid user. Skipping...\n";
		next;
	}
	
	#Print out the user's name for logging.
	print "Uploading folder $home to user $user.\n";
	
	#Make a folder in the user's Google Drive account called 'Import-[date]'.
	#Place the user's files inside of this directory.
	my $importFolder = "Import-" . `date "+%F"`;
	my $out = `python /opt/GAM-3.63/gam.py user $user\@sgate.k12.mi.us add drivefile drivefilename "$importFolder" mimetype gfolder`;
	chomp $out;
	my $id = (split ' ', $out)[-1];
	&upload($id, $home, $user);
	
	#Display the percentage of homes moved.
	print ((($count / @homes) * 100) . "% completed...\n");
	++$count;
}






###########################################
#Function Section
###########################################

#Make help message for when I forget.
sub dispHelp {
	print <<END_HELP;

USAGE: $0 [OPTIONS] [HOMES]

OPTIONS:
	-h | --help		This help message.
	-u | --user		Set the folders to go to a specific user instead of the
					name of the home directory.

HOMES:
	The home directories of the user's that you want to have moved to Google
	Drive. This assumes that the name of the home directory matches the	name
	of the user's Google Drive account.

END_HELP
}




#Determine if a specified user exists.
sub userExists {
	#Get the user
	my ($name) = @_;
	my $ret = 0;
	
	#Run GAM and try to get the user's info.
	my $out = `python /opt/GAM-3.63/gam.py info user $name\@sgate.k12.mi.us userview 2>&1`;
	
	#Look for the word 'error' in the output. If it is in there, the value
	#returned will be true.
	my $err = index( lc($out) , "error") + 1;
	
	if ( $err ) {
		$ret = 0;
	}
	else {
		$ret = "exists";
	}
	
	return $ret; #Return a true or false.
}




#Recursive function to upload a file or folder to google drive.
sub upload {
	#Get the parent ID, and the loaction of the file to upload.
	my $id =	shift || die "No parent ID given in upload function.";
	my $loc =	shift || die "No file given to upload for upload function.";
	my $user =    shift || die "No user account given for upload function.";
	
	#Seperate the filename from the location path
	my $file = (split '/', $loc)[-1];
	
	#Skip files that match something in the ban list. Exit if it does.
	for my $regex (@ban) {
		if ($file =~ $regex) {
			return 0;	#Return a false.
		}
	}
	
	print "Uploading file '$file'\n";
	
	#Determine if the file to upload is a file or dir.
	if (-f $loc) {
		#This item is a file.
		
		#Replace all of the spaces with underscores.
		
		#Upload this file to the user's Google Drive.
		`python /opt/GAM-3.63/gam.py user $user\@sgate.k12.mi.us add drivefile localfile "$loc" parentid $id`;
	}
	elsif (-d $loc) {
		#The item is a directory.
		
		#Make the folder an store the output (should look like:
		#'Successfully created drive file/folder ID
		##0B5Jqy92NKCfIYkV3MGw2SFoyNzQ').
		my $out = `python /opt/GAM-3.63/gam.py user $user\@sgate.k12.mi.us add drivefile drivefilename "$file" mimetype gfolder parentid $id`;
		chomp $out;
		my $newid = (split ' ', $out)[-1];
		
		#Open the directory, and for each item inside, make the Google
	    #Drive folder for it, and call this function again.
		opendir(my $DIR, $loc) || die "Cannot open the folder at $loc";
		
		while ( my $dirfile = readdir($DIR) ) {
			#Recall the script using the items in the directory.
			&upload($newid, "$loc/$dirfile", $user);
		}
		
		closedir($DIR);
	}
	else {
		#None
		die "File given to upload, '$loc', is neither a file nor a directory.";
	}
	
	return 42; #return true
}

