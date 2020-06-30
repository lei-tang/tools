# How to run multi-cluster security tests

## Install a multi-cluster Istio

Install a multi-cluster Istio with two clusters.

## Configure the test options

Let the root directory of this repo be *ROOT-OF-REPO*.
Enter the directory containing the tests.

    ```bash
    cd ROOT-OF-REPO/multicluster/security
    ```

Configure *setup_security_test.sh* based on your multi-cluster installation.

## To run the tests for mTLS authentication policies and certificates in multi-cluster:

    ```bash
    ./run_mtls_security_tests.sh
    ```
    
## To run the tests for authorization policies in multi-cluster:

    ```bash
    ./run_authz_security_tests.sh
    ```
