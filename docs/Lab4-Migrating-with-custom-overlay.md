## Lab 4: Migrating from IstioOperator deployed Istio with custom configuration, to ASM with custom Istio ingress gateways and a dedicated Istio nodepool
This example of a customer have the Istio controlplane with a custom configuration installed via IstioOperator. 



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

### Deploy the Istio controlplane
Deploy the Istio controlplane. We are using a custom configuration of the control plane. This IstioOperator manifest also includes a Istio IngressGateway with a custom configuration 
```
kubectl create ns istio-system
kubectl apply -f istio/controlplane/custom-controlplane.yaml
```
### Set up the central gateway resource
We will be using a central gateway resource that all application virtual services will point to. 
```
kubectl apply -f istio/gateways-and-virtualservices/gateway-object.yaml
```
### Configure the VirtualServices for your worklods to use the central-gateway
```
kubectl apply -f iistio/gateways-and-virtualservices/bookinfo-vs.yaml
kubectl apply -f iistio/gateways-and-virtualservices/online-boutique-vs.yaml
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

## Install ASM Controlplane
We will install ASM using a custom overlay file. The overlay file includes a custom configuration that was used for the Istio installation. This ensures that the ASM mesh configuration is the same as the current Istio mesh configuration.  At this point we still need to use *--ca citadel*, as the switch to Mesh-CA will happen in a later step, but we will add the *--option ca-migration-citadel*. We are not deploying a ingress gateway at this time, sa we plan to create a new gateway in its own namespace, to follow best practices. 



### *Option 1 - Terraform*
```
cd asm/terraform-custom-controlplane-citadel
terraform init
terraform plan
terraform apply --auto-approve
cd ../..
```

### *Option 2 - install_asm script*
```
./install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $ZONE \
  --mode install \
  --ca citadel \
  --enable_all \
  --option ca-migration-citadel \
  --revision_name asm-1102-2-citadel  \
  --output_dir outdir/ \
  --custom_overlay $PWD/asm/controlplane.yaml
```

After the successful installation, you will see both istio and ASM control planes as well as the Istio and ASM ingress gateways
```
kubectl get pod -n istio-system -L istio.io/rev
```
Example output
```
NAME                                         READY   STATUS    RESTARTS   AGE     REV
istio-ingressgateway-7f4ddfb5d4-2t2jb        1/1     Running   0          4m15s   default
istio-ingressgateway-7f4ddfb5d4-rgjxg        1/1     Running   0          4m15s   default
istio-ingressgateway-7f4ddfb5d4-trw8c        1/1     Running   0          4m30s   default
istiod-7f7bd484fd-4wgq4                      1/1     Running   0          4m18s   default
istiod-7f7bd484fd-xn44s                      1/1     Running   0          4m35s   default
istiod-asm-1102-2-citadel-55f6fb4fc6-mxd2c   1/1     Running   0          33s     asm-1102-2-citadel
istiod-asm-1102-2-citadel-55f6fb4fc6-txzpz   1/1     Running   0          33s     asm-1102-2-citadel
```
You can see that we now have a ASM control plane, consisting of 2 pods. 

### Create the new gateway that will reside in its own namespace
```
kubectl create ns asm-ingress
kubectl label namespace asm-ingress istio.io/rev=asm-1102-2-citadel istio-injection- --overwrite
kubectl apply -f asm/ingress-gateway/citadel
```

### Identify the ip address used for the ASM IngressGateway Service
```
kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

If you try to access the applications via the asm-ingressgateway IP, you will find that they are not available, as the applications still run on the Istio service mesh. 


### Move the app that will be used as canary over to ASM 
For our example here,the bookinfo app will be our canary. 

```
kubectl label namespace bookinfo istio.io/rev=asm-1102-2-citadel istio-injection- --overwrite
kubectl rollout restart deployment -n bookinfo
```
Create the gateway object in the asm-ingress namespace,that points to the new ASM ingress gateway.
```
kubectl apply -f asm/ingress-gateway/gateway-resource.yaml 
```

