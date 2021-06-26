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

## Example 1: Migration of default Istio to default ASM
This example has you install the default Istio profile, consisting of Istiod and a Istio IngressGateway, install the default ASM 1.10 including a revisioned-istio-ingressgateway. This example is to familiarize you with the high-level process and have you complete successful migration from Istio to ASM. 
In real life scenarios with customers that use Istio in production, it is very likely you will have to perform one of the more advanced examples.

### Install Istio
Install Istiod (Istio control plane) using 'istioctl'
```
istioctl install
```
This will install 'istiod' and the 'istio-ingressgateway' in the 'istio-system' namespace.

Example:
```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-85c449d886-4wgng   1/1     Running   0          70s
istiod-9445656d7-9ppkj                  1/1     Running   0          81s
```

### Inject the istio sidecar proxy into the applications
Perform a rollout restart to inject the enoy sidecar proxy
```
kubectl rollout restart deployment -n bookinfo
kubectl rollout restart deployment -n online-boutique
```
You will see that each pod will now have 2 containers. 
```
kubectl get po -n online-boutique
kubectl get po -n bookinfo
```
Example output:
Online Boutique Namespace
```
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-5d85844c68-4dxv9               2/2     Running   0          3m57s
cartservice-5c6cd884b5-9lgg7             2/2     Running   1          3m57s
checkoutservice-798f794848-rn645         2/2     Running   0          3m56s
currencyservice-dc6d57756-mbnpn          2/2     Running   0          3m56s
emailservice-56f44bc99d-jgx92            2/2     Running   0          3m56s
frontend-b6d85b689-zzzmc                 2/2     Running   0          3m56s
loadgenerator-5cd76cfdfc-77725           2/2     Running   2          3m55s
paymentservice-789c7cfb74-pr9l8          2/2     Running   0          3m54s
productcatalogservice-dd6fbcd5b-fx98g    2/2     Running   0          3m54s
recommendationservice-6bcfbd9f4d-slmx9   2/2     Running   0          3m54s
redis-cart-5cc4cdb588-7z5dr              2/2     Running   0          3m54s
shippingservice-66ccc998d4-ftsmh         2/2     Running   0          3m54s
```

Bookinfo Namespace
```
NAME                              READY   STATUS    RESTARTS   AGE
details-v1-599458db76-wmbtj       2/2     Running   0          2m43s
productpage-v1-6df87b8684-csxrz   2/2     Running   0          2m43s
ratings-v1-55496c99f6-6rd4f       2/2     Running   0          2m43s
reviews-v1-7cb48bfcfb-2mg4f       2/2     Running   0          2m42s
reviews-v2-65ddc99956-k5ffs       2/2     Running   0          2m42s
reviews-v3-8f967998d-ljhvp        2/2     Running   0          2m42s
```

Rerun the commands until you also see *2/2 Ready* for each pod in both namespaces.

### Verify applications are working as expected
Both applications are now reachable via the Istio Ingress Gateway. 
Grab the external IP Address:
```
kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

The bookinfo is available at
```
http://[External IP]/productpage
```
The Online Boutique is available at
``` 
http://[External IP]
```

### Install ASM 
We will install the default version of ASM, including a revisioned ingress gateway and we will continue to use Citadel as certificate authority.

```
./install_asm   --project_id $PROJECT_ID   --cluster_name cluster-1   --cluster_location us-central1-c  --mode migrate   --ca citadel --verbose --output_dir ./asm/asm-install-files/ --enable-all --option revisioned-istio-ingressgateway
```

After the successful installation, you will see both istio and ASM control planes as well as the Istio and ASM ingress gateways
```
kubectl get pod -n istio-system -L istio.io/rev
```
Example output
```
NAME                                               READY   STATUS    RESTARTS   AGE   REV
istio-ingressgateway-85c449d886-4wgng              1/1     Running   0          16m   default
istio-ingressgateway-asm-1102-2-847c4d4c7d-5nlzx   1/1     Running   0          44s   asm-1102-2
istio-ingressgateway-asm-1102-2-847c4d4c7d-f4fr5   1/1     Running   0          28s   asm-1102-2
istiod-9445656d7-9ppkj                             1/1     Running   0          16m   default
istiod-asm-1102-2-f6d5f54f-9k8pl                   1/1     Running   0          57s   asm-1102-2
istiod-asm-1102-2-f6d5f54f-sn5pd                   1/1     Running   0          57s   asm-1102-2
```


### Cut over to the ASM version of the Istio Ingress Gateway deployment 
The Istio Ingress Gateway consists of two items. 
 1. The gateway service
 2. The gateway deployment 
  
In order to maintain the external IP of the Istio Ingress Gateway, we created a copy of the Ingress Gateway deployment via the *--option revisioned-istio-ingressgateway* flag during the ASM installation. The gateway service selects both gateways and sends traffic to the correct deployment via the istio.io/rev= label. 

 Switch the istio-ingressgateway to the new revision. In the following command, change REVISION to the value that matches the revision label of the new version.
 ```
 kubectl patch service -n istio-system istio-ingressgateway --type='json' -p='[{"op": "replace", "path": "/spec/selector/service.istio.io~1canonical-revision", "value": "asm-1102-2"}]'
