#!/usr/bin/perl
#
# Primative config management (with little error handling).
#  - reads in YAML config file
#  - expects to install packages, update webroot, install configs, start services
#

use strict;
use warnings;
use YAML::XS 'LoadFile';
use Data::Dumper;
use feature 'say';

use Getopt::Long;
use Net::OpenSSH;

use File::Temp;

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

	say "  [] [CLONE WEBROOT] cd $webroot" if $verbose;
	print $fh "cd $webroot\n";
	say "  [] [CLONE WEBROOT] git clone $repourl" if $verbose;
	print $fh "git clone $repourl\n";

}

sub do_start_services {
	# cheat a little here, stop service, start service
	# - ideally it's be more like Ansible's state=restarted *if* needed
	print $fh "service $_ stop\n";
	print $fh "service $_ start\n";
	say "  [] [START] service $_ stop/start" if $verbose;
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

sub do_copy_configs {
	# scp file
	my ($src, $dest) = @_;

}

###
# main
###

# setup some default variables
my $configFile = "config.yml";
my $ssh_user = "root";
my $ssh_pass;
$verbose = 0;

# pull in command line args
GetOptions (
	"verbose"	=> \$verbose,
	"config"	=> \$configFile,
	"password"	=> \$ssh_pass,
	"username"	=> \$ssh_user,
) or die ("Error in command line arguments\n");


my $config = LoadFile($configFile);
my $outFile = get_temp_filename();

say " [VERBOSE] Writing output script => $outFile" if $verbose;

# open a filehandle for writing
$fh = IO::File->new("$outFile", 'w') or die "Failed to create $outFile: $!";

# install packages
for (@{$config->{packages}}) {
	do_install_packages($_);
}

# update webroot
say " [VERBOSE] Calling: clonewebroot with: $config->{webroot}, $config->{repourl} ";
do_clonewebroot($config->{webroot}, $config->{repourl});

# update nginx config files
# - To-do: templated config files
# - To-do: allow for more than one statically configured config files
#do_copy_configs(@config->nginxconfig);
#do_copy_configs($config->{webroot}, $config->{repourl});

# start/restart services
for (@{$config->{services}}) {
	do_start_services($_);
}

# close our file.
close $fh;