At this point the bookinfo App is still reachable via the Istio Ingress Gateway 
```
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
```

Deploy a second virtual service for the Bookinfo app with a unique name that points to the new central-gateway gateway resource in the asm-ingress namespace.
We are deploying this second virtual gateway to ensure we have no downtime for the application while we are testing it with the ASM service mesh and Ingress Gateway. 

```
kubectl apply -f asm/ingress-gateway/bookinfo-vs-asm-citadel.yaml 
```

The Bookinfo application is now accessible via both Ingress Gateway IPs, while Online Boutique is still only connected to the Istio mesh and Ingress Gateway. 
```
./check-my-apps.sh 
```

Output
```
Online Boutique via Istio Ingress Gateway

HTTP/1.1 200 OK
set-cookie: shop_session-id=791c5fef-9bf5-483e-b714-0d7753c5ecde; Max-Age=172800
date: Wed, 14 Jul 2021 20:03:36 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 44
server: istio-envoy
transfer-encoding: chunked



Bookinfo via Istio Ingress Gateway

HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 5179
server: istio-envoy
date: Wed, 14 Jul 2021 20:03:37 GMT
x-envoy-upstream-service-time: 46



Online Boutique via ASM Ingress Gateway

HTTP/1.1 404 Not Found
date: Wed, 14 Jul 2021 20:03:38 GMT
server: istio-envoy
transfer-encoding: chunked



Bookinfo via ASM Ingress Gateway

HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 4183
server: istio-envoy
date: Wed, 14 Jul 2021 20:03:38 GMT
x-envoy-upstream-service-time: 29

```


### Migrate the remaining applications to ASM
In our case this means migrating the Online Botique app. 
First we migrate the app to the ASM Service Mesh. 
```
kubectl label namespace online-boutique istio.io/rev=asm-1102-2-citadel istio-injection- --overwrite
kubectl rollout restart deployment -n online-boutique
```


Create the new new virtual service object for the Online Boutique app. 
```
kubectl apply -f asm/ingress-gateway/online-boutique-vs.yaml 
```
Both of the applications are now accessible via both Ingress Gateways
```
./check-my-apps.sh
```

You can also test via your browser. 


### Confirm that both CA certificates are now present in your pods
Install the Mesh-CA validation script. This script will validate that the sidecar is configured with both, the old Citadel, as well as the new Mesh-CA certificate. This will ensure that your applications that you migrate to Mesh-CA are still able to talk to workloads still running with Citadel. 

```
curl https://raw.githubusercontent.com/GoogleCloudPlatform/anthos-service-mesh-packages/release-1.10-asm/scripts/ca-migration/migrate_ca > migrate_ca
chmod +x migrate_ca
sudo apt-get install gawk
```

Validate that the sidecar proxies for the workloads on the cluster are configured with both the old and new root certificates:
```
./migrate_ca check-root-cert
```

