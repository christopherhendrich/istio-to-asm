#!/bin/bash
echo ""
echo "$(tput setaf 1)Online Boutique via Istio Ingress Gateway$(tput setaf 7)"
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
echo ""
echo "$(tput setaf 1)Bookinfo via Istio Ingress Gateway$(tput setaf 7)"
curl -I http://$(kubectl get services -n istio-system istio-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
echo ""
echo "$(tput setaf 1)Online Boutique via ASM Ingress Gateway$(tput setaf 7)"
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/
echo ""
echo "$(tput setaf 1)Bookinfo via ASM Ingress Gateway$(tput setaf 7)"
curl -I http://$(kubectl get services -n asm-ingress asm-ingressgateway --output jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
