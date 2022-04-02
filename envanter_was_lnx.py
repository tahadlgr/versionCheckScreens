#!/usr/bin/python

import requests
import json

##response = requests.get('https://api_in_json_format', verify = False)
response = requests.get('https://api_in_json_format', verify = False)

#print(response.status_code)

data = response.json()

host_names = []

for d in data:
    a = d['host']
    host_names.append(a)

was_filter_prod = ['was']

was_hosts_prod = [x for x in host_names if all(y in x for y in was_filter_prod)]

aix_filter_prod =['ka']

aix_hosts_prod = [x for x in was_hosts_prod if all(y in x for y in aix_filter_prod)]

#HOSTS= ' '.join(was_hosts_prod)
#print(HOSTS)


aix_hosts = ' '.join(aix_hosts_prod)

HOSTS_aix = aix_hosts



lnx_hosts_prod = []

for lnx_host in was_hosts_prod:
    if lnx_host not in aix_hosts_prod:
        lnx_hosts_prod.append(lnx_host)
    
HOSTS_lnx = ' '.join(lnx_hosts_prod)    
    
print(HOSTS_lnx)
