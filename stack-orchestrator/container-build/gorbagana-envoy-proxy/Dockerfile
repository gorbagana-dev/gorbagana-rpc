FROM envoyproxy/envoy:v1.31-latest

RUN mkdir -p /etc/envoy/tls && \
    openssl req -x509 -newkey rsa:4096 -nodes \
    -keyout /etc/envoy/tls/origin.key \
    -out /etc/envoy/tls/origin.cert.pem \
    -days 365 \
    -subj "/CN=localhost/O=Gorbagana" && \
    chown envoy:envoy /etc/envoy/tls/origin.key /etc/envoy/tls/origin.cert.pem
