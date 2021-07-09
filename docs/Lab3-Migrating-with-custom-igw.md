## Lab 3: Migrating from IstioOperator deployed Istio with custom configuration, to ASM with custom Istio ingress gateways and a dedicated Istio nodepool
This example has you install the default Istio profile via IstioOperator, consisting of Istiod and a Istio IngressGateway, install the default ASM 1.10. This is a more real-life scenario. 


### Install the IstioOperator
Install the IstioOperator in the istio-operator namespace.
```
istioctl operator init
```

Output
```
Installing operator controller in namespace: istio-operator using image: docker.io/istio/operator:1.9.6
Operator controller will watch namespaces: istio-system
✔ Istio operator installed                                                                     
✔ Installation complete
```

## Deploy the Istio controlplane
Deploy the Istio controlplane. We are just deploying the "minimal" Istio profile, which only consists of the controlplane (Istiod). 
```
kubectl apply -f istio/controlplane/controlplane.yaml
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
./install_asm   --project_id $PROJECT_ID   --cluster_name cluster-1   --cluster_location us-central1-c  --mode install   --ca citadel --verbose --output_dir ./asm/asm-install-files/ --enable-all --option revisioned-istio-ingressgateway --option ca-migration-citadel --revision_name asm-1102-2
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
 
Install the Mesh-CA validation script. This script will validate that the sidecar is configured with both, the old Citadel, as well as the new Mesh-CA certificate. This will ensure that your applications that you migrate to Mesh-CA are still able to talk to workloads still running with Citadel. 

```
curl https://raw.githubusercontent.com/GoogleCloudPlatform/anthos-service-mesh-packages/release-1.10-asm/scripts/ca-migration/migrate_ca > migrate_ca
chmod +x migrate_ca
sudo apt-get install gawk
```


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

### Validate that the sidecar proxies for the online-boutique workloads on the cluster are configured with both the old and new root certificates:

```
./migrate_ca check-root-cert
```

### Migrate the Bookinfo app to ASM
Congratulations, your first app is migrated. We will repeat the same process for the Bookinfo app. You would rpeat this process for all of your applications until all your applications are migrated to ASM. 
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

### Validate that the sidecar proxies for the online-boutique workloads on the cluster are configured with both the old and new root certificates:
Once all your applications are migrated over, you can check that your applications are configured with certificates of both conrtol planes
```
./migrate_ca check-root-cert
```
Output
```
Checking the root certificates loaded on each pod...

Namespace: asm-system

Namespace: bookinfo
 - details-v1-6d59dcdc58-9mhjv.bookinfo trusts [CITADEL MESHCA]
 - productpage-v1-747cd98958-tdjh4.bookinfo trusts [CITADEL MESHCA]
 - ratings-v1-84b9d5dbfd-jxkv4.bookinfo trusts [CITADEL MESHCA]
 - reviews-v1-cf87f4f76-vzxl7.bookinfo trusts [CITADEL MESHCA]
 - reviews-v2-ffc55cc8-8x6pw.bookinfo trusts [CITADEL MESHCA]
 - reviews-v3-75d6cc6bd4-8dgcd.bookinfo trusts [CITADEL MESHCA]

Namespace: default

Namespace: istio-system
 - istio-ingressgateway-5b47bfbd5f-xqt9r.istio-system trusts [CITADEL MESHCA]
 - istio-ingressgateway-asm-1102-2-distributed-root-785c4f47fmxfn7.istio-system trusts [CITADEL MESHCA]
 - istio-ingressgateway-asm-1102-2-distributed-root-785c4f47frds65.istio-system trusts [CITADEL MESHCA]

