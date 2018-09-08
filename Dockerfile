FROM ubuntu:bionic-20180724.1

LABEL maintainer="Simon Frost <sdwfrost@gmail.com>"

USER root

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get -yq dist-upgrade\
    && apt-get install -yq --no-install-recommends \
    autoconf \
    automake \
    ant \
    apt-file \
    apt-utils \
    build-essential \
    bzip2 \
    ca-certificates \
    clang-6.0 \
    cmake \
    curl \
    darcs \
    debhelper \
    devscripts \
    dirmngr \
    ed \
    fonts-liberation \
    fonts-dejavu \
    gcc \
    gfortran \
    ghostscript \
    ginac-tools \
    git \
    gnuplot \
    gnupg \
    gnupg-agent \
    gzip \
    libffi-dev \
    libgmp-dev \
    libgsl0-dev \
    libtinfo-dev \
    libzmq3-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libmagic-dev \
    libblas-dev \
    liblapack-dev \
    libboost-all-dev \
    libcln-dev \
    libcurl4-gnutls-dev \
    libgeos-dev \
    libginac-dev \
    libginac6 \
    libgit2-dev \
    libgl1-mesa-glx \
    libgs-dev \
    libjsoncpp-dev \
    libnetcdf-dev \
    libqrupdate-dev \
    libqt5widgets5 \
    libsm6 \
    libssl-dev \
    libudunits2-0 \
    libxext-dev \
    libxml2-dev \
    libxrender1 \
    libxt6 \
    libzmqpp-dev \
    lmodern \
    locales \
    mercurial \
    netcat \
    openjdk-8-jdk \
    openjdk-8-jre \
    pandoc \
    pbuilder \
    pkg-config \
    python3-dev \
    rsync \
    sbcl \
    software-properties-common \
    sudo \
    #texlive-fonts-extra \
    #texlive-fonts-recommended \
    #texlive-generic-recommended \
    #texlive-latex-base \
    #texlive-latex-extra \
    #texlive-xetex \
    tzdata \
    ubuntu-dev-tools \
    unzip \
    wget \
    xz-utils \
    zlib1g-dev \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
    apt-get install -yq --no-install-recommends \
    nodejs \
    nodejs-legacy \
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

# Show Julia where libraries are \
RUN mkdir /etc/julia && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown $NB_USER $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR

RUN add-apt-repository ppa:marutter/rrutter && \
    apt-get update && \
    apt-get install -yq \
    r-base r-base-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Yacas
RUN cd /tmp && \
    git clone https://github.com/grzegorzmazur/yacas && \
    cd yacas && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_CYACAS_GUI=0 -DENABLE_CYACAS_KERNEL=1  ..
    make && \
    make install && \
    cd /tmp && \
    rm -rf yacas

RUN R -e "setRepositories(ind=1:2);install.packages(c(\
    'adaptivetau', \
    'boot', \
    'cOde', \
    'deSolve',\
    'devtools', \
    'ddeSolve', \
    'feather', \
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
    'reticulate', \
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
RUN R -e "devtools::install_github('mrc-ide/odin',upgrade=FALSE)" && \
    R -e "devtools::install_github('ggrothendieck/ryacas')"

