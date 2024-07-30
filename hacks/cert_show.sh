 openssl s_client -showcerts -servername $1 -connect $1:443 | openssl x509 -text


