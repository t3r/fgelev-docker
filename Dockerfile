#Build environment for simgear
FROM debian:bookworm AS simgear-builder

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  git \
  build-essential \
  freeglut3-dev \
  libboost-dev \
  libcurl4-openssl-dev \
  liblzma-dev \
  libopenal-dev \
  libopenscenegraph-dev \
  zlib1g-dev \
  ca-certificates \
  cmake

# plain simgear w/o build env
FROM simgear-builder AS simgear
WORKDIR /app

RUN git clone --depth 1 -b release/2020.3 --single-branch https://git.code.sf.net/p/flightgear/simgear simgear \
    && mkdir -p simgear/build \
    && cd simgear/build \
    && cmake -G "Unix Makefiles" \
             -D CMAKE_BUILD_TYPE=Release \
             -D CMAKE_PREFIX_PATH="/usr/local" \
             -D CMAKE_INSTALL_PREFIX:PATH=/usr/local \
             -D ENABLE_RTI=OFF \
             -D ENABLE_TESTS=OFF \
             -D ENABLE_SOUND=OFF \
             -D USE_AEONWAVE=OFF \
             -D ENABLE_PKGUTIL=OFF \
             -D ENABLE_SIMD=OFF \
             .. \
    && make && make install

# runnable fgelev (elevation probe)
FROM simgear AS fgelev-build

RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  libplib-dev

WORKDIR /app

RUN git clone --depth 1 -b release/2020.3 --single-branch https://git.code.sf.net/p/flightgear/flightgear flightgear \
    && mkdir -p flightgear/build \
    && cd flightgear/build \
    && cmake -G "Unix Makefiles" \
             -D CMAKE_BUILD_TYPE=Release \
             -D ENABLE_AUTOTESTING=Off \
             .. \
    && cd utils/fgelev && make && make install && \
    strip /usr/local/bin/fgelev

# image for fgelev w/o build environment
FROM debian:bookworm-slim AS fgelev
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
  apt-get update && apt-get install -y --no-install-recommends \
  libopenscenegraph161 && \
  apt-get clean

COPY --from=fgelev-build /usr/local/bin/fgelev /usr/local/bin
COPY empty-propertylist.xml /usr/local/lib/FlightGear/defaults.xml
COPY empty-propertylist.xml /usr/local/lib/FlightGear/Materials/default/materials.xml

USER nobody
VOLUME /fg_scenery
ENV FG_SCENERY=/fg_scenery
ENTRYPOINT [ "/usr/local/bin/fgelev" ]