# Add Julia packages.
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'Pkg.init()' && \
    julia -e 'Pkg.update()' && \
    julia -e 'Pkg.add("DataFrames")' && \
    julia -e 'Pkg.add("Feather")' && \
    julia -e 'Pkg.add("Gadfly")' && \
    julia -e 'Pkg.add("GR")' && \
    julia -e 'Pkg.add("Plots")' && \
    julia -e 'Pkg.add("IJulia")' && \
    julia -e 'Pkg.add("DifferentialEquations")' && \
    julia -e 'Pkg.add("NamedArrays")' && \
    julia -e 'Pkg.add("RandomNumbers")' && \
    julia -e 'Pkg.add("Gillespie")' && \
    julia -e 'Pkg.add("PyCall")' && \
    julia -e 'Pkg.add("PyPlot")' && \
    julia -e 'Pkg.add("PlotlyJS")' && \
    julia -e 'Pkg.add("SymPy")' && \
    # Precompile Julia packages \
    julia -e 'using DataFrames' && \
    julia -e 'using Feather' && \
    julia -e 'using Gadfly' && \
    julia -e 'using GR' && \
    julia -e 'using Plots' && \
    julia -e 'using IJulia' && \
    julia -e 'using DifferentialEquations' && \
    julia -e 'using NamedArrays' && \
    julia -e 'using RandomNumbers' && \
    julia -e 'using Gillespie' && \
    julia -e 'using PyCall' && \
    julia -e 'using PyPlot' && \
    julia -e 'using SymPy' && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* /usr/local/share/jupyter/kernels/ && \
    chmod -R go+rx /usr/local/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR /usr/local/share/jupyter

# Add gnuplot kernel - gnuplot 5.2.3 already installed above
RUN pip install gnuplot_kernel && \
    python3 -m gnuplot_kernel install

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
RUN yes 'y' | nimble install --verbose \
    arraymancer \
    gnuplot \
    inim \
    neo \
    nimdata \
    plotly \
    random

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

# Octave
RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    octave && \
    octave --eval 'pkg install -forge dataframe' && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*    
RUN pip install octave_kernel feather-format

# XPP
ENV XPP_DIR=/opt/xppaut
RUN mkdir /opt/xppaut && \
    cd /tmp && \
    wget http://www.math.pitt.edu/~bard/bardware/xppaut_latest.tar.gz && \
    tar xvf xppaut_latest.tar.gz -C /opt/xppaut && \
    cd /opt/xppaut && \
    make && \
    ln -fs /opt/xppaut/xppaut /usr/local/bin/xppaut && \
    rm /tmp/xppaut_latest.tar.gz && \
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

# Maxima
RUN cd /tmp && \
    git clone https://github.com/andrejv/maxima && \
    cd maxima && \
    sh bootstrap && \
    ./configure --enable-sbcl && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf maxima
RUN mkdir /opt/quicklisp && \
    cd /tmp && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --non-interactive --eval '(quicklisp-quickstart:install :path "/opt/quicklisp/")' && \
    yes '' | sbcl --load /opt/quicklisp/setup.lisp --non-interactive --eval '(ql:add-to-init-file)' && \
    rm quicklisp.lisp && \
    fix-permissions /opt/quicklisp
RUN cd /opt && \
    git clone https://github.com/robert-dodier/maxima-jupyter && \
    cd maxima-jupyter && \
    python3 ./install-maxima-jupyter.py --root=/opt/maxima-jupyter && \
    fix-permissions /opt/maxima-jupyter /usr/local/share/jupyter/kernels

# JVM languages
RUN update-java-alternatives --set /usr/lib/jvm/java-1.8.0-openjdk-amd64
## kotlin
RUN cd /opt && \
    wget https://github.com/JetBrains/kotlin/releases/download/v1.3-M2/kotlin-compiler-1.3-M2.zip && \
    unzip kotlin-compiler-1.3-M2.zip && \
    rm kotlin-compiler-1.3-M2.zip && \
    cd /opt/kotlinc/bin && \
    chmod +x kotli* && \
    fix-permissions /opt/kotlinc
ENV PATH=/opt/kotlinc/bin:$PATH
#RUN cd /tmp && \
#    git clone https://github.com/ligee/kotlin-jupyter && \
#    cd kotlin-jupyter && \
#    ./gradlew install -PinstallPath=/usr/local/share/jupyter/kernels/kotlin/ && \
#    cd /tmp && \
#    rm -rf kotlin-jupyter

## Scala
RUN cd /tmp && \
    wget www.scala-lang.org/files/archive/scala-2.13.0-M5.deb && \
    dpkg -i scala-2.13.0-M5.deb && \
    rm scala-2.13.0-M5.deb
