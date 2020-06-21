#!/usr/local/bin/bash

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
# installed Istio master+master multicluster.
export PROJECT_ID=lt-multicluster-t1-6-16-2020
# Configure the first cluster name in your multicluster project.
export CLUSTER_1=master01
# Configure the first cluster location in your multicluster project.
export LOCATION_1=us-central1-a
# Configure the second cluster name in your multicluster project.
export CLUSTER_2=master02
# Configure the second cluster location in your multicluster project.
export LOCATION_2=us-central1-a
