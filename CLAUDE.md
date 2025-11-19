## 要求
1. git 相关例如 commit 要使用中文提交
2. 所有获取内容的命令 例如 ls cat 等等命令都可以执行，编辑也可以不过改完让我知道即可.

## 机器设备和驱动详情
- ⚠ Jetson 的系统组件（驱动 / CUDA / cuDNN / TensorRT）全部由 JetPack 固定绑定版本，绝不能手动覆盖。
  - 任何额外 apt/pip 安装都会破坏依赖，导致 GPU、CUDA 或系统崩溃。
- ⚠ ROS2 不能 apt 装（ros-jazzy-*），Thor 必须使用 NVIDIA Isaac ROS 官方 Docker（JetPack 对齐版）。

❌ Thor 上禁止安装的包（绝对禁区）
- NVIDIA 驱动 apt 包 (nvidia-driver-*, nvidia-dkms-*, nvidia-kernel-*)
- CUDA / cuDNN / TensorRT apt 包(cuda, cuda-toolkit-*, cudnn*, tensorrt*)
- ROS 2 apt 包(ros-jazzy-*, ros-humble-*, ros-iron-*)
- pip GPU 框架（因为会拉 x86 或无 CUDA13 版本）torch, torchvision, tensorflow


~~~sh
# lsb_release -a
No LSB modules are available.
Distributor ID:    Ubuntu
Description:    Ubuntu 24.04.3 LTS
Release:    24.04
Codename:    noble

# cat /etc/nv_tegra_release
# R38 (release), REVISION: 2.0, GCID: 41844464, BOARD: generic, EABI: aarch64, DATE: Fri Aug 22 00:55:42
UTC 2025
# KERNEL_VARIANT: oot
TARGET_USERSPACE_LIB_DIR=nvidia
TARGET_USERSPACE_LIB_DIR_PATH=usr/lib/aarch64-linux-gnu/nvidia
INSTALL_TYPE=

L4T_VERSION=38.4.0  JETPACK_VERSION=7.1  CUDA_VERSION=13.0

(.env) ay@ubuntu24:~/Desktop/app/oo1/models$ nvidia-smi
Fri Nov 14 14:06:18 2025
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.00                 Driver Version: 580.00         CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  NVIDIA Thor                    Off |   00000000:01:00.0 Off |                  N/A |
| N/A   N/A  N/A             N/A  /  N/A  | Not Supported          |      0%      Default |
|                                         |                        |             Disabled |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|    0   N/A  N/A            3507      G   /usr/lib/xorg/Xorg                        0MiB |
|    0   N/A  N/A            3735      G   /usr/bin/gnome-shell                      0MiB |
|    0   N/A  N/A            3938      G   /usr/bin/gnome-software                   0MiB |
|    0   N/A  N/A            4217      G   ...exec/xdg-desktop-portal-gnome          0MiB |
|    0   N/A  N/A            4257      G   /usr/bin/nautilus                         0MiB |
|    0   N/A  N/A           17364      G   /usr/bin/gnome-control-center             0MiB |
+-----------------------------------------------------------------------------------------+
~~~


## 容器 Build 说明
因为 当前设备版本过新，所以大概率要 build,但是由于官方不断在更新，所以我 fork 了一份，在git@github.com:ayou129/jetson-containers.git

build 要求:
1. 每次 build 都要 根据 ay 分支 创建一个 ay-[包名字例如:sglang] 的分支，然后在此分支进行 packages/[包名字]/xxx 等构建文件的修改，来适配当前的设备版本.
  - ay 分支我一般不会从 master 合并，必要的时候 从 master 合并过来，合并之前我会评估好合并之后的兼容性.
2. 每次 build 之前都要检查好 每一个 构建文件的实际代码，尽量贴合当前设备的配置信息.
3. 我使用的命令大致是: `export MAX_JOBS=12 && jetson-containers build sglang:builder`


### 注意事项:
1. 如果某个镜像文件build 报错并且修复了 package 的 build 的逻辑，那么优先删除之前错误的镜像文件，然后重新 build
2. Build 和 test 日志位置：/home/ay/Desktop/app/jetson-containers/logs/{timestamp}/build/ 和 test/ 目录。格式为 {stage}o{total}_sglang_builder-...-{package}.txt
3. 遇到 build/test 失败，优先检查日志中的关键词（如 CUDA_ARCH、IS_SBSA、MAX_JOBS 等），确认编译参数是否正确传递
4. Dockerfile 中 ARG 声明的变量必须同时在 ENV 中设置或传递，config.py 中必须通过 build_args 显式传递，否则 build.sh 脚本中无法访问


### 在 Build sglang 的时候 进行的修改
(base) ay@ubuntu:~/Desktop/app/jetson-containers$ git diff packages/attention/xformers/build.sh
diff --git a/packages/attention/xformers/build.sh b/packages/attention/xformers/build.sh
index 00559377..ab748422 100755
--- a/packages/attention/xformers/build.sh
+++ b/packages/attention/xformers/build.sh
@@ -10,8 +10,12 @@ cd /opt/xformers

 if [[ -z "${IS_SBSA}" || "${IS_SBSA}" == "0" || "${IS_SBSA,,}" == "false" ]]; then
     export MAX_JOBS=6
+    # Jetson Orin: compute capability 8.7 = SM_87
+    export CUDA_ARCH=87
 else
     export MAX_JOBS=16
+    # Jetson Thor (SBSA): compute capability 11.0 = SM_90
+    export CUDA_ARCH=90
 fi
 ARCH=$(uname -i)
 if [ "${ARCH}" = "aarch64" ]; then
@@ -22,10 +26,11 @@ if [ "${ARCH}" = "aarch64" ]; then
       export NINJAFLAGS='-j2'
 fi

-echo "Building with MAX_JOBS=$MAX_JOBS and CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS"
+echo "Building xformers with MAX_JOBS=$MAX_JOBS, CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS, CUDA_ARCH=$CUDA_ARCH"

 MAX_JOBS=$MAX_JOBS \
 CMAKE_BUILD_PARALLEL_LEVEL=$MAX_JOBS \
+CUDA_ARCH=$CUDA_ARCH \
 XFORMERS_DISABLE_FLASH_ATTN=1 \
 XFORMERS_MORE_DETAILS=1 \
 python3 setup.py --verbose bdist_wheel --dist-dir /opt/xformers/wheels
