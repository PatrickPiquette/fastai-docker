
## Using the Docker image


### Building the docker image

Build and send the Docker image to the data center:
```
make publish.notebook-fastai
```

### Starting the docker container remotely

Use `./start-notebook.sh` to start the docker container on a remote server, like for example `dc1-8gpu-01.elementai.lan`
```
Usage: ./start-notebook.sh -g -p [-s] [-u] [-r]
Where:
       -g                 GPU # to use
       -p                 Port # to map
       -s                 [optional] Data center server name to launch the Jupyter server into. Defaults to 'dc1-8gpu-01.elementai.lan'
       -u                 [optional] Local user name. Defaults to your local machine username
       -r                 [optional] Remote user name. Defaults to your local machine username
Ex:  ./start-notebook.sh -g 1 -p 8889
```

For example, to start with default values, on GPU #1 and port 6789:
```
./start-notebook.sh -g 1 -p 6789
```

It should open your browser on the running Jupyter server.

You can re-open the browser with: `open_browser_xxxx.sh`


### Stopping the container

You can stop the docker container with the temporary script that was generated: `stop_container_xxxx.sh`


### To look into the Jupyter logs

- Log into the remote machine.
- Do `docker ps`, find your running container id.
- The do `docker logs THE_CONTAINER_ID`

