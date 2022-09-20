#! /usr/bin/bash

set -e

server=False
branch="master"

while getopts h:p:e:s:b:t flag
do
    case "$flag" in
        h) host=${OPTARG};;
        p) projectName=${OPTARG};;
        e) envFile=${OPTARG};;
        s) serverType=${OPTARG};;
        b) branch=${OPTARG};;
        t) typescript=True;;
    esac
done

cd /var/lib/jenkins/projects/$projectName
git pull
git checkout $branch

if [[ $serverType == "node" ]]
then
    cp -r ../$envFile ./.env
    if [[ $typescript == True ]]
    then
        yarn install
        yarn build
        cp .env build/
        rm -rf -f node_modules
    fi
    cd ../
    zip -r $projectName.zip $projectName/ -x "$projectName/.git/*"
    scp -r $projectName.zip $host:~/temp

    ssh $host << EOF
    unzip -o temp/$projectName.zip -d ./
    cd $projectName
    yarn install
    pm2 restart all
    exit
EOF
elif [[ $serverType == 'react' ]]
then
    cp -r ../$envFile ./.env
    yarn install
    rm -rf build
    yarn build
    zip -r build.zip build
    scp -r build.zip $host:~/temp
    ssh $host << EOF
    unzip -o temp/build.zip -d temp/
    cp -r temp/build $projectName/
    exit
EOF
fi