Namespace: online-boutique
 - adservice-85c44bf5cf-ncmbt.online-boutique trusts [CITADEL MESHCA]
 - cartservice-8676b4d4bd-wkr72.online-boutique trusts [CITADEL MESHCA]
 - checkoutservice-5c65f69c7f-hxdtr.online-boutique trusts [CITADEL MESHCA]
 - currencyservice-58c98d8c7-trftz.online-boutique trusts [CITADEL MESHCA]
 - emailservice-7c8f6b7b75-7rfqk.online-boutique trusts [CITADEL MESHCA]
 - frontend-c69cd7854-jp2w7.online-boutique trusts [CITADEL MESHCA]
 - loadgenerator-8668f87b8-68tls.online-boutique trusts [CITADEL MESHCA]
 - paymentservice-69c79c5979-pwgpr.online-boutique trusts [CITADEL MESHCA]
 - productcatalogservice-5687c64f4c-qjlmz.online-boutique trusts [CITADEL MESHCA]
 - recommendationservice-59ffbf54bf-wjgk5.online-boutique trusts [CITADEL MESHCA]
 - redis-cart-7c7cb69bdc-682kt.online-boutique trusts [CITADEL MESHCA]
 - shippingservice-95c86c5c5-5kk2t.online-boutique trusts [CITADEL MESHCA]
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

## Migrate to Mesh CA
### Install a new control plane with Mesh CA enabled
Now that we are migrated to an ASM Control Plane, we migrate from Citadel to Mesh CA. 
Create a new ASM control plane revision that has Mesh CA enabled. 
```
./install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name cluster-1 \
  --cluster_location us-central1-c \
  --mode install \
  --ca mesh_ca \
  --enable_all \
  --option revisioned-istio-ingressgateway \
  --option ca-migration-meshca \
  --revision_name asm-1102-2-mesh-ca-migration \
  --output_dir asm-1102-2-mesh-ca-migration
```

Once the command completes, you will see both control planes deployed. 
```
kubectl get pod -n istio-system -L istio.io/rev
```
Output example:
```
NAME                                                              READY   STATUS    RESTARTS   AGE     REV
istio-ingressgateway-asm-1102-2-distributed-root-785c4f47fmxfn7   1/1     Running   0          3h23m   asm-1102-2-distributed-root
istio-ingressgateway-asm-1102-2-distributed-root-785c4f47frds65   1/1     Running   0          3h23m   asm-1102-2-distributed-root
istio-ingressgateway-asm-1102-2-mesh-ca-migration-5f76bb55sqj9h   1/1     Running   0          42s     asm-1102-2-mesh-ca-migration
istio-ingressgateway-asm-1102-2-mesh-ca-migration-5f76bb55zhn9b   1/1     Running   0          57s     asm-1102-2-mesh-ca-migration
istiod-asm-1102-2-distributed-root-64f497f6ff-4stnn               1/1     Running   0          3h23m   asm-1102-2-distributed-root
istiod-asm-1102-2-distributed-root-64f497f6ff-nlc6d               1/1     Running   0          3h23m   asm-1102-2-distributed-root
istiod-asm-1102-2-mesh-ca-migration-5d8d5bbb45-r5zrf              1/1     Running   0          74s     asm-1102-2-mesh-ca-migration
istiod-asm-1102-2-mesh-ca-migration-5d8d5bbb45-rwwtw              1/1     Running   0          74s     asm-1102-2-mesh-ca-migration
```

### Switch the Istio ingress gateway to the new revision. 
```
kubectl patch service -n istio-system istio-ingressgateway --type='json' -p='[{"op": "replace", "path": "/spec/selector/service.istio.io~1canonical-revision", "value": "asm-1102-2-mesh-ca-migration"}]'
```

### Migrate the Bookinfo and Online Boutique applications to the new controlplane
```
kubectl label namespace bookinfo istio.io/rev=asm-1102-2-mesh-ca-migration --overwrite
kubectl rollout restart deployment -n bookinfo
kubectl label namespace online-boutique istio.io/rev=asm-1102-2-mesh-ca-migration --overwrite
kubectl rollout restart deployment -n online-boutique
```

