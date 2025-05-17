#!/bin/bash

# User can configure startup by removing the reference in /etc.portal.yaml - So wait for that file and check it
while [ ! -f "$(realpath -q /etc/portal.yaml 2>/dev/null)" ]; do
    echo "Waiting for /etc/portal.yaml before starting ${PROC_NAME}..." | tee -a "/var/log/portal/${PROC_NAME}.log"
    sleep 1
done

# Check for $search_term in the portal config
search_term="llama"
search_pattern=$(echo "$search_term" | sed 's/[ _-]/[ _-]?/gi')
if ! grep -qiE "^[^#].*${search_pattern}" /etc/portal.yaml; then
    echo "Skipping startup for ${PROC_NAME} (not in /etc/portal.yaml)" | tee -a "/var/log/portal/${PROC_NAME}.log"
    exit 0
fi

# Check for env variables HF_REPO_ID and HF_FILENAME; if not set, skip startup; otherwise, call llama-dlm.sh
if [ -z "$HF_REPO_ID" ] || [ -z "$HF_FILENAME" ]; then
    echo "Skipping startup for ${PROC_NAME} (HF_REPO_ID or HF_FILENAME not set)" | tee -a "/var/log/portal/${PROC_NAME}.log"
    exit 0
fi

echo "Starting llama-dlm.sh to download model files..." | tee -a "/var/log/portal/${PROC_NAME}.log"
model_path=$(/opt/instance-tools/bin/llama-dlm.sh --repo "$HF_REPO_ID" --filename "$HF_FILENAME")

# Wait for provisioning to complete
while [ -f "/.provisioning" ]; do
    echo "$PROC_NAME startup paused until instance provisioning has completed (/.provisioning present)"
    sleep 10
done

llama-server \
  --model "$model_path" \
  --ctx-size "${CTX_SIZE:-16384}" \
  --parallel 1 \
  --pooling none \
  --gpu-layers 9999 \
  --port 21434 | tee -a "/var/log/portal/${PROC_NAME}.log"
