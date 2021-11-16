ARG BASE_IMAGE=ubuntu:20.04

#
# primordial base stage with common layers for all other stages
#
FROM ${BASE_IMAGE} AS primordial
# Configure apt to never install recommended packages and do not prompt for user input
RUN printf 'APT::Install-Recommends "0";\nAPT::Install-Suggests "0";\n' >> /etc/apt/apt.conf.d/01norecommends
ENV DEBIAN_FRONTEND=noninteractive
# Add .local to the path for pip installed tools
ENV PATH="${PATH}:/root/.local/bin"


#
# build_supervisor stage to build/install supervisord
#
FROM primordial AS build_supervisor
RUN apt-get update && apt-get install --yes \
        python3 \
        python3-pip
# Install supervisor
RUN pip3 install \
        --no-cache-dir \
        --upgrade \
        --compile \
        --user \
        setuptools \
        supervisor


#
# base stage for the applications to build from
#
FROM primordial as base
# Install python
RUN apt-get update && apt-get install --yes \
        python3 \
        python-is-python3 \
        && \
    apt-get autoremove --yes && apt-get clean && rm -rf /var/lib/apt/lists/*
# Copy supervisord from the build stage
COPY --from=build_supervisor /root/.local /root/.local
# Setup supervisor configuration
RUN mkdir /var/log/supervisor
COPY supervisord.conf /etc/supervisor/supervisord.conf
RUN mkdir /etc/supervisor/conf.d/
# Setup supervisor healthcheck
COPY supervisor-healthcheck /usr/local/bin/
HEALTHCHECK --interval=60s --timeout=15s --start-period=5s --retries=3 CMD [ "/usr/local/bin/supervisor-healthcheck" ]
# Make supervisord the entrypoint for this container
ENTRYPOINT ["supervisord", "--config", "/etc/supervisor/supervisord.conf"]

#
# Final stage to add applications
#
FROM base as apps

# Copy files and install dependencies for each app
COPY service-sample1 /usr/local/bin
COPY service-sample1.conf /etc/supervisor/conf.d/

COPY service-sample2 /usr/local/bin
COPY service-sample2.conf /etc/supervisor/conf.d/