Expected Output
```
Checking the root certificates loaded on each pod...

Namespace: asm-ingress
 - asm-ingressgateway-854fdbdf65-h6vkp.asm-ingress trusts [CITADEL MESHCA]
 - asm-ingressgateway-854fdbdf65-mkf4q.asm-ingress trusts [CITADEL MESHCA]
 - asm-ingressgateway-854fdbdf65-xf69c.asm-ingress trusts [CITADEL MESHCA]

Namespace: asm-system

Namespace: bookinfo
 - details-v1-59b7878765-gpntw.bookinfo trusts [CITADEL MESHCA]
 - productpage-v1-f8f876f59-qpxfb.bookinfo trusts [CITADEL MESHCA]
 - ratings-v1-59db7d4485-pgnf9.bookinfo trusts [CITADEL MESHCA]
 - reviews-v1-7fb9d5b49c-h9qtq.bookinfo trusts [CITADEL MESHCA]
 - reviews-v2-76c6bcc6f-qmtcf.bookinfo trusts [CITADEL MESHCA]
 - reviews-v3-77bbb96ff7-7xf7q.bookinfo trusts [CITADEL MESHCA]

Namespace: default

Namespace: istio-operator

Namespace: istio-system
 - istio-ingressgateway-7f4ddfb5d4-6sm96.istio-system trusts [CITADEL MESHCA]
 - istio-ingressgateway-7f4ddfb5d4-kzdj7.istio-system trusts [CITADEL MESHCA]
 - istio-ingressgateway-7f4ddfb5d4-llrhb.istio-system trusts [CITADEL MESHCA]

Namespace: online-boutique
 - adservice-7b4459d485-vbpvx.online-boutique trusts [CITADEL MESHCA]
 - cartservice-866cc789f6-sf67g.online-boutique trusts [CITADEL MESHCA]
 - checkoutservice-844f84c69f-2l6tg.online-boutique trusts [CITADEL MESHCA]
 - currencyservice-688d4c69f9-s6hd2.online-boutique trusts [CITADEL MESHCA]
 - emailservice-744d9c6b99-tbxtb.online-boutique trusts [CITADEL MESHCA]
 - frontend-598ff4f7cb-g5ppr.online-boutique trusts [CITADEL MESHCA]
 - loadgenerator-fb8cf57b4-qvc9q.online-boutique trusts [CITADEL MESHCA]
 - paymentservice-8759b47cf-t9zxd.online-boutique trusts [CITADEL MESHCA]
 - productcatalogservice-7bd8bfb95f-mkzvc.online-boutique trusts [CITADEL MESHCA]
 - recommendationservice-75d7447c4c-6v8vt.online-boutique trusts [CITADEL MESHCA]
 - redis-cart-59d7cccd6-djdzw.online-boutique trusts [CITADEL MESHCA]
 - shippingservice-85d9c89794-tpnvz.online-boutique trusts [CITADEL MESHCA]
 ```
 
 ### Cutover to the new Ingress Gateway
 At this point, once your applications are testing using the new Ingress Gateway, point DNS/AppFirewall/LoadBalancer or whatever you have sitting in front of your Istio Ingress Gateway, to the new ASM Ingress Gateway IP. 
 
 
 
### Finalize the migration
At this time, all of your workloads are migrated from Istio to ASM and we moved to a new Ingress Gateway and Gateway resource, located in their own namespace, as recommended by Istio and Google. 
We still are using Citadel at this time. Before we move on to migrating from Citadel to Mesh we will remove the old Istio environment. 


Configure the validating webhook to use the new control plane.
```
kubectl apply -f asm/terraform-custom-controlplane-citadel/outdir/asm/istio/istiod-service.yaml
```
Output
```
service/istiod configured
```

Delete the old istio-ingressgatewayDeployment.
```
kubectl delete deploy/istio-ingressgateway -n istio-system
```

Delete the old version of istiod
```
kubectl delete Service,Deployment,HorizontalPodAutoscaler,PodDisruptionBudget istiod -n istio-system --ignore-not-found=true
```
Delete the IstioOperator and IstioOperator namespace
```
istioctl operator remove
kubectl delete ns istio-operator
```

Remove the old version of the IstioOperator configuration

```
kubectl delete IstioOperator istio-controlplane -n istio-system
```

You will now only find your ASM Istiod in the istio-system namespace. 
```
kubectl get pod -n istio-system -L istio.io/rev
```
Output
```
NAME                                                   READY   STATUS    RESTARTS   AGE     REV
istiod-asm-1102-2-citadel-7bff8d6678-rk5bm   1/1     Running   0          3h34m   asm-1102-2-citadel
istiod-asm-1102-2-citadel-7bff8d6678-thwr9   1/1     Running   0          3h34m   asm-1102-2-citadel
```

And your Ingress Gateway is now in its own namespace
```
kubectl get pod -n asm-ingress -L istio.io/rev
``` 
Output
```
AME                                  READY   STATUS    RESTARTS   AGE    REV
asm-ingressgateway-854fdbdf65-h6vkp   1/1     Running   0          161m   asm-1102-2-citadel
asm-ingressgateway-854fdbdf65-mkf4q   1/1     Running   0          161m   asm-1102-2-citadel
asm-ingressgateway-854fdbdf65-xf69c   1/1     Running   0          161m   asm-1102-2-citadel
```

