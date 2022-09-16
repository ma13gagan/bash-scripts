# Bash Scripts Usage Docs

## 1. server-setup.sh script

Download the script

```sh
curl -o script.sh https://raw.githubusercontent.com/ma13gagan/bash-scripts/main/server-setup.sh && chmod +x script.sh
```

Script usage

```sh
sudo ./script.sh -p <project name> -k <public key> -h <host name> -d
```

> -d is the optional flag for installing docker

## 2. jenkins-deploy.sh script

Download the script

```sh
curl -o script.sh https://raw.githubusercontent.com/ma13gagan/bash-scripts/main/jenkins-deploy.sh && chmod +x script.sh
```

Script usage

```sh
./script.sh -p <project name> -h <host name> -t -s
```

> -t is the optional flag for typescript
> -s is optional flag if project is server. Note: If it is a react project
