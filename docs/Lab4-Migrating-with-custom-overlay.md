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

### Inject the istio sidecar proxy into the applications
Perform a rollout restart to inject the enoy sidecar proxy
```
kubectl rollout restart deployment -n bookinfo
kubectl apply -f ./microservices-demo/release -n online-boutique
kubectl apply -f istio-${ISTIO_VERSION}/samples/bookinfo/networking/bookinfo-gateway.yaml -n bookinfo
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

If you try to access the applications via the asm-ingressgateway IP, you will find that they are not avilable, as the applications still run on the Istio service mesh. 


### Move the Bookinfo app over to ASM 
We migrate the bookinfo namespace to the ASM service mesh 
```
kubectl label namespace bookinfo istio.io/rev=asm-1102-2-citadel istio-injection- --overwrite
kubectl rollout restart deployment -n bookinfo
```
Create a gateway object for the Bookinfo app, that points to the new ASM ingress gateway.
```
kubectl apply -f asm/bookinfo/bookinfo-gw-asm.yaml
```

Then we edit the VirtualService for the bookinfo app to point to the new gateway that we created
```
kubectl edit virtualservice bookinfo -n bookinfo 
```
Go into edit mode
```
i
```
replace
```
spec:
  gateways:
  - bookinfo-gateway
```

with 
```
spec:
  gateways:
  - bookinfo-gateway-asm
```
Save and exit
Hit ESC and then 
``` 
:wq
```
Output: 
```
virtualservice.networking.istio.io/bookinfo edited
```

Your application is no longer accessible via the old Istio Ingress Gateway IP...
```
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
```
Response
```
HTTP/1.1 404 Not Found
```

...but with the ASM Ingress Gateway IP
```
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
```
Response
```
HTTP/1.1 200 OK
```

Note: 
If you want to switch back to using the Istio Ingress Gateway IP, simply edit the application's virtual service and revert the Spec.Gateways from "bookinfo-gateway-asm" back to "bookinfo-gateway".

### Migrate the remaining applications to ASM
In our case this means migrating the Online Botique app. 
First we migrate the app to the ASM Service Mesh. 
```
kubectl label namespace online-boutique istio.io/rev=asm-1102-2-citadel istio-injection- --overwrite
kubectl rollout restart deployment -n online-boutique
```
The applciation is still available via the Istio Ingress Gateway. 
```
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
```
Response
```
HTTP/1.1 200 OK
```

Create the new gateway object for the Online Boutique app. 
```
kubectl apply -f asm/online-boutique/online-boutique-gw-asm.yaml -n online-boutique
```

Edit the VirtualService for the Online Boutique app to point to the new gateway that we created
```
kubectl edit virtualservice frontend-ingress -n online-boutique 
```
Go into edit mode
```
i
```
replace
```
spec:
  gateways:
  - frontend-gateway
```

with 
```
spec:
  gateways:
  - frontend-gateway-asm
```
Save and exit
Hit ESC and then 
``` 
:wq
```
Output: 
```
virtualservice.networking.istio.io/frontend-ingress edited
```

Your application is no longer accessible via the old Istio Ingress Gateway IP...
```
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
```
...but with the ASM Ingress Gateway IP
```
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
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
 
### Finalize the migration
At this time, all of your workloads are migrated from Istio to ASM and we moved to a new Ingress Gateway located in its own namespace as recommended by Istio and Google. 
At this point, you might have to change incoming traffic over to the new ingress gateway. For example updating DNS entry or pointing your Application Firewall to the new Ingress Gateway IP. 
This should close out the downtime. 
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
Remove the old version of the IstioOperator configuration

```
kubectl delete IstioOperator istio-controlplane -n istio-system
```

Delete the IstioOperator and IstioOperator namespace
```
istioctl operator remove
kubectl delete ns istio-operator
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

Confirm that both application are still working (HTTP/1.1 200 OK). 
Bookinfo using the mesh-ca ASM controlplane
```
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
```

Online boutique is still running on the Citadel ASM controlplane
```
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
```

### Migrate the rst of your applications to the new ASM Mesh CA controlplane
In our case this will only involve the Online-Boutqiue app. 
```
kubectl label namespace online-boutqiue istio.io/rev=asm-1102-2-meshca --overwrite
kubectl rollout restart deployment -n online-boutique
```

### Clean up the Citadel ASM controlplane
Configure the validating webhook to use the new control plane.
```
kubectl apply -f outdir-meshca/asm/istio/istiod-service.yaml 
```
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
Online Boutique
```
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
```
Bookinfo
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
```


### Congratulations! Your migration from Istio to ASM and from Citadel to Mesh CA is complete!



## Cleanup 
Delete the cluster to stop incurring charges.
```
gcloud container clusters delete $CLUSTER_NAME --project $PROJECT_ID --zone $ZONE
```
