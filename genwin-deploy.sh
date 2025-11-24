#!/bin/sh
docker build -f tools/docker/Dockerfile . -t genwininc/smelter
docker push genwininc/smelter