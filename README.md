# istio-to-asm migration example

## Summary

1. We will create a GKE cluster
2. Install the Istio Operator
3. Deploy the Istio controlplane (Istiod) via IstioOperator
4. Deploy an ingress gateway via k8s YAML manifests (deployment, service, hpa)
5. Install bookinfo app 
6. Configure bookinfo to use the istio ingress gateway
7. Install ASM via script
8. Create a new ingress gateway for ASM
9. Inject bookinfo namespace with ASM revision label
10. Perform rolling update on bookinfo app to inject ASM sidecar
11. Update bookinfo gateway to use the new ASM ingress gateway
12. Test Bookinfo app
13. Remove Istio ingress gateway
14. Remove Istio's Istiod
15. Remove IstioOperator



## Create the GKE cluster
We will create a GKE cluster that will include a dedicated nodepool for Istio/ASM. 

Set up a variable for your GCP Project ID

```
export PROJECT_ID=[Your project ID]
```

Create the cluster
```
gcloud beta container --project $PROJECT_ID clusters create "cluster-1" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.19.10-gke.1600" --release-channel "regular" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/$PROJECT_ID/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-pool "${PROJECT_ID}.svc.id.goog" --enable-shielded-nodes --enable-autoscaling --min-nodes "3" --max-nodes "7" --node-locations "us-central1-c" && gcloud beta container --project $PROJECT_ID node-pools create "istio-nodepool" --cluster "cluster-1" --zone "us-central1-c" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --node-labels istio-nodepool=true --metadata disable-legacy-endpoints=true,istio-nodepool=true --node-taints istio=true:NoSchedule --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --enable-autoscaling --min-nodes "3" --max-nodes "7" --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --node-locations "us-central1-c"
```

## Clone istio-to-asm repository
While the cluster is getting deployed, open another shell and clone this repo
```
git clone https://github.com/christopherhendrich/istio-to-asm
```

```
cd istio-to-asm
```

## Download Istio
```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.4 sh - 
cd istio-1.9.4/
export PATH=$PWD/bin:$PATH
cd ..
```


## Connect to the GKE cluster
Once the cluster is up and running connect to it via Cloud SDK
```
gcloud container clusters get-credentials cluster-1 --zone us-central1-c --project $PROJECT_ID
```

## Install the Bookinfo app 
```
kubectl create ns bookinfo
kubectl apply -f istio-1.9.4/samples/bookinfo/platform/kube/bookinfo.yaml -n bookinfo
```
## Install Online Boutique
We will install a second application to understand the behaviour of the migration when one app is on istio and the other on ASM
```
kubectl create ns online-boutique
kubectl label namespace online-boutique istio-injection=enabled
git clone https://github.com/GoogleCloudPlatform/microservices-demo.git
kubectl apply -f ./microservices-demo/release -n online-boutique
```

## Install Istio
### Option 1: Using the Istio Operator
Install the IstioOperator
```
istioctl operator init
```
Install the Istio Control Plane
```
kubectl create ns istio-system
kubectl apply -f istio/controlplane.yaml 
```
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


## Download the ASM script
```
curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.9 > install_asm

chmod +x install_asm
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



