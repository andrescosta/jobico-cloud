temp_dir=$(mktemp -d)
git clone git@github.com:/andrescosta/jobicok8s.git $temp_dir
cd $temp_dir
echo "Installing from: $(pwd)"
make deploy-all
