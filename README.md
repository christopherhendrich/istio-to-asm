# Istio to ASM migration examples

## Summary
This repository will walk through different migration scenarios. It is meant to give engineers more to real life scenarios


## Preparations
This section covers:
1. Create the GKE Cluster
2. Download this repository
3. Download Istio
4. Install the bookinfo demo app
5. Install the online-boutique demo app

### 1. Create the GKE cluster
We will create a GKE cluster that will include a dedicated nodepool for Istio/ASM. The dedicated nodepool is not being utilized in the default example, so you can set MIN_ISTIO_NODES to 0. For all other examples, it is recommnded to use MIN_ISTIO_NODES=4

Set up a variable for your GCP Project ID

```
export PROJECT_ID=[Your project ID]
export MIN_ISTIO_NODES=[ Number of minimum nodes for istio pool]
```

Create the cluster
```
gcloud beta container --project $PROJECT_ID clusters create "cluster-1" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.19.10-gke.1600" --release-channel "regular" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-pool "${PROJECT_ID}.svc.id.goog" --enable-shielded-nodes --enable-autoscaling --min-nodes "4" --max-nodes "10" --node-locations "us-central1-c" && gcloud beta container --project $PROJECT_ID node-pools create "istio-nodepool" --cluster "cluster-1" --zone "us-central1-c" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --node-labels istio-nodepool=true --metadata disable-legacy-endpoints=true,istio-nodepool=true --node-taints istio=true:NoSchedule --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --enable-autoscaling --min-nodes "$MIN_ISTIO_NODES" --max-nodes "7" --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --node-locations "us-central1-c"
```

### 2. Clone istio-to-asm repository
While the cluster is getting deployed, open another shell and clone this repo
```
git clone https://github.com/christopherhendrich/istio-to-asm
```

```
cd istio-to-asm
```

### 3. Download Istio 
Change the version if you prefer to use a different one. 
```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.5 sh - 
cd istio-1.9.5/
export PATH=$PWD/bin:$PATH
cd ..
```

### 4. Download ASM
```
curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.10 > install_asm
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
kubectl apply -f istio-1.9.5/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo
kubectl apply -f istio-1.9.5/samples/bookinfo/networking/bookinfo-gateway.yaml -n bookinfo
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

### [Lab 1: Migrating from default Istio to default ASM](/docs/Default-migration.md)

> "This lab walks you through a migration from a default Istio deployment to a default ASM installation. You will migrate the applictions using a canary process"









# WORK IN PROGRESS BELOW - IGNORE


## Option 1: Using the Istio Operator
#### Install the IstioOperator
```
istioctl operator init
```
Install the Istio Control Plane
```
kubectl create ns istio-system
kubectl apply -f istio/controlplane.yaml 
```
#### Install the Istio Ingress Gateway via k8s resource
```
kubectl create ns istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled 
kubectl apply -f istio/ingress1-deployment.yaml
kubectl apply -f istio/ingress1-service.yaml
kubectl apply -f istio/ingress1-hpa.yaml
kubectl apply -f istio/bookinfo-gateway-custom-ingress.yaml -n bookinfo



### Option 2: Default install using istioctl 
This will install istiod and the default istio-ingressgateway
```
istioctl install
```

## Install the Istio Ingress Gateway
```
kubectl create ns istio-ingress
kubectl label namespace istio-ingress istio-injection=enabled 
kubectl apply -f istio/ingress1-deployment.yaml
kubectl apply -f istio/ingress1-service.yaml
kubectl apply -f istio/ingress1-hpa.yaml
kubectl apply -f istio/bookinfo-gateway-custom-ingress.yaml -n bookinfo
```

## Enable the Istio on the bookinfo namespace
```
kubectl label namespace bookinfo istio-injection=enabled 
kubectl rollout restart deployment -n bookinfo
```

## Test Bookinfo via Istio Ingress Gateway
Grab the public IP of the Istio Ingress Gateway
```
kubectl get service -n istio-ingress
```
User your browser to connect to the Bookinfo app
```
http://[public ip]/productpage
```



## Install ASM 
```
./install_asm   --project_id $PROJECT_ID   --cluster_name cluster-1   --cluster_location us-central1-c  --mode migrate   --ca citadel --verbose --output_dir ./asm/asm-install-files/ --custom-overlay asm/controlplane.yaml --enable-all
```

## Grab revision label
```
kubectl get pod -n istio-system -L istio.io/rev
```

## Create an Istio Ingress Gateway for ASM
We will create a second ingress gateway
Create a test ingress for ASM
```
kubectl create ns asm-ingress
kubectl label namespace asm-ingress istio-injection- istio.io/rev=asm-195-2 --overwrite
kubectl apply -f asm/asm-ingress-deployment.yaml
kubectl apply -f asm/asm-ingress-hpa.yaml
kubectl apply -f asm/asm-ingress-service.yaml
```

## Update bookinfo gateway to use the ASM gateway
```
kubectl apply -f asm/bookinfo-gateway-asm-ingress.yaml -n bookinfo
```

## Grab the external IP of the ASM ingress
```
kubectl get service -n asm-ingress
```
Test that bookinfo is now using the ASM gateway (http://[ASM_GATEWAY_PUBLIC_IP]/productpage)

## Migrate the bookinfo namespace over to ASM
```
kubectl label namespace bookinfo istio.io/rev=asm-195-2 istio-injection- --overwrite
kubectl rollout restart deployment -n default
```

## Confirm that the bookinfo app is still working after we migrted to ASM 
Test the application via http://[ASM_GATEWAY_PUBLIC_IP]/productpage



