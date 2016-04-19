#!/bin/bash

cd /var/ufdbguard
tar xzf bigblacklist.tar.gz
mkdir -p /var/ufdbguard/blacklists/{alwaysallow,alwaysblock}
touch /var/ufdbguard/blacklists/alwaysallow/domains /var/ufdbguard/blacklists/alwaysblock/domains
chown -R ufdb:ufdb /var/ufdbguard/blacklists
/usr/sbin/ufdbConvertDB /var/ufdbguard/blacklists
