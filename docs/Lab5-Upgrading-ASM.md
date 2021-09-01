## Lab 5: Upgrading ASM

In this lab we will walk through the upgrade process for ASM.
This lab assumes you have gone through Lab 4 and have ASM MeshCA version 1.10.2-asm.3 running.
Lab 4 used the "canary" method to ensure we achieve zero downtime during the migration, we will use the upgrade to prep for in-place upgrades for future upgrade methods, meaning we will use the same revision label going forward. This will cause ASM to install the new version over the existing one and we will update the IGWs and applciations by simply performing a rollout update, without having to modify any labels going forward. 

### Activate the required variables
```
source upgrade/upgrade-vars.sh
```

Download the new version of the isntall_asm script
```
curl https://storage.googleapis.com/csm-artifacts/asm/${ASM_UPGRADE_VERSION} > upgrade/install_asm
chmod +x upgrade/install_asm
```

### Install the new version of the ASM Control Plane
Note that we using the revision label "asm" for the new version, wihtout any speicif cversion mentioned. This is to ensure we are able to do simple in-place upgrades moving forward.

upgrade/install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $ZONE \
  --mode install \
  --ca mesh_ca \
  --enable_all \
  --revision_name asm  \
  --output_dir outdir-asm/ \
  --custom_overlay $PWD/asm/controlplane.yaml

### Upgrade the IGWs to the new ASM version
Update the revision label to "asm". We will do that by deploying an updated manifest
```
kubectl apply -f upgrade/asm-ingress-deployment.yaml
```




### Migrate bookinfo to the new ASM version

kubectl label namespace bookinfo istio.io/rev=asm istio-injection- --overwrite
kubectl rollout restart deployment -n bookinfo

### Migrate Online-Boutique to the new ASM version

kubectl label namespace online-boutique istio.io/rev=asm istio-injection- --overwrite
kubectl rollout restart deployment -n online-boutique




### Summary 
We now have upgraded ASM to ASM 1.10.4-asm.6 and prepared ASM going forward to use in-place upgrades for the control plane and IGWs. 
To go through an in-place upgrade process, follow the appendix!



## Appendix

### In-place upgrades
We will now go through some in-place upgrades. Since we are already on the newest version at the time of writing this lab, we will actually downgrade to 1.10.2-asm.3 and then upgrade back to 1.10.4-asm.6 .

### Replace the ASM control plane with version 1.10.2-asm.3 control plane
./install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $ZONE \
  --mode install \
  --enable_all \
  --revision_name asm  \
  --output_dir outdir-asm/ \
  --custom_overlay $PWD/asm/controlplane.yaml


  This will do an in-place upgrade of the control plane. 

  ### Restart the IGW deployment
  Restarting the IGW deployment will inject the new (in our case old) version of the istio-proxy image used for the IGW. 

  ```
  kubectl rollout restart deploy -n asm-ingress
  ```

  ### Restart the applications

  ```
  kubectl rollout restart deploy -n bookinfo
  kubectl rollout restart deploy -n online-boutique
  ```


### Upgrade complete!
Now we are back on 1.10.2-asm.3. This is how easy it is! Let's move back to 1.10.4-asm.6.

upgrade/install_asm \
  --project_id  $PROJECT_ID \
  --cluster_name $CLUSTER_NAME \
  --cluster_location $ZONE \
  --mode install \
  --ca mesh_ca \
  --enable_all \
  --revision_name asm  \
  --output_dir outdir-asm-back-to-new/ \
  --custom_overlay $PWD/asm/controlplane.yaml

###  Restart IGWs and Application deployments to inject the new version again. 
```
kubectl rollout restart deploy -n asm-ingress
kubectl rollout restart deploy -n bookinfo
kubectl rollout restart deploy -n online-boutique
```


### Upgrade completed!!
And we are back on ASM 1.10.4-asm.6! 
