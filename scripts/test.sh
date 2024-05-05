DIR=$(dirname "$0")
CONF_FILE=${DIR}/plugins_test.conf
. $(dirname "$0")/plugins.sh 

kube::plugins::load ${CONF_FILE}
kube::plugins::test::hi
