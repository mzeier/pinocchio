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

	print $fh "apt-get install $_\n";
	say "  [] [PACKAGES] apt-get install $_" if $verbose;

}

sub do_clonewebroot {

}

sub do_start_services {

}

sub get_temp_filename {

	my $tmpfh = File::Temp->new(
		TEMPLATE => 'pinocchio-XXXXX',
		DIR	 => '/tmp/',
		SUFFIX	 => '.tmp',
	);
	
	return $tmpfh->filename;
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

$fh = IO::File->new("$outFile", 'w') or die "Failed to create $outFile: $!";

for (@{$config->{packages}}) { 
	do_install_packages($_);
}


close $fh;
