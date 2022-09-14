#! /usr/bin/bash

while getopts h:p:ts flag
do
    case "$flag" in
        h) host=${OPTARG};;
        p) projectName=${OPTARG};;
        t) typescript=True;;
        s) server=True
    esac
done

cd /var/lib/jenkins/projects/$projectName
git pull
git checkout master
cd ../
zip -r $projectName.zip $projectName/ -x "$projectName/.git/*"
scp -r $projectName.zip $host:/home/ubuntu/temp
ssh $host << EOF
unzip -o temp/$projectName.zip -d temp/
if [[ $server == True ]]
then
    cp -r temp/$projectName ./
    cd $projectName
    yarn install
    if [[ $typescript == True ]]
    then
        yarn build
        cp .env build/
    fi
    pm2 restart all
else
    cd temp/$projectName
    yarn install
    yarn build
    cp -r build ../../$projectName
fi
exit
EOF