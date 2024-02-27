#+/bin/bash

COMMON_PACKAGES="pciutils xpython3.10 pyhton3.10-venv git make pandoc"
NVIDIA_PACKAGES="cuda nvidia-drivers nvidia-utils"
AMD_PACKAGES="mesa-vulkan-drivers rocm"

VERSION="1"
LOGFILE="Linux/logs/installer.log"

check_dir(){
    current_dir=$(basename "$PWD")
    if [ "$current_dir" != "ChromaDB-Plugin-for-LM-Studio" ]; then
        curl "https://github.com/BBC-Esq/ChromaDB-Plugin-for-LM-Studio/archive/refs/tags/v4.0.0.tar.gz"
        tar -xvf v4.0.0.tar.gz # Make sure the file name matches what wget downloads
	cd Chroma*/src
    else 
        echo "Already in the right directory, skipping download"
    fi
}

OS="Unknown"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
fi

select_gpu_packages() {
    gpu_info=$(lspci | grep -i 'VGA\|3D\|Display')

    # Default to no GPU-specific packages
    GPU_PACKAGES=""

    # Check if GPU information is available
    if [ -n "$gpu_info" ]; then
        # Extract GPU name
        gpu_name=$(echo "$gpu_info" | sed -n 's/.*: \(.*\)/\1/p')
        
        # Select GPU-specific packages
        if echo "$gpu_name" | grep -q 'NVIDIA Corporation'; then
            GPU_PACKAGES="nvidia-utils-535"
        elif echo "$gpu_name" | grep -q 'Advanced Micro Devices'; then
            GPU_PACKAGES="mesa-vulkan-drivers rocm"
        elif echo "$gpu_name" | grep -q 'Intel Corporation'; then
            # Specify Intel GPU packages if necessary
            GPU_PACKAGES=""
        fi
    fi
}

install_cuda() {
    local os_version="$1"
    
    case "$os_version" in
        "ubuntu2204")
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
            sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-ubuntu2204-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo dpkg -i cuda-repo-ubuntu2204-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo cp /var/cuda-repo-ubuntu2204-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
            sudo apt-get update
            sudo apt-get -y install cuda-toolkit-12-3
            ;;
        "ubuntu2004")
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
            sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo dpkg -i cuda-repo-ubuntu2004-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo cp /var/cuda-repo-ubuntu2004-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
            sudo apt-get update
            sudo apt-get -y install cuda-toolkit-12-3
            ;;
        "fedora37")
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-fedora37-12-3-local-12.3.2_545.23.08-1.x86_64.rpm
            sudo rpm -i cuda-repo-fedora37-12-3-local-12.3.2_545.23.08-1.x86_64.rpm
            sudo dnf clean all
            sudo dnf -y install cuda-toolkit-12-3
            ;;
        "rhel9")
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-rhel9-12-3-local-12.3.2_545.23.08-1.x86_64.rpm
            sudo rpm -i cuda-repo-rhel9-12-3-local-12.3.2_545.23.08-1.x86_64.rpm
            sudo dnf clean all
            sudo dnf -y install cuda-toolkit-12-3
            ;;
        "debian12")
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-debian12-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo dpkg -i cuda-repo-debian12-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo cp /var/cuda-repo-debian12-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
            sudo add-apt-repository contrib
            sudo apt-get update
            sudo apt-get -y install cuda-toolkit-12-3
            ;;
        "debian11")
            wget https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda-repo-debian11-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo dpkg -i cuda-repo-debian11-12-3-local_12.3.2-545.23.08-1_amd64.deb
            sudo cp /var/cuda-repo-debian11-12-3-local/cuda-*-keyring.gpg /usr/share/keyrings/
            sudo add-apt-repository contrib
            sudo apt-get update
            sudo apt-get -y install cuda-toolkit-12-3
            ;;
        *)
            echo "Unsupported OS version"
            ;;
    esac
}

