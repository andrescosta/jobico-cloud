SCP() {
    scp -o ConnectTimeout=30 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 "$@"
}
SSH() {
    ssh -o ConnectTimeout=30 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 "$@"
}
