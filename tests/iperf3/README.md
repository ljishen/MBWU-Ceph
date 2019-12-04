Here are the commands used to produce the results.

## Server

```bash
iperf3 -B <server_ip> -s
```

## Client

```bash
iperf3 -c <server_ip> -B <client_ip> -l <buf_len> -t 60 -O 2 --json --logfile <log_file>
```
