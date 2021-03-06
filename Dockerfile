# Debian based image
FROM ubuntu
RUN apt-get update && apt-get install -y \
    software-properties-common \
    build-essential \
    git \
    ffmpeg \
    libjpeg-dev \
    libfreetype6 \
    libfreetype6-dev \
    libpq-dev \
    postgresql-client \
    python3-dev \
    python3-venv \
    zlib1g-dev \
    ruby-sass \
    default-jdk \
    procps \
    wget \
    nginx \
    sox \
    gunicorn

# Get barren Praat and add it to the path
RUN wget http://www.fon.hum.uva.nl/praat/praat6109_linux64barren.tar.gz && \
 gunzip praat6109_linux64barren.tar.gz && \
 tar xvf praat6109_linux64barren.tar && \
 mv praat_barren praat && \
    export PATH=$PATH:/$PWD

# Get Reaper (should already be on path)
RUN apt-get update && apt-get install -y cmake
RUN git clone https://github.com/google/REAPER.git && \
    cd REAPER && \
 mkdir build && \
    cd build && \
 cmake .. && \
 make

ENV PATH $PATH:/:/REAPER/build

# Get autovot

RUN git clone https://github.com/mlml/autovot && \
  cd autovot/autovot/code && \
  make clean && \
  make

ENV PATH $PATH:/autovot/autovot/bin

# Get Dockerize
RUN apt-get update && apt-get install -y wget
ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz &&\
    export PATH=$PATH:/$PWD

# set the environment variable default; can be overridden by compose
ENV SITE_DIR=/site/
RUN mkdir -p $SITE_DIR
WORKDIR $SITE_DIR
RUN mkdir -p proj/ var/log/ htdocs/

# create a virtualenv to separate app packages from system packages
RUN python3 -mvenv env/
COPY docker-utils/ssl/ ssl/

# pre-install requirements; doing this sooner prevents unnecessary layer-building
COPY requirements.txt requirements.txt
COPY requirements_testing.txt requirements_testing.txt
RUN env/bin/pip install pip --upgrade
RUN env/bin/pip install -r requirements.txt -U


# Get django
RUN find -L . -name . -o -type d -prune -o -type l -exec rm {} +
RUN env/bin/pip install django psycopg2-binary
RUN if [ ! -f /usr/local/bin/django-admin.py ]; then ln -s /home/docker/.local/bin/django-admin.py /usr/local/bin; fi

# Set some environment variables; can be overridden by compose
ENV NUM_THREADS=2
ENV NUM_PROCS=2
ENV DJANGO_DATABASE_URL=postgres://postgres@db/postgres

# Copy in docker scripts
COPY docker-utils/ docker-utils/

# Copy in project files
COPY . proj/

# Get Node.js
WORKDIR proj/
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm && \
    npm install -y

ARG BUILD_ENV=prod
ARG UPGRADE=no

RUN if [ "$BUILD_ENV" = "test" ] || [ "$BUILD_ENV" = "dev" ]; then ${SITE_DIR}/env/bin/pip install -r requirements_testing.txt -U ; fi
# Put bin on path
ENV PATH=$PATH:/bin

# Put venv on path
ENV PATH=/site/env/bin:$PATH

EXPOSE 8080

RUN echo "$BUILD_ENV" > /build_env

# Set a custom entrypoint to let us provide custom initialization behavior
ENTRYPOINT ["./docker-utils/start.sh"]
RUN if [ "$UPGRADE" = "y" ]; then ${SITE_DIR}/env/bin/pip install -r requirements.txt -U ; fi
