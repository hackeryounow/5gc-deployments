#!/bin/bash
# Derive the AMF and SMF config files from basic_nrf_config.yaml.
#
# With "enable_tls" enabled, AMF/SMF force https:// toward every SBI peer.
# Their NRF/AUSF/UDM targets are therefore pointed at the TLS-terminating
# proxy aliases (oai-nrf-tls / oai-ausf-tls / oai-udm-tls) served by the
# oai-sbi-proxy container. All other NFs keep the plain hostnames and talk
# plain HTTP to NRF/AUSF/UDM.
#
# Usage: ./prepare_configs.sh   (run before "docker compose up")

set -e
cd "$(dirname "$0")"

BASE=basic_nrf_config.yaml

for nf in amf smf; do
    sed -e 's/host: oai-nrf$/host: oai-nrf-tls/' \
        -e 's/host: oai-ausf$/host: oai-ausf-tls/' \
        -e 's/host: oai-udm$/host: oai-udm-tls/' \
        "$BASE" > "basic_nrf_config_${nf}.yaml"
    echo "[+] Generated basic_nrf_config_${nf}.yaml"
done
