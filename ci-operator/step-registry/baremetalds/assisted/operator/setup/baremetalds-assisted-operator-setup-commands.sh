#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

echo "************ baremetalds assisted operator setup command ************"

# Fetch packet basic configuration
# shellcheck source=/dev/null
source "${SHARED_DIR}/packet-conf.sh"

ssh "${SSHOPTS[@]}" "root@${IP}" bash - << "EOF" |& sed -e 's/.*auths\{0,1\}".*/*** PULL_SECRET ***/g'

set -xeo pipefail

function wait_for_crd() {
  echo "Waiting for CRD ($1) to be defined"
  for i in {1..40}; do
    oc get "crd/$1" && break || sleep 10
  done
  oc wait --for condition=established --timeout=60s "crd/$1" || exit 1
}

function wait_for_operator() {
  subscription=$1
  namespace=$2
  echo "waiting for operator \"${subscription}\" to get installed on namespace \"${namespace}\"..."

  for _ in $(seq 1 60); do
    CSV=$(oc -n "$namespace" get subscription "$subscription" -o jsonpath='{.status.installedCSV}' || true)
    if [[ -n "$CSV" ]]; then
      if [[ "$(oc -n "$namespace" get csv "$CSV" -o jsonpath='{.status.phase}')" == "Succeeded" ]]; then
        echo "ClusterServiceVersion \"$CSV\" ready"
        return 0
      fi
    fi

    sleep 10
  done

  echo "Timed out waiting for csv to become ready!"
  return 1
}

echo "Installing Hive..."
cat <<EOCR | oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hive-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: hive-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: hive-operator.v1.1.1
EOCR

wait_for_operator "hive-operator" "openshift-operators"
wait_for_crd "clusterdeployments.hive.openshift.io"

echo "Installing prerequisites for assisted-installer operator..."
cat <<EOCR | oc create -f -
apiVersion: v1
kind: Namespace
metadata:
  name: assisted-installer
  labels:
    name: assisted-installer
EOCR

echo "Installing assisted-installer operator..."
cat <<EOCR | oc create -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
    name: assisted-installer-group
    namespace: assisted-installer
spec:
  targetNamespaces:
    - assisted-installer
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: assisted-service-operator
  namespace: assisted-installer
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: assisted-service-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: assisted-service-operator.v0.0.2
  config:
    env:
      - name: DEPLOY_TARGET
        value: "onprem"
EOCR

wait_for_crd "agentserviceconfigs.agent-install.openshift.io"

cat <<EOCR | oc create -f -
apiVersion: agent-install.openshift.io/v1beta1
kind: AgentServiceConfig
metadata:
 namespace: assisted-installer
 name: agent
spec:
 databaseStorage:
  storageClassName: "fs-lso"
  accessModes:
  - ReadWriteOnce
  resources:
   requests:
    storage: 8Gi
 filesystemStorage:
  storageClassName: "fs-lso"
  accessModes:
  - ReadWriteOnce
  resources:
   requests:
    storage: 8Gi
EOCR

wait_for_operator "assisted-service-operator" "assisted-installer"
echo "Installation of Assisted Install operator passed successfully!"

EOF
