#!/bin/bash
docker run --init -it \
           -v ${PWD}/notebooks:/home/openintel/notebooks \
           -v ${PWD}/data:/home/openintel/data \
           -p 8888:8888 \
           --name openintel-quickstart --hostname openintel openintel-quickstart