## Migrating from Citadel to Mesh CA


### Deploy the ASM controlplane that uses Mesh CA 
We will deploy a second ASM controlplane with a different revision-label and the --ca meshca option. 

### *Option 1 - Terraform*
The control plane is going to be deployed via Terraform.
```
cd asm/terraform-custom-controlplane-mesh-ca/
terraform init
terraform plan 
terraform apply --auto-approve
cd ../..
```
End of output
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

### *Option 2 - install_asm script*
```
./install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $ZONE \
  --mode install \
  --ca mesh_ca \
  --enable_all \
  --option ca-migration-meshca \
  --revision_name asm-1102-2-meshca  \
  --output_dir outdir-meshca/ \
  --custom_overlay $PWD/asm/controlplane.yaml
```


You will now have two ASM controlplanes with differnt revision labels 
```
kubectl get pod -n istio-system -L istio.io/rev
```
Output
```
NAME                                         READY   STATUS    RESTARTS   AGE   REV
istiod-asm-1102-2-citadel-67bd6cfbcc-d4mzw   1/1     Running   0          14m   asm-1102-2-citadel
istiod-asm-1102-2-citadel-67bd6cfbcc-z85wf   1/1     Running   0          14m   asm-1102-2-citadel
istiod-asm-1102-2-meshca-5b685fd8f7-8xbzg    1/1     Running   0          27s   asm-1102-2-meshca
istiod-asm-1102-2-meshca-5b685fd8f7-jkc79    1/1     Running   0          27s   asm-1102-2-meshca
```

### Deploy a new ASM Ingress Gateway deployment 
We will keep using the Ingress Gateway service, but the deployment and hpa will be new deployments, so we can migrate our workloads with virtually zero downtime. 
```
kubectl apply -f asm/ingress-gateway/meshca/
```
This deployed a new ingress gateway deployment and hpa with the new revision label attached.

### Switch the istio-ingressgateway to the new revision. 
```
kubectl patch service -n asm-ingress asm-ingressgateway --type='json' -p='[{"op": "replace", "path": "/spec/selector/service.istio.io~1canonical-revision", "value": "asm-1102-2-meshca"}]'
```

Note: If the ingress gateway deployments do not have the *service.istio.io/canonical-revision*, the application will not be accessible after this point. To fix this, either add the required label to the appropriate ingress gateway deployment, or deleet the  */spec/selector/service.istio.io~1canonical-revision* from the service.

### Migrate the first application to the new ASM Mesh CA controlplane 
```
kubectl label namespace bookinfo istio.io/rev=asm-1102-2-meshca --overwrite
kubectl rollout restart deployment -n bookinfo
```

Confirm that both application are still working (HTTP/1.1 200 OK) via the ASM Ingress Gateway. 
```
./check-my-apps.sh
```
Expected example output 
```
Online Boutique via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Bookinfo via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Online Boutique via ASM Ingress Gateway
HTTP/1.1 200 OK
set-cookie: shop_session-id=cccf66d8-ed9a-43e4-8da1-71fc1fed935a; Max-Age=172800
date: Wed, 14 Jul 2021 20:36:52 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 46
server: istio-envoy
transfer-encoding: chunked


Bookinfo via ASM Ingress Gateway
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 5183
server: istio-envoy
date: Wed, 14 Jul 2021 20:36:55 GMT
x-envoy-upstream-service-time: 1489
```

### Migrate the rest of your applications to the new ASM Mesh CA controlplane
In our case this will only involve the Online-Boutqiue app. 
```
kubectl label namespace online-boutique istio.io/rev=asm-1102-2-meshca --overwrite
kubectl rollout restart deployment -n online-boutique
```

