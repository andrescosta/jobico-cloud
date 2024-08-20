#!/bin/bash

interrupted=false

interrupt(){
   interrupted=true 
}

trap interrupt SIGTERM SIGINT

build() {
    local cmd repo branch="main" work_dir="~/repos" registry image_name helm_repo version="0.1" build_dir branch_helm="main"
    local arg chart helm_version="0.1" git_user_email="builder@k8s" git_user_name="builder" wait_time=30 verbose=false token_file
    local first_build=false
    echo "Starting .... $cmd"
    if [ $# == 0 ]; then
        echo "No command. Supported commands: init|build ."
        exit 1
    fi
    cmd=$1
    shift
    if [[ $cmd != "init" && $cmd != "build" ]]; then
        echo "$cmd unsupported. Supported commands: init|build ."
        exit 1
    fi
    for arg in "$@"; do
        case "$arg" in
            --repository=*)
                repo="${arg#*=}"
                ;;
            --branch=*)
                branch="${arg#*=}"
                ;;
            --work-dir=*)
                work_dir=${arg#*=}
                #work_dir=$(eval "echo \"$work_dir\"")
                ;;
            --registry=*)
                registry="${arg#*=}"
                ;;
            --image-name=*)
                image_name="${arg#*=}"
                ;;
            --current-version=*)
                version="${arg#*=}"
                ;;
            --build-dir=*)
                build_dir="${arg#*=}"
                ;;
            --helm-repository=*)
                helm_repo="${arg#*=}"
                ;;
            --helm-branch=*)
                branch_helm="${arg#*=}"
                ;;
            --helm-chart=*)
                chart="${arg#*=}"
                ;;
            --helm-version=*)
                helm_version="${arg#*=}"
                ;;
            --git-user=*)
                git_user_name="${arg#*=}"
                ;;
            --git-email=*)
                git_user_email="${arg#*=}"
                ;;
            --frequency=*)
                wait_time=${arg#*=}
                ;;
            --token-file=*)
                token_file=${arg#*=}
                ;;
            --verbose)
                verbose=true
                ;;
            --first-build)
                first_build=true
                ;;
            --help)
                echo "No help. Sorry."
                exit 0
                ;;
            *)
                echo "Illegal option: $arg" >&2
                exit 1
                ;;
        esac
    done

    local image=$registry/$image_name
    local code_dir="$work_dir/code"
    local helm_dir="$work_dir/helm"
    
    local token=$(cat $token_file)
    helm_repo=$(echo "$helm_repo" | sed "s/{token}/$token/g")

    if [ $verbose == true ]; then
        echo "Repository: $repo"
        echo "Branch: $branch"
        echo "Work directory: $work_dir"
        echo "Build directory: $build_dir"
        echo "Registry: $registry"
        echo "Image: $image_name"
        echo "Repo for Helm charts: $helm_repo"
        echo "App version: $version"
        echo "Dir of code repository: $code_dir"
        echo "Dir of helm chart repository: $helm_dir"
        echo "Brach of Helm charts: $branch_helm"
        echo "Image: $image"
        echo "Chart: $chart"
        echo "Helm version: $helm_version"
        echo "Git user email: $git_user_email"
        echo "Git user name:  $git_user_name"
        echo "Frequency: $wait_time"
        echo "Token file: $token_file"
        echo "Code dir: $code_dir"
        echo "Helm dir: $helm_dir"
    fi
    if [ $cmd == "init" ]; then
        git clone $repo $code_dir
        git clone $helm_repo $helm_dir
        (cd $code_dir; git config user.email "$git_user_email"; git config user.name "$git_user_name"; git config pull.ff only)
        (cd $helm_dir; git config user.email "$git_user_email"; git config user.name "$git_user_name"; git config pull.ff only)
        cat <<EOF > /repo/$chart.sh
#!/bin/bash
/script/build.sh build $@
EOF
        chmod 0500 /repo/$chart.sh
        exit 0
    fi
    if [ $cmd == "build" ]; then
        cd $code_dir
        git checkout $branch
        while true; do
            if [ $interrupted == true ]; then
                if [ $verbose == true ]; then
                    echo "Stopping..."
                fi
                break
            fi
            if [ $verbose == true ]; then
                echo "Checking for updates..."
            fi
            git fetch -q origin "$branch"
            git diff --quiet origin/"$branch" -- "$build_dir"        
            if [[ $? == 1 || $first_build == true ]]; then
                first_build=false
                git pull origin "$branch"
                patch_version=$(git rev-list HEAD --count --no-merges)
                push_version="$version.$patch_version"
                buildah login --username jobico --password jobico123 https://reg.jobico.org
                buildah build --format=docker -t $image:$push_version $build_dir
                buildah push $image:$push_version

                pushd "$helm_dir/charts/$chart" >/dev/null
                git pull origin $branch_helm
                sed -i "s/^appVersion:.*/appVersion: ${push_version}/g" "Chart.yaml"
                sed -i "s/^version:.*/version: ${helm_version}.${patch_version}/g" "Chart.yaml"
                git commit -a -m "New chart: ${helm_version}.${patch_version}"
                git push
                popd >/dev/null
            fi
            if [ $interrupted == true ]; then
                if [ $verbose == true ]; then
                    echo "Stopping..."
                fi
                break
            fi
            sleep $wait_time
        done
    fi
}

main() {
    build "$@"
}

main "$@"
