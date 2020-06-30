#!/usr/bin/env bash

# Copyright 2020 Istio Authors

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# The values of the following environmental variables should be configured
# based on your multicluster installations (e.g., project, clusters, etc).

# Configure your multicluster project ID, in which you have
# installed Istio multicluster, e.g., my-gcp-multicluster-project-name.
# TODO: change to "export PROJECT_ID=YOUR-PROJECT-NAME"
export PROJECT_ID=lt-multicluster-t1-6-16-2020
# Configure the name of the first cluster in your multicluster project,
# e.g., primary01.
# TODO: change to "export CLUSTER_1=YOUR-CLUSTER-NAME-1"
export CLUSTER_1=master01
# Configure the location of the first cluster in your multicluster project,
# e.g., us-central1-a.
# TODO: change to "export LOCATION_1=YOUR-CLUSTER-LOCATION-1"
export LOCATION_1=us-central1-a
# Configure the name of the second cluster in your multicluster project,
# e.g., primary02.
# TODO: change to "export CLUSTER_2=YOUR-CLUSTER-NAME-2"
export CLUSTER_2=master02
# Configure the location of the second cluster in your multicluster project,
# e.g., us-central1-a.
# TODO: change to "export LOCATION_2=YOUR-CLUSTER-LOCATION-2"
export LOCATION_2=us-central1-a

# Configure the download method for Istio release.
# Two methods are supported: gsutil or curl.
# TODO: use curl to download istio-1.6.4-asm.9-linux-amd64.tar.gz from public release link.
export ISTIO_DOWNLOAD_METHOD=gsutil
# Configure the URL to download Istio release.
# If ISTIO_DOWNLOAD_METHOD=curl, an example value can look like
# https://storage.googleapis.com/gke-release/asm/istio-1.5.6-asm.0-linux.tar.gz.
# TODO: change the example gs://asm-staging-images to "gs://YOUR-GOOGLE-STORAGE-LINK-FOR-ISTIO-RELEASE".
# If ISTIO_DOWNLOAD_METHOD=gsutil, an example value can look like
# gs://asm-staging-images/asm/istio-1.5.6-asm.0-linux.tar.gz.
# As istio-1.6.0-asm.0-linux.tar.gz has not been released yet,
# when testing istio-1.6.0-asm.0-linux.tar.gz,
# istio-1.6.0-asm.0-linux.tar.gz is copied using gsutil from gs://asm-staging-images.
export ISTIO_RELEASE_URL=gs://asm-staging-images/asm/istio-1.6.4-asm.9-linux-amd64.tar.gz
# Configure the Istio release package name.
# An example is istio-1.5.6-asm.0-linux.tar.gz
export ISTIO_RELEASE_PKG=istio-1.6.4-asm.9-linux-amd64.tar.gz
# Configure the Istio release name, which should be configured to be
# the same as the directory name after unzipping ISTIO_RELEASE_PKG.
# For example, if unzipping the release pkg istio-1.5.6-asm.0-linux.tar.gz
# results in the directory istio-1.5.6-asm.0,
# ISTIO_RELEASE_NAME should be configured as istio-1.5.6-asm.0.
export ISTIO_RELEASE_NAME=istio-1.6.4-asm.9
