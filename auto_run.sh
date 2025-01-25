#!/bin/bash
echo -e

echo "----------------------------------------"
echo "MiniCPM-o 2.6 Web Demo - Auto Run Script"
echo "----------------------------------------"


#-----检查系统环境-----#

# 获取系统版本信息并打印
if [ -f /etc/os-release ]; then
    . /etc/os-release
    SYS_VERSION="$NAME $VERSION"
elif [ -f /etc/redhat-release ]; then
    SYS_VERSION=$(cat /etc/redhat-release)
else
    SYS_VERSION="Unknown"
fi
echo "System Version: $SYS_VERSION"

# 获取Python版本信息
PYTHON_VERSION=$(python3 --version 2>/dev/null || python --version 2>/dev/null)
if [ -z "$PYTHON_VERSION" ]; then
    echo "[ERROR] Python version not detected, make sure that Python is installed correctly."
    echo "[ERROR] 未检测到Python版本，请确保是否已正确安装Python。"
    exit 2 # 未检测到Python
fi
echo "Python Version: $PYTHON_VERSION"

# 检查是否已安装 Conda
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

if command_exists conda; then
    echo "检测到 Conda。"
    # 获取并打印 Conda 的版本
    CONDA_VERSION=$(conda --version)
    echo "Conda Version: $CONDA_VERSION"
else
    echo "Conda 未安装。"
fi

# 获取CUDA版本信息
CUDA_VERSION=$(command -v nvcc >/dev/null 2>&1 && nvcc --version | awk '/release/ {print $5}' | sed 's/,//')
if [ -z "$CUDA_VERSION" ]; then
    echo "[ERROR] CUDA is not detected, make sure if you are running with CUDA installed correctly, or with an Nvidia GPU."
    echo "[ERROR] 未检测到CUDA，请确保是否以正确安装CUDA，或使用Nvidia GPU运行。"
    exit 3 # 未检测到CUDA
fi
echo "CUDA Version: $CUDA_VERSION"

# 检查是否已安装 git-lfs
if ! command -v git-lfs >/dev/null 2>&1; then
    echo "Git-LFS is not installed. Installing Git-LFS..."
    echo "Git-LFS 未安装。正在安装 Git-LFS..."

    # 检查是否有sudo权限
    if [ "$EUID" -ne 0 ]; then
        echo "[WARN] This script needs to be run with sudo or as root for installation."
        echo "[WARN] 此脚本需要使用 sudo 或以 root 身份运行才能安装"
        exit 1
    fi

    # 尝试检测包管理器
    PACKAGE_MANAGER=""
    if command -v apt-get >/dev/null 2>&1; then
        PACKAGE_MANAGER="apt-get"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    elif command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    else
        echo "[ERROR] Unsupported package manager. Please install Git-LFS manually."
        exit 1
    fi

    # 安装 Git-LFS
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash || {
        echo "[ERROR] Failed to setup Git-LFS repository."
        exit 1
    }

    sudo $PACKAGE_MANAGER update -y || {
        echo "[ERROR] Failed to update package list."
        echo "[ERROR]  更新软件包列表失败"
        exit 1
    }

    sudo $PACKAGE_MANAGER install -y git-lfs || {
        echo "[ERROR] Failed to install Git-LFS."
        echo "[ERROR] 安装 Git-LFS 失败"
        exit 1
    }

    git lfs install || {
        echo "[ERROR] Failed to initialize Git-LFS."
        echo "[ERROR] 初始化 Git-LFS 失败"
        exit 1
    }

    echo "Git-LFS 已成功安装并初始化 Git-LFS has been successfully installed and initialized."
else
    echo "Git-LFS 已安装  Git-LFS is already installed."
fi

### -----模型下载----- ###

# func:检查路径是否存在
check_file_exists() {
    local file_path=$1
    if [ -d "$file_path" ]; then
        return 0
    else
        return 1
    fi
}

echo "您是否已下载MiniCPM-o-2_6模型文件。Have you downloaded the MiniCPM-o-2_6 model file? (y/n)"
read downloaded_model

local_path=$(pwd)

