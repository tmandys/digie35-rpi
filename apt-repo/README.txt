# Register external repositories in apt database running following commands (in Debian based distro):

. /etc/os-release

sudo mkdir -m 0755 -p /etc/apt/keyrings/

# log2ram repo
curl -fsSL https://azlux.fr/repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/azlux.gpg
echo "deb [signed-by=/etc/apt/keyrings/azlux.gpg] http://packages.azlux.fr/debian/ $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/azlux.list

# digie35 repo
url=https://repos.digie35.com/debian
curl -fsSL $url/repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/digie35.gpg
echo "deb [signed-by=/etc/apt/keyrings/digie35.gpg] $url $VERSION_CODENAME main" | sudo tee /etc/apt/sources.list.d/digie35.list

# Microsoft vscode repo
url=https://packages.microsoft.com
curl -fsSL $url/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] $url/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list


sudo apt update

# upgrade to latest, note: e.g. kernel 6.1.63 does not work with PWM@GPIO12,3. Kernel 6.6.31 is ok
sudo apt-get upgrade

# install rpi-digie35 which will install dependencies
sudo apt-get install rpi-digie35

# install python stuff, latest version or use 0.4 and run upgrade from GUI
sudo rm /usr/lib/python3.11/EXTERNALLY-MANAGED

pip install --user https://repos.digie35.com/python/digie35_ctrl-0.6-py3-none-any.whl

# if ~/.local/bin did not exist then force adding to path
. ~/.profile

# install digie35 services, www, ...
digie35_install -i

# satisfy nginx
chmod a+x /home/pi/
