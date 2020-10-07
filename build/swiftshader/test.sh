#!/bin/bash
set -e

function print_help {
    local self_name=$(basename "$0")
    echo "This linux-only script issues docker commands for testing Filament with SwiftShader."
    echo "The usual sequence of commands is: fetch, start, build filament release, and run."
    echo ""
    echo "Usage:"
    echo "    $self_name [command]"
    echo ""
    echo "Commands:"
    echo "    build filament [debug | release]"
    echo "        Use the container to build Filament."
    echo "    build swiftshader [debug | release]"
    echo "        Use the container to do a clean rebuild of SwiftShader."
    echo "        (Note that the container already has SwiftShader built.)"
    echo "    fetch"
    echo "        Download the docker image from the central repository."
    echo "    help"
    echo "        Print this help message."
    echo "    run [lldb]"
    echo "        Launch a test inside the container, optionally via lldb."
    echo "    shell"
    echo "        Interact with a bash prompt in the container."
    echo "    start"
    echo "        Start a container from the image."
    echo "    stop"
    echo "        Stop the container."
    echo ""
}

# Change the current working directory to the Filament root.
pushd "$(dirname "$0")/../.." > /dev/null

if [[ "$1" == "build" ]] && [[ "$2" == "filament" ]]; then
    docker exec runner filament/build.sh -t $3 gltf_viewer
    exit $?
fi

if [[ "$1" == "build" ]] && [[ "$2" == "swiftshader" ]]; then
    BUILD_TYPE="$3"
    BUILD_TYPE="$(tr '[:lower:]' '[:upper:]' <<< ${BUILD_TYPE:0:1})${BUILD_TYPE:1}"
    docker exec --workdir /trees/swiftshader runner rm -rf build
    docker exec --workdir /trees/swiftshader runner mkdir build
    docker exec --workdir /trees/swiftshader/build runner cmake -GNinja -DCMAKE_BUILD_TYPE="$BUILD_TYPE" ..
    docker exec --workdir /trees/swiftshader/build runner ninja
    exit $?
fi

if [[ "$1" == "fetch" ]]; then
    docker pull ghcr.io/filament-assets/swiftshader:latest
    docker tag ghcr.io/filament-assets/swiftshader:latest ssfilament
    exit $?
fi

if [[ "$1" == "help" ]]; then
    print_help
    exit 0
fi

if [[ "$1" == "run" ]] && [[ "$2" == "lldb" ]]; then
    docker exec -i --workdir /trees/filament/results runner \
          lldb --batch -o run -o bt -- \
          ../out/cmake-release/samples/gltf_viewer \
          --headless \
          --batch ../libs/viewer/tests/basic.json \
          --api vulkan
    docker exec runner /trees/filament/build/swiftshader/gallery.py
    exit $?
fi

if [[ "$1" == "run" ]]; then
    docker exec --tty  --workdir /trees/filament/results runner \
          /usr/bin/catchsegv \
          ../out/cmake-release/samples/gltf_viewer \
          --headless \
          --batch ../libs/viewer/tests/basic.json \
          --api vulkan
    docker exec runner /trees/filament/build/swiftshader/gallery.py
    exit $?
fi

if [[ "$1" == "shell" ]]; then
    docker exec --interactive --tty runner /bin/bash
    exit $?
fi

if [[ "$1" == "start" ]]; then
    mkdir -p results
    docker run --tty --rm --detach \
          --name runner \
          --cap-add=SYS_PTRACE \
          --security-opt seccomp=unconfined \
          --security-opt apparmor=unconfined \
          --volume `pwd`:/trees/filament \
          --workdir /trees \
          ssfilament
    exit $?
fi

if [[ "$1" == "stop" ]]; then
    docker container rm runner --force
    exit $?
fi

print_help
exit 1