if [[ $downloaded_model == "y" ]]; then
    echo "Please enter the type of model downloaded (non-quantised press 0, int4 quantised press 1):"
    echo "请输入已下载的模型类型（非量化输入0，int4量化输入1）:"
    read model_type
    
    echo "请输入模型文件所在的路径（按回车键默认为当前目录）:"
    read model_path
    
    # 如果用户没有输入路径，则使用当前目录
    if [ -z "$model_path" ]; then
        model_path=$(pwd)
    fi
    
    if check_file_exists "$model_path"; then
        echo "确认信息如下："
        echo "模型类型: $(($model_type == 0 ? '非量化版本' : 'int4量化版本'))"
        echo "模型路径: $model_path"
    else
        echo "指定的路径不存在，请重新运行脚本并提供正确的路径。"
        exit 1
    fi
elif [[ $downloaded_model == "n" ]]; then
    echo "请选择要下载的模型类型（非量化输入0，int4量化输入1）:"
    read model_type
    
    echo "请输入模型文件所在的路径（按回车键默认为当前目录）:"
    read model_path
    
    # 如果用户没有输入路径，则使用当前目录
    if [ -z "$model_path" ]; then
        model_path=$(pwd)
    fi
    
    if ! check_file_exists "$model_path"; then
        echo "指定的路径不存在，请重新运行脚本并提供正确的路径。"
        exit 1
    fi
    
    cd "$model_path"
    
    if [[ $model_type == 0 ]]; then
        git clone https://www.modelscope.cn/OpenBMB/MiniCPM-o-2_6.git
        echo "非量化版本已成功克隆到 $model_path/MiniCPM-o-2_6"
        model_path = "$model_path/MiniCPM-o-2_6"
    elif [[ $model_type == 1 ]]; then
        git clone https://www.modelscope.cn/OpenBMB/MiniCPM-o-2_6-int4.git
        echo "int4量化版本已成功克隆到 $model_path/MiniCPM-o-2_6-int4"
        model_path = "$model_path/MiniCPM-o-2_6-int4"
    else
        echo "无效的选择，请输入0或1。"
        exit 1
    fi
else
    echo "无效的回答，请输入 y 或 n。"
    exit 1
fi

#-----安装依赖-----#
cd $local_path

# func：安装依赖项
install_dependencies() {
    echo "正在安装依赖..."
    pip install -r https://raw.githubusercontent.com/EnjoyCloudDev/MiniCPM-o-demo-script/refs/heads/main/requirements.txt
    
    # 如果是int4量化版本，则安装int4依赖
    if [[ $model_type == 1 ]]; then
        git clone https://github.com/OpenBMB/AutoGPTQ.git && cd AutoGPTQ || { echo "克隆AutoGPTQ仓库失败"; exit 1; }
        git checkout minicpmo || { echo "切换到minicpmo分支失败"; exit 1; }
        pip install -vvv --no-build-isolation -e . || { echo "安装AutoGPTQ失败"; exit 1; }
        cd "$local_path" || { echo "返回原始路径失败"; exit 1; }
    fi
}

# 检查并创建Conda环境
if [ -n "$CONDA_VERSION" ]; then
    echo "检测到您已安装Conda，正在创建Conda环境..."
    conda create -n minicpmo python==3.10 -y || { echo "创建Conda环境失败"; exit 1; }
    conda activate minicpmo || { echo "激活Conda环境失败"; exit 1; }
else
    echo "您还没有安装Conda，是否需要安装Conda？(y/n)"
    read install_conda
    if [[ $install_conda == "y" ]]; then
        echo "正在安装Miniconda..."
        curl -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh || { echo "下载Miniconda安装脚本失败"; exit 1; }
        bash miniconda.sh -b -p "$HOME/miniconda" || { echo "安装Miniconda失败"; exit 1; }
        export PATH="$HOME/miniconda/bin:$PATH"
        source "$HOME/miniconda/etc/profile.d/conda.sh"
        conda init bash || { echo "初始化Conda失败"; exit 1; }
        conda create -n minicpmo python==3.10 -y || { echo "创建Conda环境失败"; exit 1; }
        conda activate minicpmo || { echo "激活Conda环境失败"; exit 1; }
    else
        echo "将不使用Conda环境进行安装."
    fi
fi

# 安装依赖项
install_dependencies || { echo "安装依赖项失败"; exit 1; }

#-----运行模型-----#
# 拉取运行脚本
git clone https://github.com/EnjoyCloudDev/MiniCPM-o-demo-script.git
cd MiniCPM-o-demo-script || { echo "没有找到MiniCPM-o-demo-script目录"; exit 1; }

# 判断模型类型，选择执行固定的脚本
if [[ $model_type == 0 ]]; then
    python backend/model_server.py --model $model_path
elif [[ $model_type == 1 ]]; then
    python backend/model_server_int4.py --model $model_path
fi
