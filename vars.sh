#! /usr/bin/env bash
PROJECT_ID=YOUR_PROJECT_ID
REGION=REGION
ZONE=ZONE
MIN_ISTIO_NODES=4  # 4 nodes are recommended for ASM 
ISTIO_VERSION=[example 1.9.5]
ASM_VERSION=[example 1.10] 
REV_LABEL="1-10"  # Use the ASM-Version label as guide
CLUSTER_NAME=cluster-1 # default name

gcloud config set project ${PROJECT_ID}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}