docker build $1 -f $1/Dockerfile -t reg.jobico.org/buildah
docker push reg.jobico.org/buildah
$1/deploy-build.sh $1
