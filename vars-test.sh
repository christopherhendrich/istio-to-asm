#! /usr/bin/env bash
PROJECT_ID=sada-chendrich-istio-to-asm
REGION=us-central1
ZONE=us-central1-c
MIN_ISTIO_NODES=4  # 4 nodes are recommended for ASM 
ISTIO_VERSION=1.9.6
ASM_VERSION=1.10
CLUSTER_NAME=cluster-2

gcloud config set project ${PROJECT_ID}
gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}