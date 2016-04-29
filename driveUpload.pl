#!/usr/bin/env perl

#This will upload a user's home folder to Google Drive using the 'GAM' command
#line software (https://github.com/jay0lee/GAM).

use strict;
use warnings;
use utf8;
use Data::Dumper;
use AnyEvent;

$| = 1;

#Make some vars
my $errLog = "/home/nic/upload.err";
my $maxUploads = 5;
my $gamLoc = "/opt/GAM-3.65/gam.py";
my $py = `which python2`; chomp $py;
my $verbose = 0;
my @cmdList;
my @homes;		#Holds the home directories to be synced.
my $user;
my @ban = (		#Holds a list of files and directories to be skipped.
	qr/^[Ll]ib(rary)?$/,
	qr/^\.(\w+)?/,
	qr/\w+\.plist$/,
	qr/\w+\.dmg$/,
	qr/\w+\.app$/,
	qr/^Applications$/,
	qr/^[A-Za-z]+ User Data$/,
	qr/^Google Drive$/,
	qr/^[Cc]ache$/,
	qr/\w+\.cache$/,
	qr/\w+\.bin$/,
	qr/\w+\.part$/,
);
my $banSpecial = qr/[\~\$\&\\\*\!\"]\ ?/;



#Go through the args given and change any settings specified by the user and
#build the list of users to upload. Don't forget to add a description for any
#new options that are added to this list into the 'dispHelp' function.
&dispHelp() if (@ARGV < 1);

while (@ARGV) {
	#Print help message.
	if ($ARGV[0] =~ m/^--?h(elp)?/i) {&dispHelp(); exit 0;}

	#Enable verbose output.
	elsif ($ARGV[0] =~ m/^--?v(erbose)?/i) {shift; $verbose = 1;}

	#Set a folder to go to a specific username.
	elsif ($ARGV[0] =~ m/^--?u(ser)?/i) {shift; $user = shift;}

	#Set the max number of files to upload.
	elsif ($ARGV[0] =~ m/^--?m(ax)?/i) {shift; $maxUploads = shift;}

	#Invaild argument
	elsif ($ARGV[0] =~ m/^(--?\w+)/i) {err(1, "'$1' is not a valid option\n");}

	#This should be a user.
	else {
		#Check if the item passed is a directory.
		if (-f $ARGV[0]) {
			err(0, "'" . shift . "' is a file, skipping...\n");
		}
		else {
			#Add arg to the 'homes' list.
			push @homes, shift;
		}
	}
}



#Now that the user homes have been listed, all that needs to be done is to send
#the user's account into Google Drive.
my $fin = 1;
foreach my $home (@homes) {
	#Check if the 'user' variable is set. If not, set it to the user assosciated
	#with the current home directory.
	if (! $user) {
		my @tmp = split '/', $home;
		my $i = 0;
		$user = $tmp[--$i] while (!$user);
	}


	#Check if the user exists. If the user does not exist, skip them.
	if (! userExists( $user )) {
		err(0, "'$user' is not a valid user. Skipping...\n");
		next;
	}

	#Print out the user's name for logging.
	print "Uploading folder $home to user $user.\n";

	#Make a folder in the user's Google Drive account called 'Import-[date]'.
	#Place the user's files inside of this directory.
	my $importFolder = "Import-" . `date "+%F"`;
	my $out = `$py $gamLoc user $user\@sgate.k12.mi.us add drivefile drivefilename "$importFolder" mimetype gfolder`;
	chomp $out;
	my $id = (split ' ', $out)[-1];
	upload(
		id		=> $id,
		loc		=> $home,
		user	=> $user
	);


	#Run the list of commands that have been collected into the '@cmdList'
	#array. These are all of the commands to upload files to Google Drive.

	my $count = 0;
	my @watchers;
	my $done = AnyEvent->condvar;

	#Start the count incase there are no folders to upload.
	$done->begin;
	for (1 .. $maxUploads) {
		runUpload(\@watchers);
	}
	#End the count.
	$done->end;

	$done->recv;

	sub runUpload {
		my $watchers = shift;
		#Make sure that no more than the max number run.
		return if $count >= $maxUploads;
		#Get the next command, until the list is depleated
		my $cmd = shift @cmdList;
		return if not $cmd;

		my $pid = fork;
		if ($pid) {
			++$count;
			$done->begin;
			my $i = nextUndef(@$watchers);
			$watchers->[$i] = AnyEvent->child(
				pid => $pid,
				cb  => sub {
					--$count;
					$done->end;
					runUpload($watchers);
					undef $watchers->[$i];
				}
			);
		}
		elsif (defined $pid) {
			exec("$cmd");
			die "Cannot exec '$cmd': $!\n";
		}
		else {
			die "Nope.  :/";
		}
	}



	#Display the percentage of homes moved.
	print ((($fin / @homes) * 100) . "% completed...\n\n");
	++$fin;
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
	-v | --verbose	Display everything that is being done by the script.
	-u | --user		Set the folders to go to a specific user instead of the
					name of the home directory.
	-m | --max		The max number of files to upload at one time. The default
					is currently $maxUploads.

HOMES:
	The home directories of the user's that you want to have moved to Google
	Drive. This assumes that the name of the home directory matches the	name
	of the user's Google Drive account.

GAM Location:
	The variable \$gamLoc is a link to the location of where the 'gam.py' file
	is located in your file directory. This must be changed if it moves or is
	incorrect. It is currently set to $gamLoc'.

Error Log:
	The error log is set to be '$errLog', but this can be changed in this
	file. All errors that the script finds should be written to this file.

END_HELP
}


#Function to return the next undefined variable in an array.
sub nextUndef {
	my @a = @_;
	my $i = 0;
	while (++$i) {
		unless (defined $a[$i]) {
			return $i;
		}
	}
}


sub quietCmd {
	if ($verbose) {return '';}
	else {return ' >/dev/null';}
}


#Function to write errors to to a log file with a date.
sub err {
	my $fatal = shift;
	my $in = join (', ', @_);

	#Make/Open the log file.
	system("touch $errLog");
	open(my $ERR, '>>', $errLog) or die "Cannot open the error file '$errLog'";

	#Get the date and time.
	my $dt = `date "+%Y/%m/%d %H:%M:%S"`;
	chomp $dt;

	#Message to print.
	my $msg = "$dt $in\n";

	#Place everything given into the log file.
	print $ERR "$msg";

	#Close the log file.
	close $ERR;

	if ($fatal) {
		die "$msg";
	}
	else {
		print STDERR "$msg";
	}
}



#Determine if a specified user exists.
sub userExists {
	#Get the user
	my ($name) = @_;
	my $ret = 0;

	#Run GAM and try to get the user's info.
	my $out = `$py $gamLoc info user $name\@sgate.k12.mi.us userview 2>&1`;

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
	#Get arguments.
	my %info = @_;

	#Get the parent ID, and the loaction of the file to upload.
	my $id =	$info{'id'}		|| err(1, "No parent ID given in upload function.");
	my $loc =	$info{'loc'}	|| err(1, "No file given to upload for upload function.");
	my $user =	$info{'user'}	|| err(1, "No user account given for upload function.");

	#Seperate the filename from the location path
	my $file = (split '/', $loc)[-1];

	#Skip files that match something in the ban list. Exit if it does.
	for my $regex (@ban) {
		if ($file =~ $regex) {
			return 0;	#Return a false.
		}
	}

	#Rename any files that will cause an error when uploading.
	if ($file =~ s/$banSpecial//g) {
		my $newLoc;
		my @tmp = split '/', $loc;
		pop @tmp;
		push @tmp, $file;
		$newLoc = join('/', @tmp);
		rename "$loc", "$newLoc";
		$loc = $newLoc;
	}

	#Determine if the file to upload is a file or dir.
	if (-f $loc) {
		#This item is a file.

		#Add this to the list of commands to run.
		print "Adding file '$file'\n" if $verbose;
		push(@cmdList, "$py $gamLoc user $user\@sgate.k12.mi.us add drivefile localfile \"$loc\" parentid $id" . quietCmd());
	}
	elsif (-d $loc) {
		#The item is a directory.

		#Make the folder an store the output (should look like:
		#'Successfully created drive file/folder ID
		##0B5Jqy92NKCfIYkV3MGw2SFoyNzQ').
		print "Making folder '$file'\n" if $verbose;
		my $out = `$py $gamLoc user $user\@sgate.k12.mi.us add drivefile drivefilename \"$file\" mimetype gfolder parentid $id`;
		chomp $out;
		my $newid = (split ' ', $out)[-1];

		#Open the directory, and for each item inside, make the Google
	    #Drive folder for it, and call this function again.
		opendir(my $DIR, $loc) || err(1, "Cannot open the folder at $loc");

		while ( my $dirfile = readdir($DIR) ) {
			#Recall the script using the items in the directory.
			upload(
				id		=> $newid,
				loc		=> "$loc/$dirfile",
				user	=> $user
			);
		}

		closedir($DIR);
	}
	else {
		#None
		err(1, "File given to upload, '$loc', is neither a file nor a directory.");
	}

	return 42; #return true
}
