# Raspberry Pi Solar Logger


SSH into the Raspberry Pi:

```
ssh user@raspberrypi.local
```

On the Pi:

```
sudo apt install sqlite3

cd ~
mkdir .virtualenvs
cd ~/.virtualenvs
python3 -m venv solar

cd ~/.ssh
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Copy the contents of ~/.ssh/id25519.pub to the clipboard

On GitHub.com, go to Account > Settings > SSH and GPG keys > SSH keys, and click "New SSH key".
Name the key "Raspberry Pi" and paste the public key contents created above.

Back on the Pi:

```
mkdir ~/projects
cd ~/projects
git clone git@github.com:pzingg/electronics
source ~/.virtualenvs/solar/bin/activate
cd electronics/solar_logger
pip3 install -r requirements.txt
```




