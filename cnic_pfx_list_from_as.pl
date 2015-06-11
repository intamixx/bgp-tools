#! /usr/bin/perl -w
###
### Perl Script to generate Cisco IOS-Like Prefixes List for Filtering peering on IXP
###
### USAGE
##       perl cnic_pfx_list_from_as.pl [AS_NUM]
#
### REQUIRED MODULES FROM CPAN
##	JSON::PP
## 	LWP::UserAgent
## 	Net::IP
#

use strict;
use warnings;
use JSON::PP;
use LWP::UserAgent;
use Net::IP;
# USE ONLY FOR DEBUG : 
use Data::Dumper;

# Sub procedure to get data from RIPE-NCC DC 
# REFERENCES :: https://stat.ripe.net/docs/data_api
# Support :
# 	[0] = AS NUM
# 	[1] = QUERY 
# Return : 
# 	JSON ENCODED CONTENT
sub get_ripe_data {
	
	my $json = undef;
	my $as_num = shift;
	my $query = shift;
	my $ripe_data_url = "https://stat.ripe.net/data/" . $query . "/data.json?resource=AS".$as_num;

	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);
	$ua->env_proxy;

	my $response = $ua->get("$ripe_data_url");
 
	if ($response->is_success) {
		return $response->decoded_content;		
	}
	else {
		die ("Unable to fetch " . $ripe_data_url . "\r\n Error code is : $response->status_line\r\n");
	}
}

# Sub procedure to parse AS holder from JSON RIPE-NCC API 
# REFERENCES :: https://stat.ripe.net/docs/data_api#AsOverview
# EXAMPLES   :: https://stat.ripe.net/data/as-overview/data.json?resource=AS35012
# Support :
# 	[0] = AS NUM
# 	[1] = JSON API CONTENT
# Return : 
# 	HASH->{'raw'}	 => RAW DATA from API
# 	HASH->{'format'} => STRUCTURED DATA without special characters and spaces, prefixed by AS_NUM_
sub parse_as_holder {
	
	my $as_id = shift;
	my $json_rtn = shift;
        my $json_pp = JSON::PP->new;

	# Decode the content 
	my $data = $json_pp->decode($json_rtn);
	my $as_name = undef;

	if ( defined ($data->{'data'}->{'holder'}) ) {
		$as_name->{'raw'} = $data->{'data'}->{'holder'};
		$as_name->{'format'} = "AS".$as_id."_".$data->{'data'}->{'holder'};
		$as_name->{'format'} =~ s/\s+/_/gmi;
		$as_name->{'format'} =~ s/[\W+]/_/gmi;
	} else {
		$as_name->{'raw'} = "AS NUM $as_id not found on RIPE-NCC Database";
		$as_name->{'format'} = "UNKNOWN_AS_HOLDER";
	}
	return $as_name;
}


# Sub procedure to parse AS prefixes from JSON RIPE-NCC API 
# REFERENCES :: https://stat.ripe.net/docs/data_api##AnnouncedPrefixes
# EXAMPLES   :: https://stat.ripe.net/data/as-overview/data.json?resource=AS35012
# Support :
# 	[0] = JSON API CONTENT
# Return : 
# 	HASH->{'ip6'}	=> @ARRAY of ALL IPv6 ANNOUNCED PREFIXES
# 	HASH->{'ip4'} 	=> @ARRAY of ALL IPv4 ANNOUNCED PREFIXES
sub parse_as_prefixes {
	
	my $json_rtn = shift;
        my $json_pp = JSON::PP->new;
	
	# Decode the content 
	my $data = $json_pp->decode($json_rtn);

	my $i = 0;
	my @prefix_list_ip4;
	my @prefix_list_ip6;
	my $prefix_list;

	# While we found ->prefixes lines on the JSON array
	while ($data->{'data'}->{'prefixes'}[$i]) {
		
		my $ip = new Net::IP ($data->{'data'}->{'prefixes'}[$i]->{'prefix'}) or die (Net::IP::Error());
		
		# On IPv6 version, returns simple prefix without zeros
		if ( ($ip->{'ipversion'} eq 6) && ($ip->{'is_prefix'} eq 1) ) {
			push @prefix_list_ip6, ( $ip->print() ) if defined $ip;
		}
		# On IPv4 version, returns simple prefix with zeros and suffixed by / prefix
		elsif ( ($ip->{'ipversion'} eq 4) && ($ip->{'is_prefix'} eq 1) ) {
			push @prefix_list_ip4, ( $ip->ip() . "/" . $ip->prefixlen() ) if defined $ip;
		}

		$i++;
	}

	$prefix_list->{'ip6'} = [@prefix_list_ip6];
	$prefix_list->{'ip4'} = [@prefix_list_ip4];
	return $prefix_list;

}

## START MAIN PROGRAM ##

# MAIN PROGRAM VARIABLES
my $as_num = undef;
my $as_pfx = undef;
my $as_holder = undef;
my $index_pfx = 0;

	if (!@ARGV) {
		die "Please enter an AS number\n";
		exit;
	}

# Test if argument 0 (first) is integer / decimal
if ($ARGV[0] =~ /^\d+$/) {
	# If it is, then fill $as_num and launch sub procedures
	$as_num = $ARGV[0];
	# Get the full ordered list of announced prefixes using RIPE DB, ordered by ipv4 and ipv6 
	$as_pfx = &parse_as_prefixes( &get_ripe_data( $as_num, 'announced-prefixes' ) );
	# Get the as number holder name
	$as_holder = &parse_as_holder( $as_num, &get_ripe_data( $as_num, 'as-overview' ) );

	# Start the output
	print "--------------------------------------------------------------------------------------------------------------\r\n";	
	print "AS NUMBER FOR QUERY ".$as_num."\r\n";	
	print "--------------------------------------------------------------------------------------------------------------\r\n";	
	print "AS HOLDER RESULT : \t".$as_holder->{'raw'}."\r\n";	
	print "AS HOLDER FORMATTED : \t".$as_holder->{'format'}."\r\n";	
	print "--------------------------------------------------------------------------------------------------------------\r\n";
	
	# Start the output of IPv6 prefix list in Cisco IOS like mode from 10
	print "IPv6 Prefix List for AS [$as_num]\r\n\r\n";
	print "\t ipv6 prefix-list AS-$as_num-IN-IP6 description \"IPv6 PREFIX AS_$as_num ($as_holder->{'raw'})\"\r\n";
	$index_pfx = 10;
	foreach my $pfx ( @{ $as_pfx->{'ip6'} } ) {
		print "\t ipv6 prefix-list AS-$as_num-IN-IP6 seq " . $index_pfx . " permit " . $pfx . "\r\n";
		$index_pfx++;
	}

	# Start the output of IPv4 prefix list in Cisco IOS like mode from 10
	print "\r\n--------------------------------------------------------------------------------------------------------------\r\n";	
	print "IPv4 Prefix List for AS [$as_num]\r\n\r\n";
	print "\t ip prefix-list AS-$as_num-IN-IP4 description \"IPv4 PREFIX AS-$as_num ($as_holder->{'raw'})\"\r\n";
	$index_pfx = 10;
	foreach my $pfx ( @{ $as_pfx->{'ip4'} } ) {
		print "\t ip prefix-list AS-$as_num-IN-IP4 seq " . $index_pfx . " permit " . $pfx . "\r\n";
		$index_pfx++;
	}
	
	print "\r\n";
} else {
	die "Need AS in numeric mode only\r\n";
}
