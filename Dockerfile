#y Download base image ubuntu 18.04
FROM ubuntu:18.04

# Maintainer label
LABEL maintainer="Mattijs Jonker <m.jonker@utwente.nl>"

USER root

# Set LANG
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Update Ubuntu Software repository
RUN apt-get update

# Install packages from Ubuntu repository
RUN apt-get install --no-install-recommends -y \
    sudo wget locales ca-certificates \
    krb5-user \
    openjdk-8-jre-headless ca-certificates-java
# Clean apt
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set JAVA_HOME (to apt installation location)
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/jre

# Generate loacle
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Spark installation
ENV SPARK_VERSION 2.4.3
ENV SPARK_HADOOP_COMPATIBILITY 2.7
ENV OPENINTEL_SCALA_VERSION 2.11
ENV OPENINTEL_SPARK_VERSION 2.4.0
RUN cd /tmp && \
    wget -q https://www-eu.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_COMPATIBILITY}.tgz && \
    wget -q https://www-eu.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_COMPATIBILITY}.tgz.sha512 && \
    tar xzf spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_COMPATIBILITY}.tgz -C /usr/local --owner root --group root --no-same-owner \
    && rm spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_COMPATIBILITY}.tgz
RUN cd /usr/local && ln -s spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_COMPATIBILITY} spark
RUN cd /usr/local/spark/jars/ && wget -q https://repo.maven.apache.org/maven2/org/apache/spark/spark-avro_${OPENINTEL_SCALA_VERSION}/${OPENINTEL_SPARK_VERSION}/spark-avro_${OPENINTEL_SCALA_VERSION}-${OPENINTEL_SPARK_VERSION}.jar
# Set Spark lib location
ENV SPARK_HOME /usr/local/spark

# Hadoop installation
ENV HADOOP_VERSION 2.7.7
RUN cd /tmp && \
    wget -q https://www-eu.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    wget -q https://www-eu.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.mds && \
    tar xzf hadoop-${HADOOP_VERSION}.tar.gz -C /usr/local --owner root --group root --no-same-owner \
    && rm hadoop-${HADOOP_VERSION}.tar.gz
RUN cd /usr/local && ln -s hadoop-${HADOOP_VERSION} hadoop
# Add Hadoop bin to path
ENV PATH /usr/local/hadoop/bin:$PATH
# Set Hadoop conf dir
ENV HADOOP_CONF_DIR /usr/local/hadoop/etc/hadoop

# Anaconda3 installation
ENV MINICONDA_VERSION 4.7.10
RUN cd /tmp && \
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -b -p /opt/miniconda3 && \
    ln -s /opt/miniconda3/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/miniconda3/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc \
    && rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh
# Add conda bin to path
ENV PATH /opt/miniconda3/bin:$PATH

# Miniconda3 packages
RUN conda install --yes --quiet \
    -c conda-forge -c anaconda \
    'jupyterlab' 'findspark' 'libhdfs3' 'pyarrow' \
    'pyspark==2.4.0' \
    && conda clean --all -f -y

# Set PySpark location
ENV PYSPARK_PYTHON /opt/miniconda3/bin/python

# Set pyarrow ENV
ENV ARROW_LIBHDFS_DIR /usr/local/hadoop/lib/native

# pip packages
RUN pip install \
    fastavro

# Add non-root user that will rune notebook
ARG NB_USER="openintel"
ARG NB_UID="1000"
ARG NB_GID="1000"
RUN groupadd -g $NB_GID $NB_USER && \
    useradd -m -s /bin/bash -N -u $NB_UID -g $NB_GID $NB_USER
# Give passwordless sudo privileges
RUN echo "${NB_USER} ALL=NOPASSWD: ALL" >> /etc/sudoers

# Init conda environment for $NB_USER
user $NB_USER
RUN echo ". /opt/miniconda3/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc

# Jupyter configuration and kernel setup
RUN mkdir /home/${NB_USER}/.jupyter/
COPY jupyter_notebook_config.py /home/${NB_USER}/.jupyter/
RUN ipython kernel install --user

# Ports to expose
# Jupyter: 8888/tcp
EXPOSE 8888/tcp

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["jupyter lab"]
