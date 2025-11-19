#!/usr/bin/env bash
set -ex

echo "Building xformers ${XFORMERS_VERSION}"

git clone --branch=v${XFORMERS_VERSION} --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers ||
git clone --depth=1 --recursive https://github.com/facebookresearch/xformers /opt/xformers

cd /opt/xformers

if [[ -z "${IS_SBSA}" || "${IS_SBSA}" == "0" || "${IS_SBSA,,}" == "false" ]]; then
    export MAX_JOBS=6
    # Jetson Orin: compute capability 8.7 = SM_87
    export CUDA_ARCH=87
else
    export MAX_JOBS=16
    # Jetson Thor (SBSA): compute capability 11.0 = SM_90
    export CUDA_ARCH=90
fi
ARCH=$(uname -i)
if [ "${ARCH}" = "aarch64" ]; then
      export NVCC_THREADS=1
      export CUDA_NVCC_FLAGS="-Xcudafe --threads=1"
      export MAKEFLAGS='-j2'
      export CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS
      export NINJAFLAGS='-j2'
fi

echo "Building xformers with MAX_JOBS=$MAX_JOBS, CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS, CUDA_ARCH=$CUDA_ARCH"

MAX_JOBS=$MAX_JOBS \
CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS \
CUDA_ARCH=$CUDA_ARCH \
XFORMERS_DISABLE_FLASH_ATTN=1 \
XFORMERS_MORE_DETAILS=1 \
python3 setup.py --verbose bdist_wheel --dist-dir /opt/xformers/wheels

uv pip install /opt/xformers/wheels/*.whl

twine upload --verbose /opt/xformers/wheels/xformers*.whl || echo "failed to upload wheel to ${TWINE_REPOSITORY_URL}"
