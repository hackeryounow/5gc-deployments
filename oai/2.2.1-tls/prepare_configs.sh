#!/bin/bash
# Derive the AMF and SMF config files from basic_nrf_config.yaml.
#
# Source-verified (v2.2.1): only AMF and SMF implement a TLS SBI server
# (ssl::context + listen_and_serve(ec, tls, ...)); NRF/UDM/UDR/AUSF serve plain
# h2c and UPF has no SBI HTTP server at all. config::enable_tls() reads the
# TOP-LEVEL `tls:` block, and sbi_interface::get_url() uses the CALLER's own
# enable_tls to pick https:// vs http://. Therefore:
#   - base file (NRF/UDM/UDR/AUSF/UPF): top-level enable_tls=false so these
#     plain NFs talk http:// to each other (UDM->UDR, AUSF->UDM auth chain).
#   - AMF/SMF: flip the TOP-LEVEL enable_tls back to true (they serve HTTPS and
#     build https:// toward their statically configured peers), and point the
#     NRF/AUSF/UDM hosts at the TLS-terminating proxy aliases
#     (oai-nrf-tls / oai-ausf-tls / oai-udm-tls) served by oai-sbi-proxy.
#
# Usage: ./prepare_configs.sh   (run before "docker compose up")

set -e
cd "$(dirname "$0")"

BASE=basic_nrf_config.yaml

for nf in amf smf; do
    SED_ARGS=(
        -e 's/^  enable_tls: false$/  enable_tls: true/'
        -e 's/host: oai-nrf$/host: oai-nrf-tls/'
        -e 's/host: oai-ausf$/host: oai-ausf-tls/'
        -e 's/host: oai-udm$/host: oai-udm-tls/'
    )
    # AMF ONLY: force static SMF selection (register_nf: no).
    # Source amf_sbi.cpp:482-509 gates SMF selection on enable_nf_registration,
    # which amf_config.cpp:999 sets from register_nrf(). With NRF discovery the
    # AMF builds a SCHEME-LESS smf_uri_root "<ip>:<port>" (amf_sbi.cpp:1716) and
    # the common http_client (http_client.cpp:251) never prepends a scheme, so
    # curl defaults to plaintext http and the TLS-only SMF resets the connection
    # ("Recv failure: Connection reset by peer"). register_nf: no makes the AMF
    # use smf_selection_from_configuration() -> the static https://oai-smf:8080
    # built by get_url(enable_tls=true), which the SMF serves natively.
    # The static smf/ausf/udm/nrf uri_roots are built unconditionally
    # (amf_config.cpp:1069-1095), so they remain valid with register_nf: no.
    if [ "$nf" = "amf" ]; then
        SED_ARGS+=( -e 's/^  general: yes$/  general: no/' )
    fi
    sed "${SED_ARGS[@]}" "$BASE" > "basic_nrf_config_${nf}.yaml"
    echo "[+] Generated basic_nrf_config_${nf}.yaml"
done
