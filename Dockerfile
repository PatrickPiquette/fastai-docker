# stretch is the codename for Debian 9.
FROM nvidia/cuda:9.1-cudnn7-devel

# Comes from deployzor.mk, not used here. Remove a warning
ARG version

ENV DEBIAN_FRONTEND noninteractive


# -----------------------------------------------------------------------------
# Install Python3 from PPA
#
# See https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.6-dev && \
    apt-get install -y wget

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1

# Install pip
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py
RUN pip install --upgrade pip setuptools wheel


# -----------------------------------------------------------------------------
# Some commands may need to be able to write to your home, set it to temporary folder
# We run as our datacenter user, which is unkown inside the docker container,
# so we set an artificial HOME folder when launching it. See ./start-notebook.sh
WORKDIR /home/jupyter


# -----------------------------------------------------------------------------
# Install requirements.txt

COPY requirements.txt .
RUN pip install -r requirements.txt

# -----------------------------------------------------------------------------
# Copy the /src/ folder to /home/jupyter, so that we can import it from notebooks.
# See ```--env PYTHONPATH=/home/jupyter``` in ./start-notebook.sh
#COPY src ./src
RUN chmod -R a=rwx /home/jupyter


