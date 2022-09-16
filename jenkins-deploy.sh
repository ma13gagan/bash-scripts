#! /usr/bin/bash

print_messages(){
    if [[ $2 -gt 0 ]]
    then
        textColor=$2
    else
        textColor=4
    fi

    echo "$(tput setaf $textColor)##############################
        $1
##############################"
}

# Exit when any command fails
set -e

# Keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# Echo an error message before exiting
trap 'print_messages "\"${last_command}\" command failed with exit code $?." 1' EXIT

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
print_messages "Pull Completed"

cd ../
zip -r $projectName.zip $projectName/ -x "$projectName/.git/*"
scp -r $projectName.zip $host:~/temp

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