# versionCheckScreens
Bash scripts gather all data from hosts using ssh. Then, writes data to txt files, and triggers python code.
Python code formats data to make compatible with Influx DB, and sends data to Kafka.
Finally, Grafana screens can be prepared with the right queries and the data which is taken from Influx DB.
