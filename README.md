# Istio to ASM migration examples

## Summary
This repository will walk through different migration scenarios. It is meant to prepare engineers for more real to life scenarios.


## Preparations
This guide was written for CloudShell. Some commands might not work as expected on MacOS or Windows. 

### Clone istio-to-asm repository
```
git clone https://github.com/sadasystems/istio-to-asm
```
```
cd istio-to-asm
```

### Update your variables
Open the vars.sh file and update it with the values you plan to use.

Example:
```
#! /usr/bin/env bash
PROJECT_ID=my-project
REGION=us-central1
ZONE=us-central1-b
MIN_ISTIO_NODES=4  # 4 nodes are recommended for ASM 
ISTIO_VERSION=1.9.6
ASM_VERSION=1.10 
CLUSTER_NAME=cluster-1  # default name
```
### Run the vars.sh script
```
chmod +x ./vars.sh
source ./vars.sh
```

### 1. Create the GKE cluster

*FOR LAB 1-2* Create the cluster - This will take several minutes
```
gcloud beta container --project $PROJECT_ID clusters create "${CLUSTER_NAME}" --zone "$ZONE" --no-enable-basic-auth  --release-channel "regular" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-pool "${PROJECT_ID}.svc.id.goog" --enable-shielded-nodes --enable-autoscaling --min-nodes "4" --max-nodes "10" --node-locations "$ZONE"
```

*FOR LAB 3-5*: Create the cluster - This will take several minutes
```
gcloud beta container --project $PROJECT_ID clusters create "${CLUSTER_NAME}" --zone "$ZONE" --no-enable-basic-auth --release-channel "regular" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-pool "${PROJECT_ID}.svc.id.goog" --enable-shielded-nodes --enable-autoscaling --min-nodes "4" --max-nodes "10" --node-locations "$ZONE" && gcloud beta container --project $PROJECT_ID node-pools create "istio-nodepool" --cluster "$CLUSTER_NAME" --zone "$ZONE" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --node-labels istio-nodepool=true --metadata disable-legacy-endpoints=true,istio-nodepool=true --node-taints istio=true:NoSchedule --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --enable-autoscaling --min-nodes "$MIN_ISTIO_NODES" --max-nodes "7" --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --node-locations "$ZONE"
```

### Download Istio 
Change the version if you prefer to use a different one. 
```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh - 
cd istio-${ISTIO_VERSION}/
export PATH=$PWD/bin:$PATH
cd ..
```

### 4. Download ASM
```
curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_${ASM_VERSION} > install_asm
chmod +x install_asm
```

### 5. Connect to the GKE cluster
Once the cluster is up and running connect to it via Cloud SDK
```
gcloud container clusters get-credentials cluster-1 --zone us-central1-c --project $PROJECT_ID
```

### 6. Install the Bookinfo app 
```
kubectl create ns bookinfo
kubectl label namespace bookinfo istio-injection=enabled
kubectl apply -f istio-${ISTIO_VERSION}/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo
```
### 7. Install Online Boutique
We will install a second application to understand the behaviour of the migration when one app is on istio and the other on ASM
```
kubectl create ns online-boutique
kubectl label namespace online-boutique istio-injection=enabled
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
kubectl apply -f ./microservices-demo/release -n online-boutique
```

## Labs

### [Lab 1: Migrating from default Istio to default ASM](/docs/Lab1-Default-migration.md)

> This lab walks you through a migration from a default Istio deployment to a default ASM installation. You will migrate the applications using a canary process

![Lab1 overview](./images/Istio-to-ASM-default-install.gif)

### [Lab 2: Migrating from default Istio to default ASM and Citadel to Mesh CA with minimal downtime](/docs/Lab2-Default-migration-with-CA.md)

> Prior to Anthos Service Mesh 1.10, if you wanted to migrate from Istio on to Anthos Service Mesh with Mesh CA, you needed to schedule downtime because Anthos Service Mesh was not able to load multiple root certificates, which interrupted mutual TLS (mTLS) traffic during the migration.
With Anthos Service Mesh 1.10 and higher, you can install a new in-cluster control plane with an option that distributes the Mesh CA root of trust to all proxies. After switching to the new control plane and restarting workloads, all proxies are configured with both the Istio CA and Mesh CA root of trust. Next, you install a new in-cluster control plane that has Mesh CA enabled. As you switch workloads over to the new control plane, mTLS traffic isn't interrupt.
This lab walks you through a migration from a default Istio deployment to a default ASM installation, as well as migrating from Citadel CA to Mesh CA using the new process, available in ASM 1.10. You will migrate the applications using the canary process as in Lab1.


### [Lab 3: Migrating from IstioOperator deployed Istio to ASM with custom Istio ingress gateway](/docs/Lab3-Migrating-with-custom-igw.md)

> This example is closer to a production deployment of Istio. The customer has their Istio ingress gateway deployed separately from the Istio control plane. Both, the ingress gateway and the control plane are deployed via IstioOperator. We will migrate the customer to ASM, and to follow best practices, we will replace the existing Istio ingress gateway and deploy a new ingress gateway in a new namespace outside of istio-system. The customer also uses a separate nodepool for the Istio control plane and gateways. 
 

### [Lab 4: Migrating from IstioOperator deployed Istio to ASM using a custom overlay file](/docs/Lab4-Migrating-with-custom-overlay.md)

> Companies running Istio in production will have modified Istio control plane to ensure resilience and high availability. In order to ensure the same configurations around horizontal pod autoscaling, AntiAffinity, resource quotas, as well as any other customizations compared to the available Istio profiles, we will use an overlay file furing the ASM installation. 
