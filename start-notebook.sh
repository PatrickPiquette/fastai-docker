#!/bin/bash

usage() {
    me=$(basename "$0")
    echo
    echo "Usage: ./${me} -g -p [-s] [-u] [-r] [-i]"
    echo "Where:"
    echo "       -g                 GPU # to use"
    echo "       -p                 Port # to map"
    echo "       -s                 [optional] Data center server name to launch the Jupyter server into. Defaults to 'dc1-8gpu-01.elementai.lan'"
    echo "       -u                 [optional] Local user name. Defaults to your local machine username"
    echo "       -r                 [optional] Remote user name. Defaults to your local machine username"
    echo "       -i                 [optional] Remote user group id. Defaults to the 'arl' group id."
    echo "Ex:  ./${me} -g 1 -p 8889 "
}

showUsage () {
    echo
    echo >&2 ERROR: "$@"
    usage
    exit 1
}

die () {
    echo
    echo >&2 ERROR: "$@"
    echo
    exit 1
}

[[ $# -ge 2 ]] || showUsage "2 or 3 arguments required, $# provided"

# Defaults
username_local=${USER}
username_remote=${USER}
user_group_id_remote=18045  # Default to 'arl' group id
server_name=dc1-8gpu-01.elementai.lan
docker_image_name=images.borgy.elementai.lan/fastai/notebook-fastai

while getopts "g:p:s:u:r:i:" opt; do
  case $opt in
    g) gpu_number="$OPTARG"
    ;;
    p) port_number="$OPTARG"
    ;;
    u) username_local="$OPTARG"
    ;;
    r) username_remote="$OPTARG"
    ;;
    i) user_group_id="$OPTARG"
    ;;
    s) server_name="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
        showUsage
    ;;
  esac
done

echo "Building Docker image..."
echo ""
make publish.notebook-fastai

echo "Launching Jupyter remotely with these params:"
echo ""
echo "    gpu_number=${gpu_number}"
echo "    port=${port_number}"
echo "    username_local=${username_local}"
echo "    username_remote=${username_remote}"
echo "    user_group_id_remote=${user_group_id_remote}"
echo "    server_name=${server_name}"
echo "    docker_image_name=${docker_image_name}"

echo ""
echo "Pull docker image..."
ssh -o StrictHostKeyChecking=no ${username_remote}@${server_name} "docker pull ${docker_image_name}:${username_local}" 2>&1

#

echo ""
echo "*************************************************************************************"
echo "Starting docker container..."
echo ""

set -x # echo commands
docker_container_id=$(\
ssh -o StrictHostKeyChecking=no ${username_remote}@${server_name} \
"NV_GPU=${gpu_number} \
nvidia-docker run --rm -d -p ${port_number}:8888 \
--user \$(id -u):${user_group_id_remote} \
-v /mnt/projects/arl/fastai/:/projects \
--env HOME=/home/jupyter \
--env PYTHONPATH=/projects/code/${username_remote}/:/home/jupyter/src \
${docker_image_name}:${username_local} jupyter notebook --ip=0.0.0.0 --no-browser --notebook-dir=/projects/code/" \
\
2>&1)
set +x
echo ""
echo "*************************************************************************************"

# Note, above we set HOME
# Some commands may need to be able to write to your home, set it to temporary folder
# We run as an unnamed user, so we set an artificial home folder. See ./Dockerfile.


if [ $? -eq 0 ]
then
    echo ""
    echo "Started remote docker!"
    echo "${docker_container_id}"

    # Create a temporary stopping script
    stop_script_filename=stop_container_${docker_container_id}.sh
    open_in_browser_script_filename=open_browser_${docker_container_id}.sh
    cat << EOF > ${stop_script_filename}
        #!/bin/bash
        deleteTempScripts () {
            echo "Deleting temp scripts..."
            rm ${stop_script_filename}
            rm ${open_in_browser_script_filename}
        }

        echo "Stopping remote instance ${docker_container_id}"
        ssh -o StrictHostKeyChecking=no ${username_remote}@${server_name} "docker stop ${docker_container_id}"
        if [ \$? -eq 0 ]
        then
            echo "Container stopped successfully."
            deleteTempScripts
        else
            echo "Error stopping the remote docker container..."
            read -n 1 -p "Delete this temporary script (y/n)? " answer
            if [ \$answer == "y" ]
            then
                deleteTempScripts
            fi
        fi
EOF
    chmod +x ${stop_script_filename}

    # get the Jupyter token from the docker logs
    echo ""
    echo "Waiting for jupyter to startup..."
    logs=""
    i=0
    while [ -z "$logs" -a "$((i+=1))" -le "5" ]
    do
        echo "Sleeping 2 secs..."
        sleep 2
        logs=$(ssh -o StrictHostKeyChecking=no ${username_remote}@${server_name} "docker logs ${docker_container_id}" 2>&1)
    done

    if [ -z "$logs" ]
    then
        echo "Cannot get the Jupyter logs..."
    else
        echo "Extracting Jupyter token from the logs..."
        token=`echo $logs | sed -n -e 's/.*token=\(.*\)/\1/p'`

        # keep only first match
        token=`echo $token | head -1`

        if [ -z "$token" ]
        then
            echo "Unable to extract the Jupyter token from the logs..."
            echo "$logs"
        else
            echo "*************************************************************************************"
            echo "Jupyter token: ${token}"
            echo ""
            url="http://${server_name}:${port_number}?token=${token}"

            # Create an open-in-browser script
            cat << EOF > ${open_in_browser_script_filename}
                #!/bin/bash
                open ${url}
EOF
            chmod +x ${open_in_browser_script_filename}

            echo "Opening: ${url}"
            open ${url}

            echo ""
            echo "To stop the docker container, use the script:"
            echo "${stop_script_filename}"
            echo "*************************************************************************************"
        fi
    fi

else
    echo "Error starting remote docker..."
    echo "${docker_container_id}"
fi
