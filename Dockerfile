# Set the base image
ARG BASE_IMAGE=seecsea/jupyterlab-pytorch:2.7.1-ubuntu22.04-dtk26.04-py3.11-devel
FROM ${BASE_IMAGE}

# Install custom node from custom_nodes.txt
ARG SKIP_CUSTOM_NODES=""

# Set the shell and enable pipefail for better error handling
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set basic environment variables
ENV SHELL=/bin/bash 
ENV PYTHONUNBUFFERED=True 
ENV DEBIAN_FRONTEND=noninteractive

# Set the default workspace directory
ENV RP_WORKSPACE=/workspace

# Override the default huggingface cache directory.
ENV HF_HOME="${RP_WORKSPACE}/.cache/huggingface/"

# Faster transfer of models from the hub to the container
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV HF_XET_HIGH_PERFORMANCE=1

# Shared python package cache
ENV VIRTUALENV_OVERRIDE_APP_DATA="${RP_WORKSPACE}/.cache/virtualenv/"
ENV PIP_CACHE_DIR="${RP_WORKSPACE}/.cache/pip/"
ENV UV_CACHE_DIR="${RP_WORKSPACE}/.cache/uv/"

# modern pip workarounds
ENV PIP_BREAK_SYSTEM_PACKAGES=1
ENV PIP_ROOT_USER_ACTION=ignore

# Set TZ and Locale
ENV TZ=Etc/UTC

ENV LD_LIBRARY_PATH=/opt/hyhal/lib:/opt/hyhal/hsa/lib:/opt/dtk-26.04/.hyhal/hsa/lib:/opt/dtk-26.04/hsa/lib:/opt/dtk-26.04/lib:$LD_LIBRARY_PATH
RUN ldconfig

# Set working directory
WORKDIR /app

COPY logo/logo.txt pip_constraints.txt requirements_dcu.txt /etc/
RUN pip install --no-cache-dir -r /etc/requirements_dcu.txt

# 1. 定义动态参数（默认值设为国内源，方便本地构建）
ARG APT_SOURCE="default"
ARG PIP_INDEX="https://pypi.org/simple/"

# 2. 动态修改 Ubuntu 系统 APT 源
# 如果传入的是 "default"，则恢复官方默认源；否则替换为指定的镜像源
RUN if [ "$APT_SOURCE" = "default" ]; then \
        sed -i 's/mirrors\.aliyun\.com/archive\.ubuntu\.com/' /etc/apt/sources.list ; \
    else \
        sed -i 's/archive\.ubuntu\.com/mirrors\.aliyun\.com/' /etc/apt/sources.list ; \
    fi

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Install the UV tool from astral-sh
ADD https://astral.sh/uv/install.sh /uv-installer.sh
RUN sh /uv-installer.sh && rm /uv-installer.sh
ENV PATH="/root/.local/bin/:$PATH"

ENV PIP_INDEX_URL=${PIP_INDEX}
# Install essential Python packages and dependencies
RUN pip install --no-cache-dir -U \
    wheel pip \
    huggingface_hub modelscope

# Banner
RUN echo 'cat /etc/logo.txt' >> /root/.bashrc \
    && echo 'echo -e "\nFor detailed documentation and guides, please visit:\n\033[1;34mhttps://cnb.cool/bigbomb\033[0m and \033[1;34mhttps://cnb.cool/bigbomb\033[0m\n\n"' >> /root/.bashrc

# Install ComfyUI and ComfyUI Manager
RUN git clone https://github.com/comfyanonymous/ComfyUI.git && \
    cd ComfyUI && \
    pip install --no-cache-dir -r requirements.txt && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    cd custom_nodes/ComfyUI-Manager && \
    pip install --no-cache-dir -r requirements.txt

COPY custom_nodes.txt /app/custom_nodes.txt

RUN if [ -z "$SKIP_CUSTOM_NODES" ]; then \
        cd /app/ComfyUI/custom_nodes && \
        xargs -n 1 git clone --recursive < /app/custom_nodes.txt && \
        find /app/ComfyUI/custom_nodes -name "requirements.txt" -exec sh -c 'echo "Installing requirements from: $1" && pip install --no-cache-dir -r "$1"' _ {} \; && \
        git clone --recursive https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git && \
		git clone https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git && \
		git clone https://github.com/seecsea/ComfyUI-llama-cpp.git \
    else \
        echo "Skipping custom nodes installation because SKIP_CUSTOM_NODES is set"; \
    fi
