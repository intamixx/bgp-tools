#! /usr/bin/perl -w
###
### Perl Script to generate AS-Paths from Looking Glass RIPE Data
###
### USAGE
##       perl cnic_looking_glass.pl [PREFIX]
#
### REQUIRED MODULES FROM CPAN
##	JSON::PP
## 	LWP::UserAgent
#

use strict;
use warnings;
use JSON::PP;
use LWP::UserAgent;
# USE ONLY FOR DEBUG : 
#use Data::Dumper;

# Sub procedure to get data from RIPE-NCC DC 
# REFERENCES :: https://stat.ripe.net/docs/data_api
# Support :
# 	[0] = AS NUM
# 	[1] = QUERY 
# Return : 
# 	JSON ENCODED CONTENT
sub get_ripe_data {
	
	my $json = undef;
	my $as_prefix = shift;
	my $query = shift;
	my $ripe_data_url = "https://stat.ripe.net/data/" . $query . "/data.json?resource=".$as_prefix;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	my $response = $ua->get("$ripe_data_url");
 
	if ($response->is_success) {
		return $response->decoded_content;		
	}
	else {
		die $response->status_line;
	}
}

# Sub procedure to parse AS-paths from JSON RIPE-NCC API 
sub parse_looking_glass {
	
	my $json_rtn = shift;
        my $json_pp = JSON::PP->new;
	
	# Decode the content 
	my $data = $json_pp->decode($json_rtn);

        my $as_name = undef;

	#print "\n$json_rtn\n";

	foreach my $RRC (%{$data->{'data'}->{'rrcs'}}) {

	        if ( defined ($data->{'data'}->{'rrcs'}->{$RRC}->{'location'}) ) {
			my $location = $data->{'data'}->{'rrcs'}->{$RRC}->{'location'};
			print "\nLocation: $location\n";
		}

		my $i = 0;
		while ($data->{'data'}->{'rrcs'}->{$RRC}->{'entries'}[$i]) {
		        if ( defined ($data->{'data'}->{'rrcs'}->{$RRC}) ) {
				my $update_from = $data->{'data'}->{'rrcs'}->{$RRC}->{'entries'}[$i]->{'update_from'};
				my $as_path = $data->{'data'}->{'rrcs'}->{$RRC}->{'entries'}[$i]->{'as_path'};
				print "Update From: $update_from\tAS Path: $as_path\n";
			}
		$i++;
		}
	}
	
}

# Sub procedure to parse prefix overview from JSON RIPE-NCC API 
sub parse_pfx_overview {

        my $json_rtn = shift;
        my $json_pp = JSON::PP->new;

        # Decode the content
        my $data = $json_pp->decode($json_rtn);
        my $as_name = undef;
        my $asn = undef;
        my $as_id = undef;
        my $i = 0;

        	if ( defined ($data->{'data'}->{'asns'}[$i]) ) {
			$as_name->{'raw'} = $data->{'data'}->{'asns'}[$i]->{'holder'};
			$asn->{'raw'} = $data->{'data'}->{'asns'}[$i]->{'asn'};
			print "$as_name->{'raw'} AS$asn->{'raw'}\n";
       		 }
}

## START MAIN PROGRAM ##

# MAIN PROGRAM VARIABLES
my $as_prefix = undef;
my $as_num = undef;
my $as_pfx_overview = undef;
my $as_looking_glass = undef;
my $as_holder = undef;
my $index_pfx = 0;

	if (!@ARGV) {
		die "Please enter a prefix address\n";
		exit;
		}

# Test if argument 0 (first) is integer / decimal
if ( ( $ARGV[0] =~ /^\d+.\d+.\d+.\d+$/ ) || ( $ARGV[0] =~ /^(((?=(?>.*?::)(?!.*::)))(::)?([0-9A-F]{1,4}::?){0,5}|([0-9A-F]{1,4}:){6})(\2([0-9A-F]{1,4}(::?|$)){0,2}|((25[0-5]|(2[0-4]|1[0-9]|[1-9])?[0-9])(\.|$)){4}|[0-9A-F]{1,4}:[0-9A-F]{1,4})(?<![^:]:)(?<!\.)\z/i ) ) {
	# If it is, then fill $as_num and launch sub procedures
	my $as_prefix = $ARGV[0];

	# Get the full ordered list of AS paths for prefix
	$as_pfx_overview = &parse_pfx_overview( &get_ripe_data( $as_prefix, 'prefix-overview' ) );
	$as_looking_glass = &parse_looking_glass( &get_ripe_data( $as_prefix, 'looking-glass' ) );

	print "\r\n";
} else {
	die "Need Prefix in numeric mode only\r\n";
}
