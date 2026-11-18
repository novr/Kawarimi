FROM swift:6.2-noble

# Matches CI (`.github/workflows/ci.yaml` swift:6.2-noble) for Swift 6.2+ and Vapor/C++ deps.
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

USER ubuntu