# Raspberry Pi Solar Logger


SSH into the Raspberry Pi:

```
ssh user@raspberrypi.local
```


## Setup I2C, sqlite, python venv, and github ssh keys on a new Pi

Enable the primary I2C bus. In a terminal, run `sudo raspi-config`, then go to Interface Options > I2C and enable kernel loading of I2C.


Install sqlite3. Run `sudo apt install sqlite3`

Install Python venv library and create venv.

```
mkdir ~/.virtualenvs
cd ~/.virtualenvs
python3 -m venv solar
```

Create an SSH keypair.

```
cd ~/.ssh
ssh-keygen -t ed25519 -C "your.email@example.com"
```

Add the SSH public key in GitHub. 

Copy the contents of ~/.ssh/id25519.pub to the clipboard.

On GitHub.com, go to Account > Settings > SSH and GPG keys > SSH keys, and click "New SSH key".
Name the key "Raspberry Pi" and paste the public key contents created above.

Clone the project and install Python libraries.

```
git config --global user.email "your.email@example.com"
git config --global user.name "Your Name"

mkdir ~/projects
cd ~/projects
git clone git@github.com:pzingg/electronics

cd ~/projects/electronics/solar_logger
source ~/.virtualenvs/solar/bin/activate
pip3 install -r requirements.txt
```

## Running the program

```
cd ~/projects/electronics/solar_logger
python3 logger.py
```