### Confirm one more time that your applciations are migrated and accessible
Confirm that the Mesh CA revision label is present on your workloads
Bookinfo
```
kubectl get pod -n bookinfo -L istio.io/rev
```
Example output
```
NAME                              READY   STATUS    RESTARTS   AGE    REV
details-v1-5c8c468f5d-tw5zr       2/2     Running   0          3m1s   asm-1102-2-meshca
productpage-v1-85d8495dc4-lwrhr   2/2     Running   0          3m1s   asm-1102-2-meshca
ratings-v1-79dc79d95d-8vf62       2/2     Running   0          3m1s   asm-1102-2-meshca
reviews-v1-57cf5fd96b-zhjvm       2/2     Running   0          3m1s   asm-1102-2-meshca
reviews-v2-77cfdf74b-pcv8v        2/2     Running   0          3m1s   asm-1102-2-meshca
reviews-v3-77b9874858-6vkjd       2/2     Running   0          3m1s   asm-1102-2-meshca
```
Online Boutique
```
kubectl get pod -n online-boutique -L istio.io/rev
```
Example output
```
NAME                                     READY   STATUS    RESTARTS   AGE     REV
adservice-57949ff959-qwklm               2/2     Running   0          6m42s   asm-1102-2-meshca
cartservice-85674b67bb-wh9ds             2/2     Running   0          6m42s   asm-1102-2-meshca
checkoutservice-6cf77999c7-vxvkt         2/2     Running   0          6m42s   asm-1102-2-meshca
currencyservice-79c99596f7-57vgx         2/2     Running   0          6m41s   asm-1102-2-meshca
emailservice-8b44f99d5-5rs79             2/2     Running   0          6m41s   asm-1102-2-meshca
frontend-7d59b68b9d-g6g6m                2/2     Running   0          6m39s   asm-1102-2-meshca
loadgenerator-55b4cbd49d-pg5hj           2/2     Running   0          6m41s   asm-1102-2-meshca
paymentservice-7b6bb96945-q9jcq          2/2     Running   0          6m38s   asm-1102-2-meshca
productcatalogservice-7694b54797-tnwlw   2/2     Running   0          6m39s   asm-1102-2-meshca
recommendationservice-7f5d9497f7-x44ch   2/2     Running   0          6m39s   asm-1102-2-meshca
redis-cart-84c59cb95f-db8jw              2/2     Running   0          6m40s   asm-1102-2-meshca
shippingservice-b74586c65-p44hl          2/2     Running   0          6m40s   asm-1102-2-meshca
```

Confirm that your apps are still reachable via the ASM Ingress Gateway
```
./check-my-apps.sh 
```
Example output
```
Online Boutique via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Bookinfo via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Online Boutique via ASM Ingress Gateway
HTTP/1.1 200 OK
set-cookie: shop_session-id=110d0be9-436e-4b26-9879-50d91780aa2a; Max-Age=172800
date: Wed, 14 Jul 2021 20:49:18 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 53
server: istio-envoy
transfer-encoding: chunked

Bookinfo via ASM Ingress Gateway
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 5179
server: istio-envoy
date: Wed, 14 Jul 2021 20:49:19 GMT
x-envoy-upstream-service-time: 68
```



### Clean up the Citadel ASM controlplane

Delete the old istio-ingressgatewayDeployment. 
```
kubectl delete deploy asm-ingressgateway -n asm-ingress --ignore-not-found=true
```

Delete the old istiod revision.
```
kubectl delete Service,Deployment,HorizontalPodAutoscaler,PodDisruptionBudget istiod-asm-1102-2-citadel -n istio-system --ignore-not-found=true
```

Remove the old IstioOperator configuration.
```
kubectl delete IstioOperator installed-state-istio-controlplane-asm-1102-2-citadel -n istio-system
```

## Clean up the CA certificates
Preserve secrets just in case you need them:
```
kubectl get secret/cacerts -n istio-system -o yaml > save_file_1
kubectl get secret/istio-ca-secret -n istio-system -o yaml > save_file_2
```

Remove the CA secrets in the cluster associated with the old CA:
```
kubectl delete secret cacerts istio-ca-secret -n istio-system --ignore-not-found
```

Restart the newly installed control plane. This makes sure the old root of trust is cleaned up from all workloads running in the mesh.
```
kubectl rollout restart deployment -n istio-system
kubectl label namespace asm-ingress istio.io/rev=asm-1102-2-meshca --overwrite
kubectl rollout restart deployment -n asm-ingress
```

