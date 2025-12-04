#!/usr/bin/env bash
set -e

USER="nite_dev"

echo ">>> [User] Creating user '$USER'..."
if id "$USER" &>/dev/null; then
    echo "   User already exists."
else
    # Create user, add to sudo group, set shell to bash
    useradd -m -s /bin/bash -G sudo $USER
    echo "   User created."
fi

echo ">>> [User] Copying SSH keys from root..."
mkdir -p /home/$USER/.ssh
cp /root/.ssh/authorized_keys /home/$USER/.ssh/
chown -R $USER:$USER /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys

echo ">>> [User] Fixing permissions for /opt/nite-os-v7..."
# Allow the group to modify files so the dev user can deploy/edit
chown -R root:$USER /opt/nite-os-v7
chmod -R 775 /opt/nite-os-v7

echo ">>> [User] Enabling Passwordless Sudo (Optional)..."
# Allows executing sudo commands without typing a password
echo "$USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/90-$USER

echo ">>> DONE! You can now logout and SSH as: ssh $USER@<YOUR_IP>"1~#!/usr/bin/env bash
set -e

USER="nite_dev"

echo ">>> [User] Creating user '$USER'..."
if id "$USER" &>/dev/null; then
    echo "   User already exists."
else
    # Create user, add to sudo group, set shell to bash
    useradd -m -s /bin/bash -G sudo $USER
    echo "   User created."
fi

echo ">>> [User] Copying SSH keys from root..."
mkdir -p /home/$USER/.ssh
cp /root/.ssh/authorized_keys /home/$USER/.ssh/
chown -R $USER:$USER /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys

echo ">>> [User] Fixing permissions for /opt/nite-os-v7..."
# Allow the group to modify files so the dev user can deploy/edit
chown -R root:$USER /opt/nite-os-v7
chmod -R 775 /opt/nite-os-v7

echo ">>> [User] Enabling Passwordless Sudo (Optional)..."
# Allows executing sudo commands without typing a password
echo "$USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/90-$USER

echo ">>> DONE! You can now logout and SSH as: ssh $USER@31.97.126.86"
