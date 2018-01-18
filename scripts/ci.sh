#!/bin/bash

base_dir=$(dirname `readlink -f "$0"`)
docker_compose_file="${base_dir}/../docker/docker-compose.yml"
makefile="${base_dir}/../Makefile"

exit_code=0

# compile and install docker plugin
if sudo BASE_DIR="$base_dir/.." make -f "$makefile"; then

    # create and run logstash as a container
    if docker-compose -f "$docker_compose_file" up -d logstash; then

        # create a container for logging to logstash
        if "${base_dir}/./wait-for.sh" logstash 5000 docker-compose -f "$docker_compose_file" up -d webapper; then

            # create some tests tests
            sample_message="this-is-one-logging-line"
            curl "http://172.31.0.3:8080/$sample_message" &>/dev/null

            # wait couple of seconds for the message to be processed by logstash
            sleep 3

            if docker logs logstash | grep "$sample_message"; then
                echo "it works like a charm"
            else
                echo "something went wrong"
                exit_code=1
            fi

        else
            exit_code=1
        fi

    else
        exit_code=1
    fi

else
    exit 1
fi

# post tasks
docker-compose -f "$docker_compose_file" rm --stop --force

if [ $exit_code -ne 0 ]; then
    exit 1
fi