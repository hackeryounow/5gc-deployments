#!/bin/bash
# Generate a self-signed CA and per-NF certificates for the OAI CN5G TLS deployment.
#
# OAI NFs (AMF and SMF are the only ones implementing TLS in v2.2.x) expect the
# following file naming convention inside the directories configured via the
# "tls:" config section:
#   cert_certificate_path -> <dir>/oai_<nf>.crt
#   cert_key_path         -> <dir>/oai_<nf>.key
#   cert_pem_path         -> CA certificate file
#
# Additionally, combined oai_<nf>.pem (cert + key) files are generated for the
# HAProxy TLS-terminating proxy (oai-sbi-proxy). The "oai-<nf>-tls" SAN entries
# match the proxy aliases used by AMF/SMF toward NRF/AUSF/UDM.
#
# Usage: ./generate_certs.sh
# Output: ./certs/ca.{crt,key} and ./certs/oai_<nf>.{crt,key,pem} for every NF

set -e

CERT_DIR="$(cd "$(dirname "$0")" && pwd)/certs"
DAYS=3650
SUBJ_BASE="/C=FR/ST=IDF/L=Paris/O=OAI/OU=CN5G"
# Container hostnames of the NFs on the compose network (used as CN/SAN)
NF_LIST="nrf amf smf upf udm udr ausf"
# Static container IPs (see docker-compose file). AMF and SMF get their IP as
# an extra SAN because peers build URIs from the IP found in NRF discovery
# profiles, and libcurl then verifies the certificate against that IP.
AMF_STATIC_IP=172.20.0.11
SMF_STATIC_IP=172.20.0.10

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "[*] Generating CA ..."
openssl genrsa -out ca.key 2048 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -sha256 -days "$DAYS" \
    -subj "${SUBJ_BASE}/CN=OAI-CN5G-ROOT-CA" -out ca.crt

for nf in $NF_LIST; do
    host="oai-${nf}"
    echo "[*] Generating certificate for ${host} (oai_${nf}.crt / oai_${nf}.key) ..."
    openssl genrsa -out "oai_${nf}.key" 2048 2>/dev/null
    openssl req -new -key "oai_${nf}.key" \
        -subj "${SUBJ_BASE}/CN=${host}" -out "oai_${nf}.csr"
    # SAN covers the container hostname, the TLS proxy alias, localhost and loopback
    ip_san="IP:127.0.0.1"
    case "$nf" in
        amf) ip_san="${ip_san},IP:${AMF_STATIC_IP}" ;;
        smf) ip_san="${ip_san},IP:${SMF_STATIC_IP}" ;;
    esac
    cat > "oai_${nf}.ext" <<EOF
subjectAltName = DNS:${host},DNS:${host}-tls,DNS:localhost,${ip_san}
extendedKeyUsage = serverAuth,clientAuth
EOF
    openssl x509 -req -in "oai_${nf}.csr" -CA ca.crt -CAkey ca.key \
        -CAcreateserial -days "$DAYS" -sha256 \
        -extfile "oai_${nf}.ext" -out "oai_${nf}.crt" 2>/dev/null
    rm -f "oai_${nf}.csr" "oai_${nf}.ext"
    # Combined cert+key bundle consumed by HAProxy (runs unprivileged)
    cat "oai_${nf}.crt" "oai_${nf}.key" > "oai_${nf}.pem"
done

rm -f ca.srl
chmod 600 ./*.key
chmod 644 ./*.pem
chmod 644 ./ca.crt
echo "[+] Done. Certificates written to: $CERT_DIR"
ls -l "$CERT_DIR"
