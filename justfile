set positional-arguments
set dotenv-load
set export

IMAGE := env_var_or_default("IMAGE", "debian-systemd")
IMAGE_SRC := env_var_or_default("IMAGE_SRC", "debian-systemd")

# Build packages
build *ARGS:
    ./ci/build.sh {{ARGS}} -- -f tedge-log-provider/nfpm.yaml

# Install python virtual environment
venv:
  [ -d .venv ] || python3 -m venv .venv
  ./.venv/bin/pip3 install -r tests/requirements.txt

# Build test images
build-test:
  docker build -t {{IMAGE}} -f ./test-images/{{IMAGE_SRC}}/Dockerfile .

# Run tests
test *args='':
  ./.venv/bin/python3 -m robot.run --outputdir output {{args}} tests
