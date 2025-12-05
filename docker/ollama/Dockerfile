# CPU-only build of the Ollama CLI on Ubuntu 24.04 (no ROCm/CUDA).
# Produces /usr/bin/ollama with ggml CPU libs bundled.

FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential cmake ninja-build pkg-config curl git ca-certificates \
      libclang-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Go matching go.mod (1.24.1)
ENV GO_VERSION=1.24.1
RUN curl -fsSL --retry 5 --retry-delay 2 --insecure https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -o /tmp/go.tgz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tgz && \
    rm /tmp/go.tgz
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /src
COPY . .

# Build ggml CPU libs
RUN cmake -S . -B build -G Ninja --preset CPU && \
    cmake --build build --parallel $(nproc) --preset CPU && \
    cmake --install build --component CPU --strip

# Build ollama binary
ENV CGO_ENABLED=1 \
    GOPROXY=direct \
    GONOSUMDB=* \
    GOINSECURE=* \
    GIT_SSL_NO_VERIFY=1
RUN go env -w GOPROXY=$GOPROXY GONOSUMDB=$GONOSUMDB GOINSECURE=$GOINSECURE && \
    go build -trimpath -buildmode=pie -o /usr/bin/ollama .

# Final minimal image
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates libstdc++6 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/bin/ollama /usr/bin/ollama
COPY --from=build /src/dist/lib/ollama /usr/lib/ollama

ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV OLLAMA_HOST=0.0.0.0:11434
EXPOSE 11434

ENTRYPOINT ["/usr/bin/ollama"]
CMD ["serve"]