### Confirm applications are up
We migrated from Istio to ASM and from Citadel to Mesh CA. 
Check that your applications are working as expected for a last time. 

Your applications are still working.

*Using a browser*
Open the Online Boutique app in your browser
```
http://[public_ip]
```

Open your Bookinfo application in your browser
```
http://[public_ip]/productpage
```
*Or using curl*
```
./check-my-apps.sh 
```
Example output
```
Online Boutique via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Bookinfo via Istio Ingress Gateway
curl: (7) Failed to connect to 34.122.113.144 port 80: Connection refused

Online Boutique via ASM Ingress Gateway
HTTP/1.1 200 OK
set-cookie: shop_session-id=110d0be9-436e-4b26-9879-50d91780aa2a; Max-Age=172800
date: Wed, 14 Jul 2021 20:49:18 GMT
content-type: text/html; charset=utf-8
x-envoy-upstream-service-time: 53
server: istio-envoy
transfer-encoding: chunked

Bookinfo via ASM Ingress Gateway
HTTP/1.1 200 OK
content-type: text/html; charset=utf-8
content-length: 5179
server: istio-envoy
date: Wed, 14 Jul 2021 20:49:19 GMT
x-envoy-upstream-service-time: 68
```



Validate that the sidecar proxies for the workloads on the cluster are configured with only the new root certificate for Mesh CA:
```
./migrate_ca check-root-cert
```
Example output
```
Checking the root certificates loaded on each pod...

Namespace: asm-ingress
 - asm-ingressgateway-meshca-7bdf4b497b-cshzs.asm-ingress trusts [MESHCA]
 - asm-ingressgateway-meshca-7bdf4b497b-j7qbb.asm-ingress trusts [MESHCA]
 - asm-ingressgateway-meshca-7bdf4b497b-phg8s.asm-ingress trusts [MESHCA]

Namespace: asm-system

Namespace: bookinfo
 - details-v1-5c8c468f5d-tw5zr.bookinfo trusts [MESHCA]
 - productpage-v1-85d8495dc4-lwrhr.bookinfo trusts [MESHCA]
 - ratings-v1-79dc79d95d-8vf62.bookinfo trusts [MESHCA]
 - reviews-v1-57cf5fd96b-zhjvm.bookinfo trusts [MESHCA]
 - reviews-v2-77cfdf74b-pcv8v.bookinfo trusts [MESHCA]
 - reviews-v3-77b9874858-6vkjd.bookinfo trusts [MESHCA]

Namespace: default

Namespace: istio-system

Namespace: online-boutique
 - adservice-57949ff959-qwklm.online-boutique trusts [MESHCA]
 - cartservice-85674b67bb-wh9ds.online-boutique trusts [MESHCA]
 - checkoutservice-6cf77999c7-vxvkt.online-boutique trusts [MESHCA]
 - currencyservice-79c99596f7-57vgx.online-boutique trusts [MESHCA]
 - emailservice-8b44f99d5-5rs79.online-boutique trusts [MESHCA]
 - frontend-7d59b68b9d-g6g6m.online-boutique trusts [MESHCA]
 - loadgenerator-55b4cbd49d-pg5hj.online-boutique trusts [MESHCA]
 - paymentservice-7b6bb96945-q9jcq.online-boutique trusts [MESHCA]
 - productcatalogservice-7694b54797-tnwlw.online-boutique trusts [MESHCA]
 - recommendationservice-7f5d9497f7-x44ch.online-boutique trusts [MESHCA]
 - redis-cart-84c59cb95f-db8jw.online-boutique trusts [MESHCA]
 - shippingservice-b74586c65-p44hl.online-boutique trusts [MESHCA]
 ```



### Congratulations! Your migration from Istio to ASM and from Citadel to Mesh CA is complete!



## Cleanup 
Delete the cluster to stop incurring charges.
```
gcloud container clusters delete $CLUSTER_NAME --project $PROJECT_ID --zone $ZONE
```
