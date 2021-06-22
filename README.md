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
11. Uppdate bookinfo gateway to use the new ASM ingress gateway
12. Test Bookinfo app
13. Remove Istio ingress gateway
14. Remove Istio's Istiod
15. Remove IstioOperator



## Create the GKE cluster
We will create a GKE cluster that will include a dedicated nodepool for Istio/ASM. 

Set up a variable for your GCP Project ID
'export PROJECT_ID=[Your project ID]'

```
gcloud beta container --project $PROJECT_ID clusters create "cluster-1" --zone "us-central1-c" --no-enable-basic-auth --cluster-version "1.19.10-gke.1600" --release-channel "regular" --machine-type "e2-medium" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/sada-chendrich-istio-to-asm/global/networks/default" --subnetwork "projects/$PROJECT_ID/regions/us-central1/subnetworks/default" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations "us-central1-c" && gcloud beta container --project $PROJECT_ID node-pools create "istio-nodepool" --cluster "cluster-1" --zone "us-central1-c" --machine-type "e2-standard-4" --image-type "COS_CONTAINERD" --disk-type "pd-standard" --disk-size "100" --node-labels istio-nodepool=true --metadata disable-legacy-endpoints=true,istio-nodepool=true --node-taints istio=true:NoSchedule --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --enable-autoscaling --min-nodes "3" --max-nodes "7" --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --node-locations "us-central1-c"
```

## Clone istio-to-asm repository
while the 