```

While we added the revision to the gateway service, your applications are still working as expected. Go ahead and retry your applications!

### Replace the Istio sidecar with the ASM sidecar for the Online Boutique application 
Remove the *istio-injection=enabled* label and add the *istio.io/rev=asm-1102-2* label to the online-boutique namespace.
```
kubectl label namespace online-boutique istio.io/rev=asm-1102-2 istio-injection- --overwrite
```
While the namespace labels have now been changed, your application has not been affected. The Istio control plane is still connected. 
In order to complete the cutover to the ASM sidecars, we need to restart the pods. That will trigger the injectino of the ASM sidecar. 

```
kubectl rollout restart deployment -n online-boutique
```
Check on your application's migration
```
kubectl get pod -n online-boutique -L istio.io/rev
```
You can see that your old pods with the Istio *default* revision are getting replaced with pods with the ASM *asm-1102-2* revision. 

Example:
```
NAME                                     READY   STATUS        RESTARTS   AGE     REV
adservice-6dcb7bf4-pkw2h                 0/2     Terminating   0          3m34s   default
adservice-6fdd85486c-xsqqk               2/2     Running       0          36s     asm-1102-2
cartservice-65c8c559cf-t6m2s             0/2     Terminating   0          3m34s   default
cartservice-7cf98bb446-7qvsl             2/2     Running       0          36s     asm-1102-2
checkoutservice-76584c9fd5-9xxtv         2/2     Running       0          36s     asm-1102-2
currencyservice-577f67c6df-j4lsh         2/2     Running       0          36s     asm-1102-2
emailservice-65dfd4d689-gvvb6            2/2     Running       0          36s     asm-1102-2
frontend-5785f67758-fpsx5                2/2     Running       0          35s     asm-1102-2
frontend-7ffcd9f9-5tb9r                  0/2     Terminating   0          3m33s   default
loadgenerator-544c94c59d-5dlzl           2/2     Running       2          35s     asm-1102-2
paymentservice-6b7485bbfc-klh7l          2/2     Running       0          35s     asm-1102-2
productcatalogservice-575786449-5cqr9    2/2     Running       0          35s     asm-1102-2
recommendationservice-75c7bb9db5-r4clq   2/2     Running       0          35s     asm-1102-2
redis-cart-696bdc9779-6k2nk              2/2     Running       0          34s     asm-1102-2
shippingservice-7c65cd54f-t8smb          2/2     Running       0          34s     asm-1102-2
```

Go ahead and test your Online Boutique application. It is still running, while the migraiton to the ASM control plane occurs. 

Run the command again until all pods have the new revision label and are up and running. 
```
kubectl get pod -n online-boutique -L istio.io/rev
```

Output:
```
NAME                                     READY   STATUS    RESTARTS   AGE     REV
adservice-6fdd85486c-xsqqk               2/2     Running   0          4m30s   asm-1102-2
cartservice-7cf98bb446-7qvsl             2/2     Running   0          4m30s   asm-1102-2
checkoutservice-76584c9fd5-9xxtv         2/2     Running   0          4m30s   asm-1102-2
currencyservice-577f67c6df-j4lsh         2/2     Running   0          4m30s   asm-1102-2
emailservice-65dfd4d689-gvvb6            2/2     Running   0          4m30s   asm-1102-2
frontend-5785f67758-fpsx5                2/2     Running   0          4m29s   asm-1102-2
loadgenerator-544c94c59d-5dlzl           2/2     Running   2          4m29s   asm-1102-2
paymentservice-6b7485bbfc-klh7l          2/2     Running   0          4m29s   asm-1102-2
productcatalogservice-575786449-5cqr9    2/2     Running   0          4m29s   asm-1102-2
recommendationservice-75c7bb9db5-r4clq   2/2     Running   0          4m29s   asm-1102-2
redis-cart-696bdc9779-6k2nk              2/2     Running   0          4m28s   asm-1102-2
shippingservice-7c65cd54f-t8smb          2/2     Running   0          4m28s   asm-1102-2
```

### Test the Online Boutique application
At this point, you would test your Online Boutique application to make sure it is working as expected. Your Bookinfo application, still running on the istio control plane, is also still working and has not been affected. Go ahead and test

Open the Online Boutique app in your browser
```
http://[public_ip]
```

Open your Bookinfo application in your browser
```
http://[public_ip]/productpage
```
Notice that both applications, even though one is running on the Istio control plane and the other on the ASM control plane, are both accessible via the same Ingress Gateway public endpoint. 

```
kubectl get pod -n online-boutique -L istio.io/rev
```
Output
```
NAME                                     READY   STATUS    RESTARTS   AGE     REV
adservice-6fdd85486c-xsqqk               2/2     Running   0          4m30s   asm-1102-2
cartservice-7cf98bb446-7qvsl             2/2     Running   0          4m30s   asm-1102-2
checkoutservice-76584c9fd5-9xxtv         2/2     Running   0          4m30s   asm-1102-2
currencyservice-577f67c6df-j4lsh         2/2     Running   0          4m30s   asm-1102-2
emailservice-65dfd4d689-gvvb6            2/2     Running   0          4m30s   asm-1102-2
frontend-5785f67758-fpsx5                2/2     Running   0          4m29s   asm-1102-2
loadgenerator-544c94c59d-5dlzl           2/2     Running   2          4m29s   asm-1102-2
paymentservice-6b7485bbfc-klh7l          2/2     Running   0          4m29s   asm-1102-2
productcatalogservice-575786449-5cqr9    2/2     Running   0          4m29s   asm-1102-2
recommendationservice-75c7bb9db5-r4clq   2/2     Running   0          4m29s   asm-1102-2
redis-cart-696bdc9779-6k2nk              2/2     Running   0          4m28s   asm-1102-2
shippingservice-7c65cd54f-t8smb          2/2     Running   0          4m28s   asm-1102-2
```

```
kubectl get pod -n bookinfo -L istio.io/rev
```
Output
```
NAME                              READY   STATUS    RESTARTS   AGE   REV
details-v1-599458db76-wmbtj       2/2     Running   0          40m   default
productpage-v1-6df87b8684-csxrz   2/2     Running   0          40m   default
ratings-v1-55496c99f6-6rd4f       2/2     Running   0          40m   default
reviews-v1-7cb48bfcfb-2mg4f       2/2     Running   0          40m   default
reviews-v2-65ddc99956-k5ffs       2/2     Running   0          40m   default
reviews-v3-8f967998d-ljhvp        2/2     Running   0          40m   default
```


### Migrate the Bookinfo app to ASM
Congratulations, your first app is migrated. We will rpeat the same process for the Bookinfo app. You would rpeat this process for all of your applications until all your applications are migrated to ASM. 
```
kubectl label namespace bookinfo istio.io/rev=asm-1102-2 istio-injection- --overwrite
kubectl rollout restart deployment -n bookinfo
```

Confirm that the bookinfo app is now also injected with the ASM sidecar proxy.
```
kubectl get pod -n bookinfo -L istio.io/rev
```
Ouput
```
NAME                              READY   STATUS    RESTARTS   AGE   REV
details-v1-5845bf4697-rbm7l       2/2     Running   0          41s   asm-1102-2
productpage-v1-664788f66c-h2s2q   2/2     Running   0          41s   asm-1102-2
ratings-v1-75c4fd7585-888dg       2/2     Running   0          41s   asm-1102-2
reviews-v1-86b48465c7-5kztk       2/2     Running   0          41s   asm-1102-2
reviews-v2-7bd994dbd9-zvbqf       2/2     Running   0          41s   asm-1102-2
reviews-v3-86dd7c489c-c66sm       2/2     Running   0          40s   asm-1102-2
```

### Finalize the migration

Configure the validating webhook to use the new control plane.
```
kubectl apply -f asm/asm-install-files/asm/istio/istiod-service.yaml
```

Delete the old istio-ingressgatewayDeployment.
```
kubectl delete deploy/istio-ingressgateway -n istio-system
```

Delete the old version of istiod
```
kubectl delete Service,Deployment,HorizontalPodAutoscaler,PodDisruptionBudget istiod -n istio-system --ignore-not-found=true
```
Remove the old version of the IstioOperator configuration

```
kubectl delete IstioOperator installed-state -n istio-system
```

You will now only find your ASM Istiod and Ingress Gateway in the istio-system namespace. 
```
kubectl get po -n istio-system
```
Output
```
NAME                                               READY   STATUS    RESTARTS   AGE
istio-ingressgateway-asm-1102-2-847c4d4c7d-5nlzx   1/1     Running   0          43m
istio-ingressgateway-asm-1102-2-847c4d4c7d-f4fr5   1/1     Running   0          42m
istiod-asm-1102-2-f6d5f54f-9k8pl                   1/1     Running   0          43m
istiod-asm-1102-2-f6d5f54f-sn5pd                   1/1     Running   0          43m
```


Your applications are still working.
Open the Online Boutique app in your browser
```
http://[public_ip]
```

Open your Bookinfo application in your browser
```
http://[public_ip]/productpage
```

The Anthos Service Mesh UI is also displaying your services now
```
https://console.cloud.google.com/anthos/services?project=[PROJECT_ID]
```

### Congratulations! Your migration is complete!

## Cleanup 
Delete the cluster to stop incurring charges.
```
gcloud container clusters delete cluster-1 --project $PROJECT_ID --zone us-central1-c
```












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



