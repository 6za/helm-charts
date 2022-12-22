#!/bin/bash
shopt -s expand_aliases
source  ~/.bash_profile
export K1_WATCHER_PATH=${BASE_PATH_GIT}/kubefirst/kubefirst-watcher/branches/main
export K1_OPERATOR_PATH=${BASE_PATH_GIT}/kubefirst/kubefirst-watcher-operator/branches/main
export CHART_DIR=${BASE_PATH_GIT}/6za/helm-charts/branches/main
export HERE=$PWD
cd $K1_WATCHER_PATH && git_6za pull 
export K1_WATCHER_SHA=$(git rev-parse --short HEAD)
cd $K1_OPERATOR_PATH && git_6za pull 
export K1_OPERATOR_SHA=$(git rev-parse --short HEAD)
cd $CHART_DIR && git_6za pull 
cd $HERE
docker run --rm -it \
    -w /go/src \
    -v operator-sdk:/go/pkg \
    --network="host" \
    -e K1_OPERATOR_SHA \
    -e DOCKER_CI_KEY \
    -e DOCKER_CI_USER \
    -v $K1_OPERATOR_PATH:/go/src \
    -v /var/run/docker.sock:/var/run/docker.sock  \
    --privileged \
    kubebuilder bash -c "echo $DOCKER_CI_KEY | docker login --username $DOCKER_CI_USER --password-stdin  &&\
                        make docker-build IMG=6zar/k1-watcher-contoller:latest &&\
                        make docker-push IMG=6zar/k1-watcher-contoller:latest &&\
                        make docker-build IMG=6zar/k1-watcher-contoller:${K1_OPERATOR_SHA} &&\
                        make docker-push IMG=6zar/k1-watcher-contoller:${K1_OPERATOR_SHA}"

docker run --rm -it \
    -w /go/src \
    -v operator-sdk:/go/pkg \
    --network="host" \
    -e K1_WATCHER_SHA \
    -e DOCKER_CI_KEY \
    -v $K1_WATCHER_PATH:/go/src \
    -v /var/run/docker.sock:/var/run/docker.sock  \
    --privileged \
    kubebuilder bash -c "echo $DOCKER_CI_KEY | docker login --username 6zar --password-stdin  &&\
                        docker build -f build/Dockerfile .  -t k1test:$K1_WATCHER_SHA  &&\
                        docker image tag k1test:$K1_WATCHER_SHA 6zar/k1test:$K1_WATCHER_SHA  &&\
                        docker image tag k1test:$K1_WATCHER_SHA 6zar/k1test:latest  &&\
                        docker image push 6zar/k1test:latest  &&\
                        docker image push 6zar/k1test:$K1_WATCHER_SHA"


docker run --rm -it \
    -v $K1_OPERATOR_PATH:/go/src \
    -v $CHART_DIR:/chart \
    -w /go/src \
    kubebuilder \
    bash -c "kustomize build config/default >  /chart/charts/helm-k1-watcher-operator/templates/deploy.yaml"

docker run --rm -it \
    -v $CHART_DIR:/chart \
    -e K1_WATCHER_SHA \
    kubebuilder \
    bash -c 'sed -i "s/k1test\:latest/k1test\:${K1_WATCHER_SHA}/g" /chart/charts/helm-k1-watcher-operator/templates/deploy.yaml '

docker run --rm -it \
    -v $CHART_DIR:/chart \
    -e K1_OPERATOR_SHA \
    kubebuilder \
    bash -c 'sed -i "s/k1-watcher-contoller\:latest/k1-watcher-contoller\:${K1_OPERATOR_SHA}/g" /chart/charts/helm-k1-watcher-operator/templates/deploy.yaml '    

docker run -it --rm \
    -v $CHART_DIR:/chart \
    arielev/pybump:1.9.3 \
    bump --file /chart/charts/helm-k1-watcher-operator/Chart.yaml --level minor


docker run --rm -it \
    -v $CHART_DIR:/chart \
    -w /chart \
    kubebuilder \
    helm package charts/helm-k1-watcher-operator/

docker run --rm -it \
    -w /chart \
    -v $CHART_DIR:/chart \
    kubebuilder \
    helm repo index --url https://6za.github.io/helm-charts/ --merge index.yaml .

cd $CHART_DIR 
git_6za add .
git_6za commit -s -m "update charts"
git_6za push origin main
cd $HERE    
