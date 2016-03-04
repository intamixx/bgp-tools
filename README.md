# bgp-tools

Script to monitor the quagga bgpd daemon via Check_MK
check_quagga_bgpd.pl is a perl script that connects to the running bgpd, parses the config, lists the BGP peers, checks on their status (both IPv4 and IPv6) 

cnic_looking_glass.pl: Perl Script to generate AS-Paths from Looking Glass RIPE Data

cnic_pfx_list_from_as.pl: Perl Script to generate Cisco IOS-Like Prefixes List for Filtering peering on IXP

pfx2as_get.py: Download latest ipv4 / ipv6 pfx2as routeview files from http://data.caida.org and 
create single pfx2as file for pmacct AS number lookup
