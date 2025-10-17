# Derive from base image with all binaries
FROM gorbagana/gorchain-base:local

# Copy validator-specific files
COPY primordial.yml /agave/primordial.yml
COPY programs/precompiled /agave/programs/precompiled

# Expose validator-specific ports
# RPC JSON
EXPOSE 8899/tcp
# RPC pubsub
EXPOSE 8900/tcp
# Gossip
EXPOSE 8001/udp
EXPOSE 8001/tcp
# TPU
EXPOSE 8003/udp
# Faucet
EXPOSE 9900/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8899/health || exit 1

CMD ["agave-validator"]