RUN cd /tmp && \
    git clone https://github.com/jupyter-scala/jupyter-scala && \
    cd jupyter-scala && \
    ./jupyter-scala && \
    cd /tmp && \
    rm -rf jupyter-scala

## Clojure
RUN cd /tmp && \
    curl -O https://download.clojure.org/install/linux-install-1.9.0.391.sh && \
    chmod +x linux-install-1.9.0.391.sh && \
    yes 'y' | bash ./linux-install-1.9.0.391.sh && \
    rm linux-install-1.9.0.391.sh
#RUN cd /tmp && \
#    git clone https://github.com/clojupyter/clojupyter && \
#    cd clojupyter && \
#    make && \
#    make install && \
#    mv ${HOME}/.local/share/jupyter/kernels/clojupyter/ /usr/local/share/jupyter/kernels/clojupyter/ && \
#    fix-permissions /usr/local/share/jupyter/kernels ${HOME}
    
#RUN cd /tmp && \
#    git clone https://github.com/twosigma/beakerx && \
#    cd beakerx/beakerx && \
#    pip install -e . --verbose && \
#    beakerx install && \
#    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
#    cd /tmp/beakerx/js/lab && \
#    jupyter labextension install . && \
#    cd /tmp && \
#    rm -rf beakerx
RUN pip install beakerx && \
    beakerx install && \
    jupyter nbextension enable beakerx --py --sys-prefix && \
    rm -rf /home/$NB_USER/.cache/pip && \
    fix-permissions /home/$NB_USER /usr/share/jupyter/kernels
# Remove non-working/defunct kernels
RUN rm -rf /usr/share/jupyter/kernels/groovy && \
    rm -rf /usr/share/jupyter/kernels/sql

# SBCL
RUN cd /opt && \
    git clone https://github.com/fredokun/cl-jupyter && \
    cd cl-jupyter && \
    python3 ./install-cl-jupyter.py && \
    sbcl --load ./cl-jupyter.lisp

# OCAML
RUN apt update && \
    apt-get install -yq \
    opam \
    ocaml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
RUN yes 'y' | opam init && \
    eval `opam config env`
RUN yes 'Y' | opam install jupyter && \
    yes 'Y' | opam install jupyter-archimedes  && \
    yes 'Y' | opam install odepack  && \
    jupyter kernelspec install --name ocaml-jupyter "$(opam config var share)/jupyter"

# .Net
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
    apt update && \
    apt-get install -yq --no-install-recommends mono-complete \
    mono-dbg \
    mono-csharp-shell \
    mono-runtime-dbg \
    fsharp && \
    mozroots --import --machine --sync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb && \
    yes 'y' | dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -yq --no-install-recommends \
    apt-transport-https \
    dotnet-sdk-2.1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#RUN cd /tmp && \
#    git clone --recursive https://github.com/zabirauf/icsharp.git && \
#    cd icsharp && \
#    bash ./build.sh && \
#    jupyter-kernelspec install kernel-spec && \
#    cd /tmp && \
#    rm -rf icsharp

RUN cd /opt && \
    mkdir ifsharp && \
    cd ifsharp && \
    wget https://github.com/fsprojects/IfSharp/releases/download/v3.0.0/IfSharp.v3.0.0.zip && \
    unzip IfSharp.v3.0.0.zip && \
    mono ifsharp.exe && \
    mv ${HOME}/.local/share/jupyter/kernels/ifsharp/ /usr/local/share/jupyter/kernels/ifsharp/ && \
    fix-permissions /usr/local/share/jupyter/kernels ${HOME} /opt/ifsharp

# Go
RUN cd /tmp && \
    wget https://dl.google.com/go/go1.11.linux-amd64.tar.gz && \
    mkdir /opt/go && \
    tar xvf go1.11.linux-amd64.tar.gz -C /opt/go --strip-components=1 && \
    rm go1.11.linux-amd64.tar.gz && \
    fix-permissions /opt/go
