FROM registry.gitlab.com/packaging/signal-cli/signal-cli-jre:latest

SHELL ["/bin/bash", "-euxo", "pipefail", "-c"]

USER root

RUN <<EOD
  apt-get update
  apt-get install -y --no-install-recommends python3-pip python3-venv ruby bundler
  mkdir /app/
  chown signal-cli /app
EOD

WORKDIR /app

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock

RUN <<EOD
  PACKAGES="build-essential ruby-dev"
  apt-get install -y --no-install-recommends ${PACKAGES}
  bundle
  apt-get purge -y --autoremove ${PACKAGES}
EOD

USER signal-cli

RUN <<EOD
  python3 -m venv venv
  source venv/bin/activate
  python3 -m pip install google-genai
EOD

COPY generate_pic.py /app

USER signal-cli

ENTRYPOINT ["ruby", "source/bot.rb"]
