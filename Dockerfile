ARG PYTORCH_BASE=vastai/pytorch:2.5.1-cuda-12.1.1-py311

FROM ${PYTORCH_BASE}

# Maintainer details
LABEL org.opencontainers.image.source="https://github.com/vastai/"
LABEL org.opencontainers.image.description="Llama.cpp Vast.ai image"
LABEL maintainer="Ruslan Veselov <rv@rakkade.su>"

# Copy Supervisor configuration and startup scripts
COPY ./ROOT /

RUN \
    set -euo pipefail && \
    . /venv/main/bin/activate && \
    # We have PyTorch pre-installed so we will check at the end of the install that it has not been clobbered
    torch_version_pre="$(python -c 'import torch; print (torch.__version__)')" && \
    # Install xformers while pinning to the inherited torch version.  Fail build on dependency resolution if matching version is unavailable
    pip install xformers torch==$PYTORCH_VERSION --index-url "${PYTORCH_INDEX_URL}" && \
    pip install onnxruntime-gpu && \
    # Get Llama.cpp
    mkdir -p /opt/llama.cpp/bin && \
    cd /tmp && \
    apt-get install libcurl4-openssl-dev && \
    git clone https://github.com/ggerganov/llama.cpp && \
    cmake llama.cpp -B /tmp/llama.cpp/build \
        -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON -DLLAMA_CURL=ON && \
    cmake --build /tmp/llama.cpp/build --config Release -j --clean-first --target llama-quantize llama-cli llama-server llama-gguf-split && \
    cp /tmp/llama.cpp/build/bin/llama-* /opt/llama.cpp/bin && \
    rm -rf /tmp/llama.cpp && \
    mkdir -p /opt/workspace-internal/llama.cpp/models/ && \
    # Test 1: Verify PyTorch version is unaltered
    torch_version_post="$(python -c 'import torch; print (torch.__version__)')" && \
    [[ $torch_version_pre = $torch_version_post ]] || { echo "PyTorch version mismatch (wanted ${torch_version_pre} but got ${torch_version_post})"; exit 1; }

    ENV PATH="${PATH}:/opt/llama.cpp/bin"
