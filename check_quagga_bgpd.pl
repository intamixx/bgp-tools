#!/usr/bin/perl

# Msingh
# Script to monitor the quagga bgpd daemon via Check_MK
# check_quagga_bgpd is a perl script that connects to the running bgpd, parses the config, lists the BGP peers,
# checks on their status (both IPv4 and IPv6) 

use strict;
use warnings;

my $servicename="BGP_Peer_Connect";
my $badpeers = [];
my @pre;
my $i;

my $cmd = "vtysh -c 'show ip bgp summary'";

                if (!open(CMD, $cmd.' 2>&1|')) {
                        #_error("Error executing command: $!");
                } else {
                        while (<CMD>) {
                                chomp;
                                next if ($_ eq '');
                                push( @{pre}, $_ );
                        }
                close(CMD);
                if ($? > 0) {
                        printf("2 %s - CRITICAL - Connect Failure to Quagga\n", $servicename);
                        exit 2;
                        }
                }

my @res = &parsebgpsum(@pre);

        if ( scalar(@res) == 0 ) {
                printf("2 %s - CRITICAL - BGP stopped / Missing Peer Config\n", $servicename);
                exit 1;
                } else {
                        foreach $i (@res) {
                                if ( $i =~ /(\S+) (\S+) (\S+) (\d+)/ ) {
                                # Peer OK
                                } elsif ( $i =~ /(\S+) (\S+) (\S+) (\w+)/ ) {
                                        push(@{$badpeers}, "ip:$1 as:$2" );
                                } else {
                                push(@{$badpeers}, "Unknown Peer" );
                                }
                        }
                }

        if (scalar(@{$badpeers}) > 0) {
                $badpeers = join (" ", map { $_ } @{$badpeers});
                printf ("1 %s - WARNING - BGP Peer Failure: %s\n", $servicename, $badpeers);
                exit 1;
        } else {
                printf ("0 %s - OK - BGP Peers Established\n", $servicename);
                exit 0;
        }

########################################

sub parsebgpsum {
    my(@pre)= @_;

    my($ip,$as,$upt,$pfx);
    my($off, $t);
    my($res)='';
    my($mode)='';

    foreach $i (0..$#pre) {
        # print $mode.": $pre[$i]\n";

        if ( $pre[$i] =~ /^([0-9a-f\.:]+)/ ) {
            ( $ip ) = ( $pre[$i] =~ /^([0-9a-f\.:]+)/ );
            # which line do we have to parse ?
            if ( defined($ip) ) {
                if ( length($ip) > 15 ) {
                    $t = substr($pre[$i+1],18);
                }
                else {
                    $t = substr($pre[$i],18);
                }
                # parse the line
                # print $mode."m: $t\n";
                my(@t)=split(/\s+/,$t);
                if ( $t[0] eq '' ) {
                    shift(@t);
                }
                $as = $t[0];
                $upt= upt2sec($t[6]);
                 #print "ip: $ip as: $as\n";
                $pfx= $t[7];
                push (@res, "$ip $as $upt $pfx");

            }
            else {
                # we can not parse this line, skip it
                next;
            }
        }
        else {
            next;
        }
    }

    return @res;
}

# IN: string with the session uptime in some obscure format
# OUT: seconds since epoch
sub upt2sec {
    my($inp) = @_;

    # examples: never, 01:43:22, 1d00h57m, 05w4d23h

    # print "inp: $inp\n";
    if ( $inp eq 'never' ) {
        return -1;
    }

    if ( $inp =~ /:/ ) {
        my($h,$m,$s) = split(/:/,$inp);
        if ( !defined($h) ) {
            return -1;
        }
        return $h * 3600 + $m * 60 + $s;
    }

    if ( $inp =~ /\d+d\d+h\d+m/ ) {
        my($d,$h,$m) = ( $inp =~ /^(\d+)d(\d+)h(\d+)m$/ );
        if ( !defined($d) ) {
            return -1;
        }
        return $d * 86400 + $h * 3600 + $m * 60;
    }

    if ( $inp =~ /\d+w\d+d\d+h/ ) {
        my($w,$d,$h) = ( $inp =~ /^(\d+)w(\d+)d(\d+)h$/ );
        if ( !defined($w) ) {
            return -1;
        }
        return $w * 604800 + $d * 86400 + $h * 3600;
    }

    # if we can not parse it, return -1
    return -1;

}
