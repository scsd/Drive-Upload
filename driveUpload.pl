#!/usr/bin/env perl

#This will upload a user's home folder to Google Drive using the 'GAM' command
#line software (https://github.com/jay0lee/GAM).

use strict;
use warnings;
use utf8;
use Data::Dumper;
use AnyEvent;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);

#$| = 1;

#Make some vars
#Email address to send errors to.
my $address = "";
#Location of the error log.
my $errLog = "upload.err";
#Maximum amount of files to upload at a time.
my $maxUploads = 5;
#Location of the GAM script.
my $gamLoc = "/opt/GAM-3.65/gam.py";
#Location of python v2.
my $py = `which python2`; chomp $py;
#Enable verbose mode.
my $verbose = 1;
#Array to hold the commands to send to the shell.
my @cmdList;
#Holds the home directories to be synced.
my @homes;
#What user to send the files to.
my $user = "";
my $userChange = 0;
#Will hold a condition variable.
my $done;
#Holds a list of files and directories to be skipped.
my @ban = (
	qr/^[Ll]ib(rary)?$/,
	qr/^\.(\w+)?/,
	qr/\w+\.plist$/,
	qr/\w+\.dmg$/,
	qr/\w+\.app$/,
	qr/^Applications/,
	qr/^[A-Za-z]+ User Data$/,
	#qr/^Google Drive$/,
	qr/[Cc]ache/,
	qr/\w+\.cache$/,
	qr/\w+\.bin$/,
	qr/\w+\.part$/,
	qr/^Local Settings$/,
	qr/^[Pp]rofiles?$/,
	qr/^[Ff]onts$/,
	qr/^[Mm]icrosoft [Oo]ffice \d{4}$/,
	qr/^[Tt]rash$/,
	qr/RECYCLE.BIN/,
	qr/^[Mm]etadata$/,
	qr/\w+\.download$/,
	qr/\w+\.pictClipping$/,
	qr/^Icon[\u{f00d}\u{00EF}]$/,
	qr/^Start Menu$/,
	qr/^(POP|IMAP)\-\w+\@(mail\.)?\w+/,
	qr/\w+\.mbox$/,
);
#Regex to remove any really bad special chars in files.
my $banSpecial = qr/[\~\$\&\\\*\!\"\`]\ ?/;



#Go through the args given and change any settings specified by the user and
#build the list of users to upload. Don't forget to add a description for any
#new options that are added to this list into the 'dispHelp' function.
&dispHelp() if (@ARGV < 1);

while (@ARGV) {
	#Print help message.
	if ($ARGV[0] =~ m/^--?h(elp)?/i) {&dispHelp(); exit 0;}

	#Disable verbose output.
	elsif ($ARGV[0] =~ m/^--?q(uiet)?/i) {shift; $verbose = 0;}

	#Set a folder to go to a specific username.
	elsif ($ARGV[0] =~ m/^--?u(ser)?/i) {shift; $user = shift; $userChange = 1; }

	#Set the max number of files to upload.
	elsif ($ARGV[0] =~ m/^--?m(ax)?/i) {shift; $maxUploads = shift // $maxUploads;}

	#Set the email address to send errors to.
	elsif ($ARGV[0] =~ m/^--?a(ddress)?/i) {shift; $address = shift // $address;}

	#Set the location of the log file.
	elsif ($ARGV[0] =~ m/^--?e(rror)?/i) {shift; $errLog = shift // $errLog;}

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
	print "User = $user\n";
	if (! $user and $userChange) {
		print "Changing user.\n";
		my @tmp = split '/', $home;
		my $i = 0;
		$user = $tmp[--$i] while (!$user);
	}


	#Check if the user exists. If the user does not exist, skip them.
	if (! userExists( $user )) {
		err(0, "'$user' is not a valid user. Skipping...\n");
		$user = "" unless ($userChange);
		++$fin;
		next;
	}

	#Print out the user's name for logging.
	print "Uploading folder $home to user $user.\n";

	#Make a folder in the user's Google Drive account called 'Import-[date]'.
	#Place the user's files inside of this directory.
	my $importFolder = "Import-" . `date "+%F"`;
	my $out = `$py $gamLoc user $user\@sgate.k12.mi.us add drivefile drivefilename "$importFolder" mimetype gfolder 2>>"$errLog"`;
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
	$done = AnyEvent->condvar;

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
		my $cmd;
		$cmd = shift(@cmdList) while (@cmdList && not $cmd);
		return unless $cmd;

		my $pid = fork;
		if ($pid) {
			++$count;
			$done->begin;
			my $i = nextUndef(@$watchers);
			$watchers->[$i] = AnyEvent->child(
				pid => $pid,
				cb  => sub {
					--$count;
					runUpload($watchers);
					$done->end;
					undef $watchers->[$i];
				}
			);

		}
		elsif (defined $pid) {
			system("$cmd");
			my ($code) = ($?);
			if ($code != 0) {
				#Get the name of the file.
				my $file = $1 if ($cmd =~ m/localfile \"(.*)\" parentid/);
				#Figure out what went wrong.
				my $error = "";
				if (! -e $file) {$error = "File does not exist.";}
				elsif (! -r $file) {$error = "Cannot read file.";}
				elsif (-z $file) {$error = "File is empty.";}
				elsif (-l $file) {$error = "File is a symbolic link.";}
				elsif (-t $file) {$error = "The file handle is open.";}
				else {$error = "Unknown error. File possibly is locked."}
				err(1, "Cannot upload '$file': $error");
			}
			exit;
		}
		else {
			err(1, "Nope.  :/");
		}
	}

	#Clear out the condvar.
	undef $done;
	$user = "" unless ($userChange);

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
	-q | --quiet	This option will make the script output very little text,
					instead of everything that it is doing.
	-u | --user		Set the folders to go to a specific user instead of the
					name of the home directory.
	-m | --max		The max number of files to upload at one time. The default
					is currently $maxUploads.
	-a | --address	Email address to send error messages to.
	-e | --error	Set the file to save errors to.

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

	#Get the date and time.
	my $dt = `date "+%Y/%m/%d %H:%M:%S"`;
	chomp $dt;

	#Message to print.
	my $msg = "$dt - [ERROR] $in\n";

	#Make/Open the log file.
	#system("touch $errLog");
	open(my $FH, ">>", $errLog) or die "Cannot open the error file '$errLog'";

	#Place everything given into the log file.
	print $FH "$msg";

	#Close the log file.
	close($FH) or die "Cannot close error log.";

	if ($address) {
		#Send an email of the log to the address specified.
		#Write the contents of the email.
		my $email = Email::MIME->create(
			header_str	=> [
				From	=> 'driveupload@localhost',
				To		=> $address,
				Subject	=> 'Upload script error'
			],
			attributes	=> {
    			encoding	=> 'quoted-printable',
    			charset		=> 'UTF-8',
  			},
			body_str	=> $msg
		);

		#Send the email.
		sendmail($email);
	}

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
	if ($file =~ s/$banSpecial/-/g) {
		my $newLoc;
		my @tmp = split '/', $loc;
		pop @tmp;
		push @tmp, $file;
		$newLoc = join('/', @tmp);
		rename "$loc", "$newLoc";
		$loc = $newLoc;
	}

	#Determine if the file to upload is a file or dir.
	if ((-f $loc) and (! -l $loc)) {
		#This item is a file.

		#Add this to the list of commands to run.
		print "Adding file '$file'\n" if $verbose;
		push(@cmdList, "$py $gamLoc user $user\@sgate.k12.mi.us add drivefile localfile \"$loc\" parentid $id 2>>\"$errLog\"" . quietCmd());
	}
	elsif (-d $loc) {
		#The item is a directory.

		#Make the folder an store the output (should look like:
		#'Successfully created drive file/folder ID
		##0B5Jqy92NKCfIYkV3MGw2SFoyNzQ').
		print "Making folder '$file'\n" if $verbose;
		my $out = `$py $gamLoc user $user\@sgate.k12.mi.us add drivefile drivefilename \"$file\" mimetype gfolder parentid $id 2>>"$errLog"`;
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
		err(0, "File given to upload, '$loc', is neither a file nor a directory.");
	}

	return 42; #return true
}
