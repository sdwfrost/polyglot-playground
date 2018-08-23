FROM ubuntu:bionic-20180724.1

LABEL maintainer="Simon Frost <sdwfrost@gmail.com>"

USER root

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -yq dist-upgrade\
    && apt-get install -yq --no-install-recommends \
    wget \
    bzip2 \
    ca-certificates \
    curl \
    sudo \
    locales \
    fonts-liberation \
    build-essential \
    fonts-dejavu \
    gcc \
    gfortran \
    ghostscript \
    ginac-tools \
    git \
    gnuplot \
    gnupg-agent \
    gzip \
    libboost-all-dev \
    libcln-dev \
    libgeos-dev \
    libginac-dev \
    libginac6 \
    libgit2-dev \
    libgl1-mesa-glx \
    libgs-dev \
    libjsoncpp-dev \
    libqt5widgets5 \
    libsm6 \
    libxext-dev \
    libxrender1 \
    libxt6 \
    libzmqpp-dev \
    lmodern \
    netcat \
    pandoc \
    pkg-config \
    python3-dev \
    rsync \
    sbcl \
    software-properties-common \
    texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    tzdata \
    unzip \
    zlib1g-dev \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -yq --no-install-recommends \
    nodejs \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN ln -s /bin/tar /bin/gtar

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV HOME=/home/$NB_USER

ADD fix-permissions /usr/local/bin/fix-permissions
RUN chmod +x /usr/local/bin/fix-permissions

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME

EXPOSE 8888
WORKDIR $HOME

# Install pip
RUN cd /tmp && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py && \
    rm get-pip.py && \
    rm -rf /home/$NB_USER/.cache/pip && \
    fix-permissions /home/$NB_USER

# Install Tini

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/local/bin/tini
RUN chmod +x /usr/local/bin/tini
ENV PATH=/usr/local/bin:$PATH
# Configure container startup
ENTRYPOINT ["tini", "-g", "--"]

RUN pip install \
    notebook \
    jupyterhub \
    jupyterlab && \
    jupyter labextension install @jupyterlab/hub-extension && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf /home/$NB_USER/.cache/pip && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions /home/$NB_USER

RUN pip install \
    gr \
    ipywidgets \
    pandas \
    numexpr \
    matplotlib \
    scipy \
    sympy \
    seaborn \
    cython \
    papermill \
    nteract_on_jupyter \
    numba  && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install jupyterlab_bokeh && \
    npm cache clean --force && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions /home/$NB_USER

# Install facets which does not have a pip or conda package at the moment
RUN cd /tmp && \
    git clone https://github.com/PAIR-code/facets.git && \
    cd facets && \
    jupyter nbextension install facets-dist/ --sys-prefix && \
    cd && \
    rm -rf /tmp/facets && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
# RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
#    fix-permissions /home/$NB_USER

# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=0.6.4

RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    # echo "dc6ec0b13551ce78083a5849268b20684421d46a7ec46b17ec1fab88a5078580 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia

# Show Julia where conda libraries are \
 RUN mkdir /etc/julia && \
#    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

RUN add-apt-repository ppa:marutter/rrutter && \
    apt-get update && \
    apt-get install -yq \
    libssl-dev \
    libcurl4-gnutls-dev \
    r-base r-base-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c(\
    'adaptivetau', \
    'boot', \
    'cOde', \
    'deSolve',\
    'devtools', \
    'ddeSolve',\
    'GillespieSSA', \
    'git2r', \
    'ggplot2', \
    'FME', \
    'KernSmooth', \
    'magrittr', \
    'odeintr', \
    'PBSddesolve', \
    'plotly', \
    'pomp', \
    'pracma', \
    'ReacTran', \
    'rmarkdown', \
    'rodeo', \
    'Rcpp', \
    'rpgm', \
    'simecol', \
    'spatial'), dependencies=TRUE, clean=TRUE, repos='https://cran.microsoft.com/snapshot/2018-08-14')"
RUN R -e "devtools::install_github('IRkernel/IRkernel')" && \
    R -e "IRkernel::installspec()" && \
    mv $HOME/.local/share/jupyter/kernels/ir* /usr/local/share/jupyter/kernels/ && \
    chmod -R go+rx /usr/local/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions /usr/local/share/jupyter
RUN pip install rpy2
RUN R -e "devtools::install_github('mrc-ide/odin',upgrade=FALSE)"

