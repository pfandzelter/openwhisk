<!--
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
-->

# Lean OpenWhisk on arm64 in 2024

This repository is a fork of [razkey23/Serverless-On-Edge](https://github.com/razkey23/Serverless-On-Edge), which itself is a fork of [kpavel/incubator-openwhisk](https://github.com/kpavel/incubator-openwhisk), which is a fork of [apache/openwhisk](https://github.com/apache/openwhisk).
We run Lean OpenWhisk on a Raspberry Pi 3/4 with Raspberry Pi OS (Debian Bookworm) in 2024.

## Deployment

Here are the steps:

```sh
sudo apt update

sudo apt install python3 python3-pip netcat-openbsd nodejs npm unzip -y

sudo pip install ansible==4.1.0 --break-system-packages
sudo pip install jinja2==3.0.1 --break-system-packages
sudo pip install requests==2.31.0 --break-system-packages
sudo pip install docker==4.0.2 --break-system-packages
sudo pip install httplib2==0.9.2 --break-system-packages

# install Docker using your preferred method, or this one
curl -fsSL https://get.docker.com -o install-docker.sh
sudo sh install-docker.sh
sudo usermod -aG docker $USER
newgrp docker

cd ~
git clone https://github.com/pfandzelter/openwhisk

cd openwhisk

export OPENWHISK_HOME=$(pwd)
export OPENWHISK_TMP_DIR=$OPENWHISK_HOME/tmp

cd ansible

cat << EOF > db_local.ini
[db_creds]
db_provider=CouchDB
db_username=whisk_admin
db_password=some_passw0rd
db_protocol=http
db_host=172.17.0.1
db_port=5984
[controller]
db_username=whisk_local_controller0
db_password=some_controller_passw0rd
[invoker]
db_username=whisk_local_invoker0
db_password=some_invoker_passw0rd
EOF


# for x64, simply replace "arm64" with "x64"
docker pull pfandzelter/controller:arm64
docker pull pfandzelter/python3action:arm64
docker pull treehouses/couchdb

ansible-playbook setup.yml
ansible-playbook couchdb.yml
ansible-playbook initdb.yml
ansible-playbook wipe.yml
ansible-playbook openwhisk.yml -v \
    -e lean=true \
    -e invoker_user_memory=1024m \
    -e docker_image_prefix=pfandzelter \
    -e docker_image_tag=arm64 \
    -e controller_protocol=http
ansible-playbook postdeploy.yml -e skip_catalog_install=true
# ansible-playbook apigateway.yml \
#     -e apigateway_docker_image=pfandzelter/apigateway:arm64
```

Replace `arm64` with `amd64` if you want to run this on an `amd64` computer.

Note that you may get the following error when deploying CouchDB:

```error
The requested image's platform (linux/amd64) does not match the detected host platform (linux/arm64/v8) and no specific platform was requested
```

That is no reason to worry, it's a result of changes in how Docker handles multi-platform images.

We now have Lean OpenWhisk running and can deploy our functions.
First, we need to install the `wsk` CLI:

```sh
sudo wget -qO- https://github.com/apache/incubator-openwhisk-cli/releases/download/0.10.0-incubating/OpenWhisk_CLI-0.10.0-incubating-linux-arm64.tgz | tar xvz -C ~/openwhisk/bin wsk
export PATH=$PATH:~/openwhisk/bin

cat << EOF > ~/.wskprops
AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
APIHOST=http://172.17.0.1:10001
NAMESPACE=guest
EOF
```

Of course, download the `amd64` variant for an `amd64` computer.

Create a file `hello.js`, add it as an action, and invoke it:

```sh
cat << EOF > ~/hello.js
/**
 * Hello world as an OpenWhisk action.
 */
function main(params) {
    var name = params.name || 'World';
    return {payload:  'Hello, ' + name + '!'};
}
EOF

wsk action create hello hello.js
wsk action invoke hello --result
```

## Runtimes

The existing Lean OpenWhisk repositories use a Node.js runtime that was build in 2019 for `arm32`.
We wanted to have a Python3 runtime, so we had to build our own.
As we did not want to create a bunch more forks, we copied the [`apache/openwhisk-runtime-python`](https://github.com/apache/openwhisk-runtime-python) and [`apache/openwhisk-runtime-dockerskeleton`](https://github.com/apache/openwhisk-runtime-dockerskeleton) repositories to the `runtime` directory.
We used the `1.14.0` version from early 2020, just in case there were any breaking changes in the last four years.
If you want to build your own runtimes, roughly follow these steps for Python3.
These are all performed on an M1 MacBook Pro (`arm64`) with Docker, but you could perform these steps on a Raspberry Pi if you have the patience.

1. Sign in to your Docker repository.
    You can use the default Docker hub or any other registry, just note the correct prefix.

1. Build a development container.
    We use a development container to get an environment with roughly the dependencies that we would have in 2019, most importantly Docker

    ```sh
    cd runtimes
    docker build --platform linux/arm64 -f devel.Dockerfile -t wsk-runtime-devel .
    ```

    For amd64, simply replace `linux/arm64` with `linux/amd64` and use the `devel-amd64.Dockerfile`:

    ```sh
    docker build --platform linux/amd64 -f devel-amd64.Dockerfile -t wsk-runtime-devel .
    ```

1. Start the development container with access to `/var/run/docker.sock` and your files.

    ```sh
    cd ..
    docker run --rm -it -v $(pwd):/wsk -v /var/run/docker.sock:/var/run/docker.sock wsk-runtime-devel
    ```

    You are now in the container's shell and can start building the containers.

1. Export the correct prefix and tag for your images:

    ```sh
    export WSK_IMAGE_PREFIX=pfandzelter
    export WSK_IMAGE_TAG=arm64
    export WSK_IMAGE_REGISTRY=docker.io
    ```

    Make sure you are logged in to your registry!
    Feel free to change the image tag to `amd64` if you are building for amd64.

1. Build the `dockerskeleton` image:

    ```sh
    cd /wsk/runtimes/dockerskeleton

    ./gradlew core:actionProxy:distDocker :sdk:docker:distDocker \
        -PdockerImagePrefix=$WSK_IMAGE_PREFIX \
        -PdockerImageTag=$WSK_IMAGE_TAG \
        -PdockerRegistry=$WSK_IMAGE_REGISTRY \
        -PdockerPlatform=linux/arm64
    ```

    The image should now be available in your registry.
    We will use it to build the `python` image.
    Change the platform to `linux/amd64` for amd64.

1. Build the `python` image.
    Note that we have added the `WSK_IMAGE_PREFIX`, `WSK_IMAGE_REGISTRY`, and `WSK_IMAGE_TAG` build arguments to the Dockerfile!

    ```sh
    cd /wsk/runtimes/python3

    ./gradlew core:pythonAction:distDocker \
        -PdockerImagePrefix=$WSK_IMAGE_PREFIX \
        -PdockerImageTag=$WSK_IMAGE_TAG \
        -PdockerRegistry=$WSK_IMAGE_REGISTRY \
        -PdockerPlatform=linux/arm64 \
        -PdockerBuildArgs="WSK_IMAGE_PREFIX=$WSK_IMAGE_PREFIX WSK_IMAGE_TAG=$WSK_IMAGE_TAG WSK_IMAGE_REGISTRY=$WSK_IMAGE_REGISTRY"
    ```

    Change the platform to `linux/amd64` for amd64.
    You should now have the runtime image in your repository.

1. If you want, you can close your development container now:

    ```sh
    exit
    ```

1. To test it, modify the `ansible/files/rpiruntimes.json` file and redeploy your Raspberry Pi Lean OpenWhisk installation.
    For example:

    ```json
    {
        "runtimes": {
            "python": [
                {
                    "kind": "python:3",
                    "default": true,
                    "image": {
                        "prefix": "pfandzelter",
                        "name": "python3action",
                        "tag": "arm64"
                    },
                    "deprecated": false,
                    "stemCells": [
                        {
                            "count": 2,
                            "memory": "512 MB"
                        }
                    ]
                }
            ]
        },
        "blackboxes": []
    }
    ```

    For amd64, simply replace `arm64` with `amd64`.

1. Deploy a Python action:

    ```sh
    cat << EOF > test1.py
    def main(args):
        name = args.get("name", "stranger")
        greeting = "Hello " + name + "!"
        print(greeting)
        return {"greeting": greeting}
    EOF

    wsk action create test1 test1.py
    wsk action invoke test1 --result
    ```

## Building the Controller

If you want, you can also build your own controller image for `arm64`.
Again, feel free to adapt for `amd64`.
Simply use the `wask-runtime-devel` image built above:

1. Start the container from the `openwhisk` directory:

    ```sh
    docker run --rm -it \
        --platform linux/arm64 \
        -v $(pwd):/wsk -v /var/run/docker.sock:/var/run/docker.sock \
        wsk-runtime-devel
    ```

1. Build the container.
    We have set the `openjdk:8u181-jdk` `arm64` image instead of the `arm32v7/openjdk:8u181-jdk` image and have changed some dependencies to `arm64`.

    ```sh
    # change these to fit your needs
    # may need to run docker login
    export WSK_IMAGE_PREFIX=pfandzelter
    export WSK_IMAGE_TAG=arm64
    export WSK_IMAGE_REGISTRY=docker.io

    ./gradlew core:controller:distDocker \
        -PdockerImagePrefix=$WSK_IMAGE_PREFIX \
        -PdockerImageTag=$WSK_IMAGE_TAG \
        -PdockerRegistry=$WSK_IMAGE_REGISTRY \
        -PdockerPlatform=linux/arm64
    ```

    This will also push the container to the registry.
    Note that you must log in, the same as with the runtime images.

1. You can now use your custom controller image during deployment, for example:

    ```sh
    ansible-playbook openwhisk.yml -v \
        -e lean=true \
        -e invoker_user_memory=1024m \
        -e docker_image_prefix=pfandzelter \
        -e docker_image_tag=arm64 \
        -e controller_protocol=http
    ```

## API Gateway

We don't know what the API gateway is needed for, but we'll compile it anyway.
The contents of [apache/openwhisk-apigateway@1.0.0](https://github.com/apache/openwhisk-apigateway) are in the `apigateway` directory.

```sh
cd apigateway

export WSK_IMAGE_PREFIX=pfandzelter
export WSK_IMAGE_TAG=arm64
export WSK_IMAGE_REGISTRY=docker.io

OPENWHISK_TARGET_REGISTRY=$WSK_IMAGE_REGISTRY OPENWHISK_TARGET_PREFIX=$WSK_IMAGE_PREFIX OPENWHISK_TARGET_TAG=$WSK_IMAGE_TAG make docker

docker push $WSK_IMAGE_REGISTRY/$WSK_IMAGE_PREFIX/apigateway:$WSK_IMAGE_TAG
```

---

[![Build Status](https://travis-ci.org/apache/incubator-openwhisk.svg?branch=master)](https://travis-ci.org/apache/incubator-openwhisk)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)
[![Join Slack](https://img.shields.io/badge/join-slack-9B69A0.svg)](http://slack.openwhisk.org/)
[![codecov](https://codecov.io/gh/apache/incubator-openwhisk/branch/master/graph/badge.svg)](https://codecov.io/gh/apache/incubator-openwhisk)
[![Twitter](https://img.shields.io/twitter/follow/openwhisk.svg?style=social&logo=twitter)](https://twitter.com/intent/follow?screen_name=openwhisk)

OpenWhisk is a cloud-first distributed event-based programming service. It provides a programming model to upload event handlers to a cloud service, and register the handlers to respond to various events. Learn more at [http://openwhisk.incubator.apache.org](http://openwhisk.incubator.apache.org).

* [Quick Start](#quick-start) (Docker-Compose)
* [Native development](#native-development) (Mac and Ubuntu)
* [Kubernetes](#kubernetes-setup)
* [Vagrant](#vagrant-setup)
* [Learn concepts and commands](#learn-concepts-and-commands)
* [Issues](#issues)
* [Slack](#slack)

### Quick Start

The easiest way to start using OpenWhisk is to get Docker installed on on Mac, Windows or Linux. The [Docker website](https://docs.docker.com/install/) has details instructions on getting the tools installed. This does not give you a production deployment but gives you enough of the pieces to start writing functions and seeing them run.

```

git clone <https://github.com/apache/incubator-openwhisk-devtools.git>
cd incubator-openwhisk-devtools/docker-compose
make quick-start

```

For more detailed instructions or if you encounter problems see the [OpenWhisk-dev tools](https://github.com/apache/incubator-openwhisk-devtools/blob/master/docker-compose/README.md) project.

### Kubernetes Setup

Another path to quickly starting to use OpenWhisk is to install it on a Kubernetes cluster.  On a Mac, you can use the Kubernetes support built into Docker 18.06 (or higher). You can also deploy OpenWhisk on Minikube, on a managed Kubernetes cluster provisioned from a public cloud provider, or on a Kubernetes cluster you manage yourself. To get started,

```

git clone <https://github.com/apache/incubator-openwhisk-deploy-kube.git>

```

Then follow the instructions in the [OpenWhisk on Kubernetes README.md](https://github.com/apache/incubator-openwhisk-deploy-kube/blob/master/README.md).

### Vagrant Setup

A [Vagrant](http://vagrantup.com) machine is also available to run OpenWhisk on Mac, Windows PC or GNU/Linux but isn't used by as much of the dev team so sometimes lags behind.
Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.vagrantup.com/downloads.html) for your operating system and architecture.

**Note:** For Windows, you may need to install an ssh client in order to use the command `vagrant ssh`. Cygwin works well for this, and Git Bash comes with an ssh client you can point to. If you run the command and no ssh is installed, Vagrant will give you some options to try.

Follow these step to run your first OpenWhisk Action:

```

# Clone openwhisk

git clone --depth=1 <https://github.com/apache/incubator-openwhisk.git> openwhisk

# Change directory to tools/vagrant

cd openwhisk/tools/vagrant

# Run script to create vm and run hello action

./hello

```

Wait for hello action output:

```

wsk action invoke /whisk.system/utils/echo -p message hello --result
{
    "message": "hello"
}

```

These steps were tested on Mac OS X El Capitan, Ubuntu 14.04.3 LTS and Windows using Vagrant.
For more information about using OpenWhisk on Vagrant see the [tools/vagrant/README.md](tools/vagrant/README.md)

During the Vagrant setup, the Oracle JDK 8 is used as the default Java environment. If you would like to use OpenJDK 8, please change the line "su vagrant -c 'source all.sh oracle'" into "su vagrant -c 'source all.sh'" in tools/vagrant/Vagrantfile.

### Native development

Docker must be natively installed in order to build and deploy OpenWhisk.
If you plan to make contributions to OpenWhisk, we recommend either a Mac or Ubuntu environment.

* [Setup Mac for OpenWhisk](tools/macos/README.md)
* [Setup Ubuntu for OpenWhisk](tools/ubuntu-setup/README.md)

### Learn concepts and commands

Browse the [documentation](docs/) to learn more. Here are some topics you may be
interested in:

* [System overview](docs/about.md)
* [Getting Started](docs/README.md)
* [Create and invoke actions](docs/actions.md)
* [Create triggers and rules](docs/triggers_rules.md)
* [Use and create packages](docs/packages.md)
* [Browse and use the catalog](docs/catalog.md)
* [Using the OpenWhisk mobile SDK](docs/mobile_sdk.md)
* [OpenWhisk system details](docs/reference.md)
* [Implementing feeds](docs/feeds.md)

### Repository Structure

The OpenWhisk system is built from a [number of components](docs/dev/modules.md).  The picture below groups the components by their GitHub repos. Please open issues for a component against the appropriate repo (if in doubt just open against the main openwhisk repo).

![component/repo mapping](docs/images/components_to_repos.png)

### Issues

Report bugs, ask questions and request features [here on GitHub](../../issues).

### Slack

You can also join the OpenWhisk Team on Slack [https://openwhisk-team.slack.com](https://openwhisk-team.slack.com) and chat with developers. To get access to our public slack team, request an invite [https://openwhisk.incubator.apache.org/slack.html](https://openwhisk.incubator.apache.org/slack.html).

# Disclaimer

Apache OpenWhisk is an effort undergoing incubation at The Apache Software Foundation (ASF), sponsored by the Apache Incubator. Incubation is required of all newly accepted projects until a further review indicates that the infrastructure, communications, and decision making process have stabilized in a manner consistent with other successful ASF projects. While incubation status is not necessarily a reflection of the completeness or stability of the code, it does indicate that the project has yet to be fully endorsed by the ASF.
