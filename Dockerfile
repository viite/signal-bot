FROM registry.gitlab.com/packaging/signal-cli/signal-cli-jre:latest

USER root

RUN <<EOD
  apt-get update
  apt-get install -y --no-install-recommends python3-pip python3-venv ruby
  mkdir /app/
  chown signal-cli /app
EOD

WORKDIR /app
USER signal-cli
SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

RUN <<EOD
  python3 -m venv venv
  source venv/bin/activate
  python3 -m pip install google-genai
EOD

COPY generate_pic.py /app

USER signal-cli
