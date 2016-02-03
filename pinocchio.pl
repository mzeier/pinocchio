#!/usr/bin/perl
#
# Primative config management (with little error handling).
#  - reads in YAML config file
#  - expects to install packages, update webroot, install configs, start services
#
# To-do:
# - only push config files if necessary (md5sum src/dest files?)
# - templated files, especially nginx configs
# - no error handling - assumes specific input YAML, changes here will likely break all the things


use strict;
use warnings;
use YAML::XS 'LoadFile';
use Data::Dumper;
use feature 'say';

use Getopt::Long;
use Net::OpenSSH;

use File::Temp;

# be lazy & treat these as globally scoped variables.
use vars qw( $outFile $fh $verbose);

sub do_install_packages {
	# apt-get packages.
	# - To-do: perhaps concatinate all packages to a single line
	print $fh "apt-get -y install $_\n";
	say "  [] [PACKAGES] apt-get -y install $_" if $verbose;
}

sub do_clonewebroot {
	# do a local git clone/git pull to update web content
	my ($webroot, $repourl) = @_;

	say "  [] [CLONE WEBROOT] git clone/pull $repourl" if $verbose;

	# catch when this is a fresh host & clone repourl
	print $fh "\nif [ ! -d \"$webroot/pinocchio-web\" ]; then\n";
	print $fh " cd $webroot\n";
	print $fh " git clone $repourl\n";
	print $fh "fi\n";

	# To-do: better way to do this?
	print $fh "cd $webroot/pinocchio-web\n";
	print $fh "git pull\n";
	print $fh "\n";

}

sub do_start_services {
	# cheat a little here, stop service, start service
	# - ideally it's be more like Ansible's state=restarted
	print $fh "service $_ stop\n";
	print $fh "service $_ start\n";
	say "  [] [START] service $_ stop/start" if $verbose;
}

sub do_update_iptables {

	# this begs for a better iptables module. This is quick and dirty for now.
	# - dirty: iptables willing adds duplicate entries!
	print $fh "iptables -D INPUT -p tcp --dport 80 -j DROP\n"
	print $fh "iptables -A INPUT -p tcp --dport 80 -j ACCEPT\n";

}

sub get_temp_filename {
	# generate temporary filename
	# - use this to build the shell script that will be copied to the remote host
	my $tmpfh = File::Temp->new(
		TEMPLATE => 'pinocchio-XXXXX',
		DIR	 => '/tmp/',
		SUFFIX	 => '.tmp',
	);
	return $tmpfh->filename;
}

###########################
# main
###########################

# setup some default variables
my $configFile = "config.yml";
my $ssh_user = "root";
my $ssh_pass;
$verbose = 0;

# pull in command line args
GetOptions (
	"verbose"	=> \$verbose,
	"config=s"	=> \$configFile,
	"password=s"	=> \$ssh_pass,
	"username=s"	=> \$ssh_user,
) or die ("Error in command line arguments\n");


my $config = LoadFile($configFile);
my $outFile = get_temp_filename();

say " [VERBOSE] Writing output script => $outFile" if $verbose;

# open a filehandle for writing
$fh = IO::File->new("$outFile", 'w') or die "Failed to create $outFile: $!";

# init the script
print $fh "#!/bin/bash\n\n";
print $fh "export DEBIAN_FRONTEND=noninteractive\n";


# install packages
for (@{$config->{packages}}) {
	do_install_packages($_);
}

# open up iptables
do_update_iptables();

# update webroot
say " [VERBOSE] Calling: clonewebroot with: $config->{webroot}, $config->{repourl} ";
do_clonewebroot($config->{webroot}, $config->{repourl});


# start/restart services
say " [VERBOSE] Calling: stop/start services ";
for (@{$config->{services}}) {
	do_start_services($_);
}

# close our file.
close $fh;

#
# In this for-loop, we do the following:
# - open ssh to remote hosts
# - scp config files
# - scp $outFile remote:$outFile
# - exec $outFile
# - rm $outFile
for (@{$config->{hosts}}) {
	my $ssh = Net::OpenSSH->new(
		$_,
		user => $ssh_user,
		password => $ssh_pass,
		timeout => 60,
		master_opts => [-o => "StrictHostKeyChecking=no"]);

		$ssh->error and die "Unable to connect to remote host: " . $ssh->error;
		say "  [] [ssh] Connecting: $ssh_user\@$_" if $verbose;

		# Preflight. Ideally make this a function but do it inline for now.
		# - do we have disk space?
		# -- for now, care only about / and assume we need > 100MB
		say "  [] [ssh] Preflight check: disk space > 100M" if $verbose;
		my $preflight = $ssh->capture2("df -m --output=avail /") or die "command failed: " . $ssh->error . "\n";
		# strip out the 'df' header and newline.
		$preflight =~ s/Avail\s+//;
		$preflight =~ s/\n//;
		if ($preflight < 100) {
			say "FATAL ERROR: Insufficient disk space: host $_ ($preflight MB free)";
		} else {

			# force /etc/resolv.conf to be sane - in a better world this would be
			#  a "common" role/set of tasks
			# - takes some assumptions that 'resolvconf -u' will work
			say "  [] [resolv.conf] Updating /etc/resolv.conf" if $verbose;
			my $resolvconf = $ssh->capture2("/sbin/resolvconf -u");

			say "  [] [ssh] Copying: scp $outFile $ssh_user\@$_:/tmp/" if $verbose;
			$ssh->scp_put($outFile, "/tmp") or die "scp failed: " . $ssh->error;

			say "  [] [ssh] Copying: scp $config->{nginxconfigsrc} -> $config->{nginxconfigdest}" if $verbose;
			my @results = $ssh->capture2("/bin/mkdir -p /etc/nginx/sites-enabled/") or die "command failed: " . $ssh->error . "\n";
			$ssh->scp_put($config->{nginxconfigsrc}, $config->{nginxconfigdest}) or die "scp failed: " . $ssh->error;

			say "  [] [ssh] Exec\'ing $outFile" if $verbose;
			@results = $ssh->capture2("/bin/bash $outFile") or die "command filed: " . $ssh->error . "\n";
			#my @results = $ssh->capture2('/bin/bash $outFile') or die "command filed: " . $ssh->error . "\n";
			say "@results" if $verbose;

		}





		# cleanup after ourselves but for this coding exercise, leave the files on disk for inspection
		#@results = $ssh->capture2("/bin/rm $outFile") or die "command filed: " . $ssh->error . "\n";

}

# cleanup after ourselves but for this coding exercise, leave the files on disk for inspection
#unlink($outFile) or warn "Could not unlink $file: $!";