### Verify that the application is working as expected
```
kubectl get pods -n bookinfo -l istio.io/rev=asm-1102-2-mesh-ca-migration
```
Expected output should be similar to:
```
NAME                             READY   STATUS    RESTARTS   AGE
details-v1-7c8f6577b8-7d62n      2/2     Running   0          113s
productpage-v1-7bb76c86d-sqqmr   2/2     Running   0          113s
ratings-v1-b8679d656-wnbpg       2/2     Running   0          113s
reviews-v1-69f57fd9fd-hqx4q      2/2     Running   0          112s
reviews-v2-77775cf696-p98mf      2/2     Running   0          112s
reviews-v3-8569d448fd-c5bjz      2/2     Running   0          112s
```
```
kubectl get pods -n online-boutique -l istio.io/rev=asm-1102-2-mesh-ca-migration
```
Expected output should be similar to:
```
NAME                                     READY   STATUS    RESTARTS   AGE
adservice-78dbcfd4bc-mq7kc               2/2     Running   0          113s
cartservice-866c9bb4dd-4nbpm             2/2     Running   0          113s
checkoutservice-5f6f8cfb87-hm45z         2/2     Running   0          113s
currencyservice-f9859f977-52st7          2/2     Running   0          113s
emailservice-77f47c8c5-dmrjt             2/2     Running   0          112s
frontend-8cc986b94-xs55r                 2/2     Running   0          112s
loadgenerator-574fc68fd8-xbbhp           2/2     Running   3          112s
paymentservice-c4487d8bc-xmtqz           2/2     Running   0          112s
productcatalogservice-69764b77f5-xd967   2/2     Running   0          112s
recommendationservice-5f6d4cb9bf-cf8nl   2/2     Running   0          112s
redis-cart-75c7d79499-wx96f              2/2     Running   0          112s
shippingservice-767b98c9ff-bhvck         2/2     Running   0          111s
```

### Check that yuor applications are still up and accessible
We have migrated to the new ASM control plane now and the workloads are now using Mesh-CA. Confirm that your applciations are still running as epxected.

Open the Online Boutique app in your browser
```
http://[public_ip]
```

Open your Bookinfo application in your browser
```
http://[public_ip]/productpage
```

### Clean up the old Citadel ASM Control Plane
This is very similar to the cleanup we performed for the Istio control plane, but we have to include the revision of the old ASM control plane this time. We also have to make sure we are applying the istiod-service from the folder we used as *output-dir* for this control plane installation.  
```
kubectl apply -f asm-1102-2-mesh-ca-migration/asm/istio/istiod-service.yaml
kubectl delete deploy -l app=istio-ingressgateway,istio.io/rev=asm-1102-2 -n istio-system --ignore-not-found=true
kubectl delete Service,Deployment,HorizontalPodAutoscaler,PodDisruptionBudget istiod-asm-1102-2 -n istio-system --ignore-not-found=true
kubectl delete IstioOperator installed-state-asm-1102-2 -n istio-system
```

### Remove the CA secrets and restart the new control plane
It is recommended to take a backup of the old certificates, in case they are needed for any reason at a later point.
```
kubectl get secret/cacerts -n istio-system -o yaml > save_file_1
kubectl get secret/istio-ca-secret -n istio-system -o yaml > save_file_2
```

Remove the CA secrets in the cluster associated with the old CA
```
kubectl delete secret cacerts istio-ca-secret -n istio-system --ignore-not-found
```
Restart the control plane
```
kubectl rollout restart deployment -n istio-system
```

### Confirm applications are up
We migrated from Istio to ASM and from Citadel to Mesh CA. 
Check that your applications are working as expected for a last time. 

Your applications are still working.
Open the Online Boutique app in your browser
```
http://[public_ip]
```

Open your Bookinfo application in your browser
```
http://[public_ip]/productpage
```


### Congratulations! Your migration from Istio to ASM and from Citadel to Mesh CA is complete!

## Cleanup 
Delete the cluster to stop incurring charges.
```
gcloud container clusters delete cluster-1 --project $PROJECT_ID --zone us-central1-c
rm -rf asm/asm-install-files/*
rm -tf asm-1102-2-mesh-ca-migration
```
