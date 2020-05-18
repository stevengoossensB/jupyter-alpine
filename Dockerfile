# Author: Steven Goossens
# License: GPL-3.0
# References:
# https://github.com/jupyter/docker-stacks/blob/master/all-spark-notebook/Dockerfile
# https://derflounder.wordpress.com/2016/07/11/editing-etcsudoers-to-manage-sudo-rights-for-users-and-groups/

FROM alpine:latest
LABEL maintainer="Steven Goossens"
LABEL description="Dockerfile Jupyter on Alpine Linux"

ENV DEBIAN_FRONTEND noninteractive

USER root

# **** Set ARG Values ****
ARG JUPYTER_USER=jupyter
ARG JUPYTER_UID=810
ARG JUPYTER_GID=810

# *********** Setting Environment Variables ***************
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV JUPYTER_DIR=/opt/jupyter
ENV CONDA_DIR=/opt/conda
ENV PATH /opt/conda/bin:$PATH
# ********** Jupyter User ******
ENV USER ${JUPYTER_USER}
ENV JUPYTER_UID ${JUPYTER_UID}
ENV HOME /home/${JUPYTER_USER}
ENV JUPYTER_GID=$JUPYTER_GID

# *********** Installing Prerequisites ***************
# ********** Installing Initial Requirements ***************
RUN apk update  && apk add wget sudo nano curl build-base bash openssl bzip2 ca-certificates glib \
  git mercurial subversion unzip zip \
