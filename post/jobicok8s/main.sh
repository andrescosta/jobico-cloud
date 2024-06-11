if [[ $1 != "" && -d $1 ]]; then
    temp_dir=$1
else
    temp_dir=$(mktemp -d)
fi
git clone git@github.com:/andrescosta/jobicok8s.git $temp_dir/jobicok8s
cd $temp_dir/jobicok8s
echo "Installing from: $(pwd)"
make deploy-all
