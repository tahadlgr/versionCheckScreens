#!/usr/bin/python

import requests
import json

response = requests.get('https://api_in_json_format', verify = False)

#print(response.status_code)

data = response.json()

host_names = []

for d in data:
    a = d['host']
    host_names.append(a)


lib_filter_uat = 'wlpt'
lib_filter_prod = ['wlp']

liberty_hosts_uat = [x for x in host_names if all(y in x for y in lib_filter_uat)]

liberty_hosts_prod = [x for x in host_names if all(y in x for y in lib_filter_prod)]

HOSTS= ' '.join(liberty_hosts_prod)

print(HOSTS)