# Add Julia packages.
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'Pkg.init()' && \
    julia -e 'Pkg.update()' && \
    julia -e 'Pkg.add("Gadfly")' && \
    julia -e 'Pkg.add("GR")' && \
    julia -e 'Pkg.add("Plots")' && \
    julia -e 'Pkg.add("IJulia")' && \
    julia -e 'Pkg.add("DifferentialEquations")' && \
    julia -e 'Pkg.add("RandomNumbers")' && \
    julia -e 'Pkg.add("Gillespie")' && \
    julia -e 'Pkg.add("PyCall")' && \
    julia -e 'Pkg.add("PyPlot")' && \
    julia -e 'Pkg.add("PlotlyJS")' && \
    # Precompile Julia packages \
    julia -e 'using Gadfly' && \
    julia -e 'using GR' && \
    julia -e 'using Plots' && \
    julia -e 'using IJulia' && \
    julia -e 'using DifferentialEquations' && \
    julia -e 'using RandomNumbers' && \
    julia -e 'using Gillespie' && \
    julia -e 'using PyCall' && \
    julia -e 'using PyPlot' && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* /usr/local/share/jupyter/kernels/ && \
    chmod -R go+rx /usr/local/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR /usr/local/share/jupyter

# Add gnuplot kernel - gnuplot 5.2.3 already installed above
RUN pip install gnuplot_kernel && \
    python3 -m gnuplot_kernel install

# CFFI
RUN pip install cffi_magic

# GR
RUN cd /tmp && \
    wget https://gr-framework.org/downloads/gr-latest-Ubuntu-x86_64.tar.gz && \
    tar xvf gr-latest-Ubuntu-x86_64.tar.gz -C /usr/local --strip-components=1 && \
    rm gr-latest-Ubuntu-x86_64.tar.gz && \
    fix-permissions /usr/local

# Nim
ENV NIMBLE_DIR=/opt/nimble
RUN curl https://nim-lang.org/choosenim/init.sh -sSf > choosenim.sh && \
    chmod +x ./choosenim.sh && \
    ./choosenim.sh -y && \
    mkdir /opt/nimble && \
    mv /home/jovyan/.nimble/bin /opt/nimble
ENV PATH=$NIMBLE_DIR/bin:$PATH
RUN fix-permissions $NIMBLE_DIR

# Scilab
ENV SCILAB_VERSION=6.0.1
ENV SCILAB_EXECUTABLE=/usr/local/bin/scilab-adv-cli
RUN mkdir /opt/scilab-${SCILAB_VERSION} && \
    cd /tmp && \
    wget http://www.scilab.org/download/6.0.1/scilab-${SCILAB_VERSION}.bin.linux-x86_64.tar.gz && \
    tar xvf scilab-${SCILAB_VERSION}.bin.linux-x86_64.tar.gz -C /opt/scilab-${SCILAB_VERSION} --strip-components=1 && \
    rm /tmp/scilab-${SCILAB_VERSION}.bin.linux-x86_64.tar.gz && \
    ln -fs /opt/scilab-${SCILAB_VERSION}/bin/scilab-adv-cli /usr/local/bin/scilab-adv-cli && \
    ln -fs /opt/scilab-${SCILAB_VERSION}/bin/scilab-cli /usr/local/bin/scilab-cli && \
    pip install scilab_kernel

RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    octave && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*    
RUN pip install octave_kernel

# XPP
ENV XPP_DIR=/opt/xppaut
RUN mkdir /opt/xppaut && \
    cd /tmp && \
    wget http://www.math.pitt.edu/~bard/bardware/xppaut_latest.tar.gz && \
    tar xvf xppaut_latest.tar.gz -C /opt/xppaut --strip-components=1 && \
    cd /opt/xppaut && \
    make && \
    ln -fs /opt/xppaut/xppaut /usr/local/bin/xppaut && \
    rm /tmpxppaut_latest.tar.gz && \
    fix-permissions $XPP_DIR /usr/local/bin

# VFGEN
# First needs MiniXML
RUN cd /tmp && \
    mkdir /tmp/mxml && \
    wget https://github.com/michaelrsweet/mxml/releases/download/v2.11/mxml-2.11.tar.gz && \
    tar xvf mxml-2.11.tar.gz -C /tmp/mxml && \
    cd /tmp/mxml && \
    ./configure && \
    make && \
    make install && \
    cd /tmp && \
    rm mxml-2.11.tar.gz && \
    rm -rf /tmp/mxml
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

RUN mkdir /opt/vfgen && \
    cd /tmp && \
    git clone https://github.com/WarrenWeckesser/vfgen && \
    cd vfgen/src && \
    make -f Makefile.vfgen && \
    cp ./vfgen /opt/vfgen && \
    cd /tmp && \
    rm -rf vfgen && \
    ln -fs /opt/vfgen/vfgen /usr/local/bin/vfgen

# RUN cd ${HOME} && \
#    npm install ijavascript && \
#    rsync ${HOME}/node_modules/ /usr/lib/node_modules/ && \
#    fix-permissions /usr/lib/node_modules && \
#    ijsinstall

# Make sure the contents of our repo are in ${HOME}
COPY . ${HOME}
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}