# ********** Adding Jupyter User **************
  && addgroup -g ${JUPYTER_GID} ${JUPYTER_USER}\
  && adduser -D -s /bin/bash -u ${JUPYTER_UID} -G ${JUPYTER_USER} ${JUPYTER_USER} \
  && mkdir -pv /opt/jupyter/{notebooks,scripts} \
  && rm -rf /var/lib/apt/lists/* \
  && chown -R ${USER} /opt ${HOME}

USER root

# Install glibc and useful packages
RUN echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk --update add \
    bash \
    curl \
    ca-certificates \
    libstdc++ \
    glib \
    tini@testing \
    && curl "https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub" -o /etc/apk/keys/sgerrand.rsa.pub \
    && curl -L "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-2.23-r3.apk" -o glibc.apk \
    && apk --allow-untrusted add glibc.apk \
    && curl -L "https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-bin-2.23-r3.apk" -o glibc-bin.apk \
    && apk --allow-untrusted add glibc-bin.apk \
    && curl -L "https://github.com/andyshinn/alpine-pkg-glibc/releases/download/2.25-r0/glibc-i18n-2.25-r0.apk" -o glibc-i18n.apk \
    && apk add --allow-untrusted glibc-i18n.apk \
    && /usr/glibc-compat/bin/localedef -i en_US -f UTF-8 en_US.UTF-8 \
    && /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc/usr/lib \
    && rm -rf glibc*apk /var/cache/apk/*


# *********** Install Miniconda3 ********************
# **** Current Channels ***********
#- https://repo.anaconda.com/pkgs/main/linux-64
#- https://repo.anaconda.com/pkgs/main/noarch
#- https://repo.anaconda.com/pkgs/free/linux-64
#- https://repo.anaconda.com/pkgs/free/noarch
#- https://repo.anaconda.com/pkgs/r/linux-64
#- https://repo.anaconda.com/pkgs/r/noarch
# ** Conda Issue **
# https://github.com/ContinuumIO/anaconda-issues/issues/11148
ENV SSL_NO_VERIFY=1


RUN mkdir /home/${USER}/.conda \
  && cd /tmp \
  && wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/anaconda.sh \
  && /bin/bash ~/anaconda.sh -b -p /opt/conda \
  && rm ~/anaconda.sh \
  && conda config --system --prepend channels conda-forge \
  && conda install --quiet --yes conda-build \
  && conda install --quiet --yes \
    'python=3.7.5' \
    'conda=4.8.3' \
    'nbconvert=5.6.1' \
    'notebook=6.0.3' \
    'jupyterhub=1.1.0' \
    'jupyterlab=2.1.1' \
    'pandas=1.0.3' \
    'plotly=4.7.1' 
RUN conda update --all --quiet --yes \
  # *********** Installing Jupyter Extensions *****************
  && rm -rf $CONDA_DIR/share/jupyter/lab/staging \
  # *********** Clean *****************
  && npm cache clean --force \
  && conda clean -tipy \
  && conda build purge-all \
  && rm -rf /home/$JUPYTER_USER/.cache/yarn

# *********** Setting Environment Variables ***************
ENV GRAPHFRAMES_VERSION=0.7.0
ENV KAFKA_VERSION=2.4.0
ENV SCALA_VERSION=2.11
ENV SLF4J_API_VERSION=1.7.29
ENV LZ4_JAVA=1.6.0
ENV SNAPPY_JAVA=1.1.7.3
ENV ESHADOOP_VERSION=7.5.2
ENV ESHADOOP_DIR=${JUPYTER_DIR}/es-hadoop

# **** Current Channels ***********
#- https://repo.anaconda.com/pkgs/main/linux-64
#- https://repo.anaconda.com/pkgs/main/noarch
#- https://repo.anaconda.com/pkgs/free/linux-64
#- https://repo.anaconda.com/pkgs/free/noarch
#- https://repo.anaconda.com/pkgs/r/linux-64
#- https://repo.anaconda.com/pkgs/r/noarch
RUN mkdir -v ${ESHADOOP_DIR} \
  # *********** Install Jupyter Notebook & Extra Packages with Conda *************
  && conda install --quiet --yes \
    'altair=4.1.0' \
    's3fs=0.4.2' \
    'elasticsearch-dsl=7.0.0' \
    'matplotlib=3.2.1' \
    'networkx=2.4' \
    'nxviz=0.6.2' \
  && conda update --all --quiet --yes \
  # *********** Clean *****************
  && conda clean -tipy \
  && conda build purge-all \
  && rm -rf /home/$USER/.cache/yarn \
  # *********** Install Pip packages not availabe via conda ************
  && python3 -m pip install ksql==0.5.1.1 confluent-kafka==1.4.1 splunk-sdk==1.6.12 Kqlmagic==0.1.111.post15 neo4j==1.7.6 openhunt==1.6.5 pyarrow==0.17.0 msticpy==0.4.0 \
  # *********** Download ES-Hadoop ***************
  && wget https://artifacts.elastic.co/downloads/elasticsearch-hadoop/elasticsearch-hadoop-${ESHADOOP_VERSION}.zip -P ${ESHADOOP_DIR}/ \
  && unzip -j ${ESHADOOP_DIR}/*.zip -d ${ESHADOOP_DIR}/ \
  && rm ${ESHADOOP_DIR}/*.zip \
  # *********** Download Graphframes Jar ***************
  && wget http://dl.bintray.com/spark-packages/maven/graphframes/graphframes/${GRAPHFRAMES_VERSION}-spark2.4-s_2.11/graphframes-${GRAPHFRAMES_VERSION}-spark2.4-s_2.11.jar -P ${SPARK_HOME}/jars/ \
  && cp ${SPARK_HOME}/jars/graphframes* ${SPARK_HOME}/graphframes.zip \
  # *********** Download Extra Jars ***************
  && wget https://repo1.maven.org/maven2/org/apache/spark/spark-sql-kafka-0-10_${SCALA_VERSION}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_VERSION}-${SPARK_VERSION}.jar -P ${SPARK_HOME}/jars/ \
  && wget https://repo1.maven.org/maven2/org/apache/kafka/kafka-clients/${KAFKA_VERSION}/kafka-clients-${KAFKA_VERSION}.jar -P ${SPARK_HOME}/jars/ \
  && wget https://repo1.maven.org/maven2/org/slf4j/slf4j-api/${SLF4J_API_VERSION}/slf4j-api-${SLF4J_API_VERSION}.jar -P ${SPARK_HOME}/jars/ \
  && wget https://repo1.maven.org/maven2/org/spark-project/spark/unused/1.0.0/unused-1.0.0.jar -P ${SPARK_HOME}/jars/ \
  && wget https://repo1.maven.org/maven2/org/lz4/lz4-java/${LZ4_JAVA}/lz4-java-${LZ4_JAVA}.jar -P ${SPARK_HOME}/jars \
  && wget https://repo1.maven.org/maven2/org/xerial/snappy/snappy-java/${SNAPPY_JAVA}/snappy-java-${SNAPPY_JAVA}.jar -P ${SPARK_HOME}/jars/


USER root

# *********** Setting Environment Variables ***************
ENV POSTGRESQL_VERSION=42.2.12

# ********** Installing additional libraries **************
RUN mkdir /opt/jupyter/notebooks/datasets \
    && apk update && apk add postgresql postgresql-contrib \
    && rm -rf /var/lib/apt/lists/* \
    && pip install timesketch-api-client \
    # ********** Download Postgresql JAR *****************
    && wget https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_VERSION}.jar -P /opt/jupyter/spark/jars/

# *********** Adding HELK scripts and files to Container ***************
COPY notebooks/demos ${JUPYTER_DIR}/notebooks/demos
COPY notebooks/tutorials ${JUPYTER_DIR}/notebooks/tutorials
COPY notebooks/sigma ${JUPYTER_DIR}/notebooks/sigma
COPY spark/* ${SPARK_HOME}/conf/
COPY scripts/* ${JUPYTER_DIR}/scripts/

RUN chown -R ${USER} ${JUPYTER_DIR} ${HOME} ${SPARK_HOME} \
    && chown ${USER} /run/postgresql

WORKDIR ${HOME}
ENTRYPOINT ["/opt/jupyter/scripts/jupyter-entrypoint.sh"]
CMD ["/opt/jupyter/scripts/jupyter-cmd.sh"]

USER ${USER}
