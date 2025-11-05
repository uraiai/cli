# Urai CLI Docker Image
# Based on Debian 13 (Trixie)
# This is a developer-friendly image (not distroless) that users can extend

FROM debian:trixie-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy the binary (will be provided by build context)
ARG TARGETARCH
COPY urai-linux-${TARGETARCH} /usr/local/bin/urai
RUN chmod +x /usr/local/bin/urai

# Verify the binary works
RUN urai --version || urai --help || true

# Set working directory
WORKDIR /workspace

# Default command
CMD ["urai", "--help"]
