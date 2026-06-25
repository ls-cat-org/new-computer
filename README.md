# new-computer
Configuration files for commissioning a new LS-CAT computer

## Prerequisites
For the operating system you have installed on your machine, please complete the following tasks before using this utility:

1. Configure your network interfaces and assign an internal network IP address to your machine.

2. Install the lustre client.

3. As root, generate an SSH key for github access by running "ssh-keygen" (no arguments, no password),
   then add the public key to the list of deploy keys for this repository using the link below:
   
       https://github.com/ls-cat-org/new-computer/settings/keys


## Usage
For the operating system version you have installed on your machine, please use the
appropriate install.sh script in the corresponding subdir of this repository. For example,
the install script for Ubuntu Server 24.04 is located under "ubuntu-server/24.04".
To use it, the commands are:

    git clone git@github.com:ls-cat-org/new-computer.git
    cd ubuntu-server/24.04
    ./install.sh
    
Please follow the on-screen instructions of the install script to complete the installation.
