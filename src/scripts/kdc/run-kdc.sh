#!/bin/bash

set -eux

# create KDC database if it doesn't exist
if [ ! -e /var/kerberos/krb5kdc/principal ]; then
  kdb5_util create -r LOCAL -P password
fi

krb5kdc
tail -f /var/log/krb5kdc.log
