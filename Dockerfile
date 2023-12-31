# Set the base image to the latest LTS version of Ubuntu
FROM ubuntu:22.04

# Set the working directory to /home
WORKDIR /home

# Create an apt configuration file to fix erroneous "hash sum mismatch" errors
RUN printf "Acquire::http::Pipeline-Depth 0;\nAcquire::http::No-Cache true;\nAcquire::BrokenProxy true;" \
	>> /etc/apt/apt.conf.d/99fixbadproxy

# Prevent prompt to include timezone
ENV DEBIAN_FRONTEND="noninteractive"

# Add the necessary packages to compile Elmer/Ice
RUN apt update -o Acquire::CompressionTypes::Order::=gz && apt upgrade -y && apt install -y \
	build-essential cmake git \
	libblas-dev liblapack-dev libmumps-dev libparmetis-dev \
	libnetcdf-dev libnetcdff-dev libhypre-dev \
	mpich sudo less vim gmsh nano \
	python3-numpy python3-scipy  python3-matplotlib  ipython3  \
	python3-virtualenv  python3-dev  python3-pip  python3-sip

ENV MUMPS_ROOT="/usr/lib/aarch64-linux-gnu/" \
    MUMPS_INC="/usr/include" \
    HYPRE_ROOT="/usr/lib/aarch64-linux-gnu" \
    HYPRE_INC="/usr/include/hypre"


# export these paths before a new user is created otherwise, the users .bashrc
# will overwrite these and render this useless. See:
#          (https://stackoverflow.com/questions/28722548/)
ENV PATH=$PATH:/usr/local/Elmer-devel/bin
ENV PATH=$PATH:/usr/local/Elmer-devel/share/elmersolver/lib

# Add a user "glacier" with sudo privileges
ENV USER=glacier
RUN adduser --disabled-password --gecos '' ${USER} \
	&& adduser ${USER} sudo \
	&& echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ${USER}
ENV HOME=/home/${USER}
WORKDIR ${HOME}

# Add vim syntax highlighting
COPY .vim ${HOME}/.vim/

# Clone the ElmerIce source code and make directories needed for compilation
RUN git clone https://github.com/ElmerCSC/elmerfem.git \
	  && mkdir elmerfem/builddir \
   	  && cd elmerfem
#RUN git clone git://www.github.com/ElmerCSC/elmerfem -b elmerice elmerice \
#	  && mkdir elmerice/builddir

#RUN git checkout devel 

# Move to the builddir
WORKDIR ${HOME}/elmerfem/builddir

RUN	cmake ${HOME}/elmerfem \
		-DCMAKE_INSTALL_PREFIX=/usr/local/Elmer-devel \
		-DCMAKE_C_COMPILER=/usr/bin/gcc \
		-DCMAKE_Fortran_COMPILER=/usr/bin/gfortran \
		-DWITH_MPI:BOOL=TRUE \
		-DWITH_LUA:BOOL=TRUE \
		-DWITH_OpenMP:BOOLEAN=TRUE \
		-DWITH_Trilinos:BOOL=FALSE \
		-DWITH_ELMERGUI:BOOL=FALSE \
		-DWITH_ElmerIce:BOOL=TRUE \
		-DWITH_NETCDF:BOOL=TRUE \
		-DWITH_GridDataReader:BOOL=TRUE \
		-DWITH_Mumps:BOOL=TRUE \
	        -DMumps_LIBRARIES="${MUMPS_ROOT}/libpord.so;${MUMPS_ROOT}/libmumps_common.so;${MUMPS_ROOT}/libdmumps.so" \
		-DMumps_INCLUDE_DIR="${MUMPS_INC}" \
		-DWITH_Hypre:BOOL=TRUE \
                -DHypre_LIBRARIES="${HYPRE_ROOT}/libHYPRE.so"\
                -DHypre_INCLUDE_DIR="${HYPRE_INC}"

# compile the source code
RUN make && sudo make install


# set the working dir to home
WORKDIR ${HOME}