ENV PATH=/opt/go/bin:$PATH
RUN cd /opt && \
    go get -u github.com/gopherdata/gophernotes && \
    git clone https://github.com/gopherdata/gophernotes && \
    mkdir -p /usr/local/share/jupyter/kernels/gophernotes && \
    cp /opt/gophernotes/kernel/* /usr/local/share/jupyter/kernels/gophernotes && \
    fix-permissions /opt/gophernotes /usr/local/share/jupyter/kernels/
ENV PATH=/opt/gophernotes:$PATH

# C
RUN pip install cffi_magic \
    jupyter-c-kernel && \
    install_c_kernel && \
    rm -rf /home/$NB_USER/.cache/pip && \    
    fix-permissions /usr/local/share/jupyter/kernels ${HOME}

# Fortran
RUN cd /tmp && \
    git clone https://github.com/ZedThree/jupyter-fortran-kernel && \
    pip install -e jupyter-fortran-kernel && \
    cd jupyter-fortran-kernel && \
    jupyter-kernelspec install fortran_spec/ && \
    cd /tmp && \
    rm -rf jupyter-fortran-kernel && \
    rm -rf /home/$NB_USER/.cache/pip && \    
    fix-permissions /usr/local/share/jupyter/kernels ${HOME}

# C++
# cling
RUN cd /opt && \
    mkdir /opt/cling && \
    mkdir /opt/cling-build && \
    wget https://github.com/vgvassilev/cling/archive/v0.5.tar.gz && \
    tar xvf v0.5.tar.gz -C /opt/cling-build --strip-components=1 && \
    cd /opt/cling-build/tools/packaging && \
    chmod +x cpt.py && \
    ./cpt.py --create-dev-env Release --with-workdir=/opt/cling-build && \
    cp -R /opt/cling-build/cling-Ubuntu-18.04-x86_64*/ /opt/cling/ && \
    fix-permissions ${HOME} /opt/cling && \
    rm -rf /opt/cling-build
ENV PATH=/opt/cling/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/cling/lib:$LD_LIBRARY_PATH

# Xeus
RUN cd /tmp && \
    git clone https://github.com/zeromq/libzmq && \
    cd libzmq && \
    mkdir build && \
    cd build && \
    cmake -DWITH_PERF_TOOL=OFF -DZMQ_BUILD_TESTS=OFF -DENABLE_CPACK=OFF -DCMAKE_BUILD_TYPE=Release ..  && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf libzmq

RUN cd /tmp && \
    git clone https://github.com/zeromq/cppzmq && \
    cd cppzmq && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release .. && \
    make install && \
    cd /tmp && \
    rm -rf cppzmq

RUN cd /tmp && \
    git clone https://github.com/weidai11/cryptopp && \
    cd cryptopp && \
    git submodule add https://github.com/noloader/cryptopp-cmake.git cmake && \
    git submodule update --remote && \
    cp "$PWD/cmake/cryptopp-config.cmake" "$PWD" && \
    cp "$PWD/cmake/CMakeLists.txt" "$PWD" && \
    mkdir build && \
    cd build && \
    cmake -D BUILD_SHARED=OFF -D BUILD_TESTING=OFF -D CMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf cryptopp

RUN cd /tmp && \
    git clone https://github.com/nlohmann/json && \
    cd json && \
    cmake . && \
    make && \
    make install && \
    cd /tmp && \
    rm -rf json

RUN cd /tmp && \
    git clone https://github.com/QuantStack/xtl && \
    cd xtl && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release .. && \
    make install && \
    cd /tmp && \
    rm -rf xtl

RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
    uuid-dev \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#RUN cd /tmp && \
#    git clone https://github.com/QuantStack/xeus && \
#    cd xeus && \
#    mkdir build && \
#    cd build && \
#    cmake -D BUILD_EXAMPLES=ON -D CMAKE_BUILD_TYPE=Release .. && \
#    make && \
#    make install && \
#    cd /tmp && \
#    rm -rf xeus