check_python() {
    PYTHON_VERSION=$(python3 --version 2>/dev/null | grep -oP '(?<=Python )\d+\.\d+')
    PYTHON_VENV_PACKAGE="python3.10-venv" 

    if [[ $PYTHON_VERSION < 3.10 ]]; then
        echo "Python 3.10 or higher is not installed. Please install it using your distribution's package manager."
        case $1 in
            "Ubuntu"|"Debian")
                echo "Run: sudo apt install python3.10 python3.10-venv (or higher)" ;;
            "Arch")
                echo "Run: sudo pacman -S python3.10 python3.10-venv (or higher)" ;;
            "RedHat")
                echo "Run: sudo yum install python3.10 python3.10-venv (or higher)" ;;
            *)
                echo "Unsupported distribution." ;;
        esac
    else
        echo "Python 3.10 or higher is installed."
    fi
}

# Installation function
install_packages() {
    # Define common packages
    COMMON_PACKAGES="pciutils gcc git make pandoc curl wget"
    # Combine common and GPU-specific packages
    INSTALL_PACKAGES="$COMMON_PACKAGES $GPU_PACKAGES"
    # Installation commands based on distribution
    if [[ "$1" == "Ubuntu" || "$1" == "Debian" ]]; then
        apt update
        apt install software-properties-common -y
        add-apt-repository ppa:deadsnakes/ppa -y 
        apt install python3.10-venv -y
        apt install -y $INSTALL_PACKAGES
        apt install build-essential
    elif [[ "$1" == "Arch" ]]; then
        sudo pacman -Syu
        sudo pacman -S cuda
        sudo pacman -S $INSTALL_PACKAGES
    elif [[ "$1" == "RedHat" ]]; then
        sudo yum update
        sudo yum install -y $INSTALL_PACKAGES
    fi
}

create_python_venv() {
    if command -v python3.10 >/dev/null 2>&1; then
        python3.10 -m venv plugin_venv
        echo "Virtual environment created with Python 3.10 in 'plugin_venv' directory."
    elif command -v python3.11 >/dev/null 2>&1; then
        python3.11 -m venv plugin_venv
        echo "Virtual environment created with Python 3.11 in 'plugin_venv' directory."
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m venv plugin_venv
        echo "Virtual environment created with default Python 3 in 'plugin_venv' directory."
    else
        echo "No suitable Python 3 version found. Please install Python 3."
        return 1
    fi
}

activate_venv() {
    source plugin_venv/bin/activate
    echo "Virtual environment activated."
}

pip_dependencies() {
    pip install -r requirements.txt
    pip install nvidia-ml-py
    pip install torch
    pip install bitsandbytes
    pip install --no-deps whisper-s2t==1.3.0
    pip install xformers==0.0.24
    echo "Dependencies installed from requirements.txt."
}

main() {
    echo "Starting setup..."

    
    # Determine OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        echo "Unable to determine operating system."
        exit 1
    fi

    # Select GPU packages based on the system's GPU
    # Install common and GPU-specific packages

    install_packages "$OS"

    select_gpu_packages
    os_version=$(lsb_release -cs)
   # Checks specific part of the os for cuda 
    case "$os_version" in
        "jammy")
            install_cuda "ubuntu2204"
            ;;
        "focal")
            install_cuda "ubuntu2004"
            ;;
        "fedora37")
            install_cuda "fedora37"
            ;;
        "rhel9")
            install_cuda "rhel9"
            ;;
        "bookworm")
            install_cuda "debian12"
            ;;
        "bullseye")
            install_cuda "debian11"
            ;;
        *)
            echo "Unsupported OS version"
            ;;
    esac
    # Check current directory and download if necessary
    check_dir

    # Create and activate a Python virtual environment
    create_python_venv
    activate_venv
    pip install wheel

    # Install Python dependencies
    pip_dependencies

    echo "Setup complete."
}

# Check if the script is being run directly and call main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
