# Work in progress

## Lab 2: Migration of default Istio to default ASM and from Citadel CA to Mesh CA
This example has you install the default Istio profile, consisting of Istiod and a Istio IngressGateway, install the default ASM 1.10 including a revisioned-istio-ingressgateway and migrate the certificate authority from Citadel to the Google managed Mesh-CA. This example is meant to familiarize you with the high-level process and have you complete successful migration from Istio to ASM using the canary method. In real life scenarios with customers that use Istio in production, it is very likely you will have to perform one of the more advanced examples.

Migrating to Anthos Service Mesh certificate authority (Mesh CA) from Istio CA (also known as Citadel) requires migrating the root of trust. Prior to Anthos Service Mesh 1.10, if you wanted to migrate from Istio on Google Kubernetes Engine (GKE) to Anthos Service Mesh with Mesh CA, you needed to schedule downtime because Anthos Service Mesh was not able to load multiple root certificates. Therefore, during the migration, the newly deployed workloads trust the new root certificate, while others trust the old root certificate. Workloads using certificates signed by different root certificates can't authenticate with each other. This means that mutual TLS (mTLS) traffic is interrupted during the migration. The entire cluster only fully recovers when the control plane and all workloads in all namespaces are redeployed with Mesh CA's certificate. If your mesh has multiple clusters with workloads that send requests to workloads on another cluster, all workloads on those clusters need to be updated as well.

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
kubectl apply -f ./microservices-demo/release -n online-boutique
kubectl apply -f istio-1.9.5/samples/bookinfo/networking/bookinfo-gateway.yaml -n bookinfo
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

Rerun the commands until you see *2/2 Ready* for each pod in both namespaces.

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
We will install the default version of ASM, including a revisioned ingress gateway. At this point we still need to use *--ca citadel*, as the switch to Mesh-CA will happen in a later step, but we will add the *--option ca-migration-citadel*, compared to Lab 1. 

```
./install_asm   --project_id $PROJECT_ID   --cluster_name cluster-1   --cluster_location us-central1-c  --mode migrate   --ca citadel --verbose --output_dir ./asm/asm-install-files/ --enable-all --option revisioned-istio-ingressgateway --option ca-migration-citadel
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
rm -rf asm/asm-install-files/*
```
