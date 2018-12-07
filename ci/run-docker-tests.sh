#!/bin/bash
set -ex

# Switch to same directory that this script lives in
cd "$(dirname "$0")"

# Switch to project base directory
pushd ../

docker build -f Dockerfile -t example-tests .

docker run -v julia-depot:/root/.julia example-tests
