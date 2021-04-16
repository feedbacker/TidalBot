FROM phusion/baseimage:master

# == define ENV_VARS ===========================================================
ENV LANG C.UTF-8
ENV HOME /root

# == install some packs ========================================================
# Ref: https://github.com/ikag/docker-images/blob/master/supercollider/Dockerfile
# Ref: https://github.com/lvm/tida1vm/blob/0.9/Dockerfile
# Ref: https://github.com/maxhawkins/sc_radio/blob/master/Dockerfile
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    supervisor \
    autoconf \
    automake \
    libtool \
    build-essential \
    libsndfile1-dev \
    libasound2-dev \
    libavahi-client-dev \
    libgmp3-dev \
    libicu-dev \
    libreadline6-dev \
    libfftw3-dev \
    libxt-dev \
    libudev-dev \
    git \
    wget \
    ca-certificates \
    cmake \
    jackd2 \
    libjack-jackd2-dev \
    ffmpeg \
    haskell-mode \
    zlib1g-dev \
    liblo7

# == deal with nodejs ==========================================================
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g node-gyp

# == install stack =============================================================
RUN curl -sL https://get.haskellstack.org/ | bash -
RUN stack update

# == bye apt ===================================================================
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# == build SuperCollider =======================================================
# Ref: https://github.com/ikag/docker-images/blob/master/supercollider/Dockerfile
# Ref: https://github.com/supercollider/supercollider/wiki/Installing-SuperCollider-from-source-on-Ubuntu
# Ref: https://github.com/supercollider/sc3-plugins
WORKDIR $HOME
RUN git clone --depth=1 -b Version-3.11.0 --recursive https://github.com/supercollider/supercollider.git
WORKDIR $HOME/supercollider
RUN git submodule update --init
RUN mkdir -p $HOME/supercollider/build
WORKDIR $HOME/supercollider/build
RUN cmake -DCMAKE_BUILD_TYPE="Release" -DBUILD_TESTING=OFF -DSUPERNOVA=OFF -DNATIVE=OFF -DSC_WII=OFF -DSC_QT=OFF -DSC_ED=OFF -DSC_EL=OFF -DSC_VIM=OFF ..
RUN make -j4 && make install
RUN ldconfig
WORKDIR $HOME/supercollider
RUN cp SCClassLibrary/Common/Core/Model.sc /usr/local/share/SuperCollider/SCClassLibrary/Common/Core/
RUN rm -f /usr/local/share/SuperCollider/SCClassLibrary/deprecated/3.7/deprecated-3.7.sc

WORKDIR $HOME
RUN git clone --recursive https://github.com/supercollider/sc3-plugins.git
WORKDIR $HOME/sc3-plugins
RUN git submodule update --init
RUN mkdir -p $HOME/sc3-plugins/build
WORKDIR $HOME/sc3-plugins/build
RUN cmake -DCMAKE_BUILD_TYPE="Release" -DSC_PATH=$HOME/supercollider ..
RUN cmake --build . --config Release --target install
WORKDIR $HOME
RUN rm -rf sc3-plugins supercollider

# == pull SuperDirt and its samples ============================================
RUN echo 'include( "https://github.com/FMS-Cat/Dirt-Samples" );' | sclang
RUN echo 'include( "SuperDirt" );' | sclang

# == setup node app ============================================================
ADD ./home/app/package.json $HOME/app/package.json
RUN npm i

# == setup stack, install Tidal ================================================
WORKDIR $HOME/app
RUN stack setup
RUN stack install tidal-1.7.3

# == download BootTidal ========================================================
RUN curl -sL https://raw.githubusercontent.com/tidalcycles/atom-tidalcycles/ab71768ff27bc427abab17977fc465d80041fdc2/lib/BootTidal.hs > $HOME/app/BootTidal.hs

# == send some files ===========================================================
ADD ./home $HOME

# == build jack-audio ==========================================================
WORKDIR $HOME/jack-audio
RUN npm i
RUN node-gyp configure
RUN node-gyp build
RUN mv ./build/Release/jack-audio.node $HOME/app
WORKDIR $HOME
RUN rm -rf jack-audio

# == I think it's done =========================================================
CMD supervisord -c supervisor.conf