#RUN cd /tmp && \
#    git clone https://github.com/QuantStack/xeus-cling && \
#    cd xeus-cling && \
#    mkdir build && \
#    cd build && \
#    cmake -DCMAKE_INSTALL_PREFIX=/opt/cling -DCMAKE_INSTALL_LIBDIR=/opt/cling/lib .. && \
#    make && \
#    make install && \
#    cd /tmp && \
#    rm -rf xeus-cling && \
#    fix-permissions /opt/cling

# Haskell
RUN mkdir ${HOME}/.stack && \
    fix-permissions ${HOME}
RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    haskell-stack && \
    stack upgrade && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*  && \
    fix-permissions ${HOME}
ENV PATH=/home/jovyan/.local/bin:$PATH
RUN cd /tmp && \
    git clone https://github.com/gibiansky/IHaskell && \
    cd IHaskell && \
    pip install jupyter \
    jupyter_nbextensions_configurator \
    jupyter_contrib_nbextensions \
    ipykernel \
    ipywidgets \
    jupyter-client \
    jupyter-console \
    jupyter-core && \
    rm -rf /home/$NB_USER/.cache/pip && \
    fix-permissions /home/$NB_USER
    
# RUN cd /tmp/IHaskell && \
#    mv stack.yaml stack.yaml.bak && \
#    mv stack-8.4.yaml stack.yaml && \
#    stack upgrade && \
#    # stack install gtk2hs-buildtools && \
#    stack install --fast && \
#    ihaskell install --stack && \
#    jupyter labextension install ihaskell_labextension && \
#    cd /tmp && \
#    rm -rf IHaskell && \
#    fix-permissions ${HOME}

# Libbi 
RUN cd /tmp && \
    wget https://github.com/thrust/thrust/releases/download/1.8.2/thrust-1.8.2.zip && \
    unzip thrust-1.8.2.zip && \
    mv thrust /usr/local/include && \
    rm thrust-1.8.2.zip && \
    fix-permissions /usr/local/include
RUN cd /opt && \
    git clone https://github.com/lawmurray/LibBi && \
    cd LibBi && \
    PERL_MM_USE_DEFAULT=1  cpan . && \
    fix-permissions /opt/LibBi
ENV PATH=/opt/LibBi/script:$PATH
RUN R -e "install.packages('rbi')"

# PARI-GP
RUN apt-get update && apt-get -yq dist-upgrade && \
    apt-get install -yq --no-install-recommends \
    pari-gp \
    pari-gp2c && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* 
RUN pip install pari_jupyter

# Lua
RUN cd /opt && \
    wget http://ulua.io/download/ulua~latest.zip && \
    unzip ulua~latest.zip && \
    rm ulua~latest.zip && \
    fix-permissions /opt/ulua
ENV BIT=64 PATH=/opt/ulua:$PATH
RUN cd /opt/ulua/bin && \
    yes 'y' | ./upkg add sci && \
    yes 'y' | ./upkg add sci-lang && \
    fix-permissions /opt/ulua

# SOS
RUN pip install sos sos-notebook && \
    python3 -m sos_notebook.install

# Node
RUN mkdir /opt/npm && \
    echo 'prefix=/opt/npm' >> ${HOME}/.npmrc 
ENV PATH=/opt/npm/bin:$PATH
ENV NODE_PATH=/opt/npm/lib/node_modules
RUN fix-permissions /opt/npm

# Rust and Rusti
#RUN cd /tmp && \
#    curl https://sh.rustup.rs -sSf > /usr/local/bin/rustup && \
#    chmod +x /usr/local/bin/rustup && \
#    fix-permissions /usr/local/bin && \
#    rustup install nightly-2016-08-01 -y && \
#    cargo install --git https://github.com/murarth/rusti

# Make sure the contents of our repo are in ${HOME}
COPY . ${HOME}
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}

RUN npm install -g ijavascript \
    plotly-notebook-js \
    ode-rk4 && \
    ijsinstall

USER root
RUN fix-permissions /opt/npm ${HOME} /usr/local/share/jupyter/kernels

USER ${NB_USER}
RUN cd ${HOME} && \
    rm fix-permissions && \
    rm choosenim.sh
