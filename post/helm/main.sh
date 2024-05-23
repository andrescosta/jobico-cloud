mkdir $1/tmp
wget https://get.helm.sh/helm-v3.15.1-linux-amd64.tar.gz --directory=$1/tmp
tar -zxvf $1/tmp/helm-v3.15.1-linux-amd64.tar.gz -C $1/tmp
sudo cp $1/tmp/linux-amd64/helm /usr/local/bin
rm -rf $1/tmp
