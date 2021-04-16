# terraform-kubernetes-tempest-pushgateway
This module helps to deploy `tempest-pushgateway` on a Kubernetes cluster

**WARNING: This module will wipe all resources that match the name `tempest`
before running the actual job, please make sure you assign credentials for
this user which are exclusively for Tempest.**