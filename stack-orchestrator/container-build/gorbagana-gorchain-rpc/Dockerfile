# Derive from base image with all binaries
FROM gorbagana/gorchain-base:local

# Expose RPC-specific ports
# RPC JSON
EXPOSE 8899/tcp
# RPC pubsub
EXPOSE 8900/tcp
# Gossip
EXPOSE 8001/udp
EXPOSE 8001/tcp
# Dynamic port range for RPC
EXPOSE 9000-9025/udp

# Health check (RPC nodes also use port 8899 internally)
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8899/health || exit 1

CMD ["agave-validator"]
