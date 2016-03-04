#!/usr/bin/env python

# Msingh

"""
Download latest ipv4 / ipv6 pfx2as routeview files from http://data.caida.org and 
create single pfx2as file for pmacct AS number lookup
"""

from __future__ import ( division, absolute_import, print_function, unicode_literals )

import sys, os, tempfile, logging
import time
import re
import gzip

if sys.version_info >= (3,):
    import urllib.request as urllib2
    import urllib.parse as urlparse
else:
    import urllib2
    from urllib2 import urlopen
    import urlparse

def download_file(url, desc=None):
    u = urllib2.urlopen(url)

    scheme, netloc, path, query, fragment = urlparse.urlsplit(url)
    filename = os.path.basename(path)
    if not filename:
        filename = 'downloaded.file'
    if desc:
        filename = os.path.join(desc, filename)

    with open(filename, 'wb') as f:
        meta = u.info()
        meta_func = meta.getheaders if hasattr(meta, 'getheaders') else meta.get_all
        meta_length = meta_func("Content-Length")
        file_size = None
        if meta_length:
            file_size = int(meta_length[0])
        print("Downloading: {0} Bytes: {1}".format(url, file_size))

        file_size_dl = 0
        block_sz = 8192
        while True:
            buffer = u.read(block_sz)
            if not buffer:
                break

            file_size_dl += len(buffer)
            f.write(buffer)

            status = "{0:16}".format(file_size_dl)
            if file_size:
                status += "   [{0:6.2f}%]".format(file_size_dl * 100 / file_size)
            status += chr(13)
            print(status, end="")
        print()

    return filename


if __name__ == '__main__':
        year = time.strftime("%Y")
        month = time.strftime("%m")
        os_path = os.path.dirname(os.path.realpath(__file__))
        gzfilelist = []

        ipv4_urlweb = "http://data.caida.org/datasets/routing/routeviews-prefix2as/{}/{}".format(year,month)
        try:
                ipv4_urlpath = urlopen(ipv4_urlweb)
        except urllib2.HTTPError, err:
                print ("Error URL Lookup: {}: {}".format(ipv4_urlweb,err.code))
                sys.exit(1)
        string = ipv4_urlpath.read().decode('utf-8')
        pattern = re.compile('<a href=\"(\w*-\w*-\w*-\w*.pfx2as.gz)\">') #the pattern
        ipv4pfx_filelist = pattern.findall(string)

        if ipv4pfx_filelist:
                latest_ipv4pfx_file = ipv4pfx_filelist.pop()
                print("Found %s" % latest_ipv4pfx_file)
                ipv4_url = "{}/{}".format(ipv4_urlweb, latest_ipv4pfx_file)
                ipv4pfx_file = download_file(ipv4_url)
                gzfilelist = ['/'.join([os_path, latest_ipv4pfx_file])]
        else:
                print ("No v4 routeviews found")
                sys.exit(1)

        ipv6_urlweb = "http://data.caida.org/datasets/routing/routeviews6-prefix2as/{}/{}".format(year,month)
        try:
                ipv6_urlpath = urlopen(ipv6_urlweb)
        except urllib2.HTTPError, err:
                print ("Error URL Lookup: {}: {}".format(ipv6_urlweb,err.code))
                sys.exit(1)
        string = ipv6_urlpath.read().decode('utf-8')
        pattern = re.compile('<a href=\"(\w*-\w*-\w*-\w*.pfx2as.gz)\">') #the pattern
        ipv6pfx_filelist = pattern.findall(string)

        if ipv6pfx_filelist:
                latest_ipv6pfx_file = ipv6pfx_filelist.pop()
                print("Found %s" % latest_ipv6pfx_file)
                ipv6_url = "{}/{}".format(ipv6_urlweb, latest_ipv6pfx_file)
                ipv6pfx_file = download_file(ipv6_url)

                gzfilelist.append('/'.join([os_path, latest_ipv6pfx_file]))
        else:
                print ("No v6 routeviews found")
                sys.exit(1)

        for gzip_path in gzfilelist:
                print (gzip_path)
                if not os.path.isdir(gzip_path):
                        with gzip.open(gzip_path, 'rb') as in_file:
                                        s = in_file.read()

                        # Now store the uncompressed data
                        path_to_store = gzip_path[:-3]  # remove the '.gz' from the filename

                        # store uncompressed file data from 's' variable
                        with open(path_to_store, 'w') as f:
                                        f.write(s)

        regexList = ['^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\t(\d{1,2})\t(.*)', '^(.+::)\t(\d{1,3})\t(.*)']
        pfx2as_filename = '/'.join([os_path, 'pfx2as'])
        target = open(pfx2as_filename, 'w')

        for file in gzfilelist:
                f = open(file[:-3], "r")
                for line in f:
                        for regex in regexList:
                                matchObj = re.match(regex,line)
                                if matchObj:
                                        ipaddress = matchObj.group(1)
                                        ippfx = matchObj.group(2)
                                        numbersonly = re.compile('\d+') #the pattern
                                        asnumbers = numbersonly.findall(matchObj.group(3))
                                        for asnumber in asnumbers:
                                                print ('%s,%s/%s' % ( asnumber, ipaddress, ippfx ))
                                                target.write ('%s,%s/%s\n' % ( asnumber, ipaddress, ippfx ))
                f.close()

        target.close()
        sys.exit(0)
