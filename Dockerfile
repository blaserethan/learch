FROM ubuntu:18.04

ARG NUM_MAKE_CORES=4
ARG WORK_DIR=/root
ARG SOURCE_DIR=/root/learch/learch
ARG SANDBOX_DIR=/tmp

RUN apt -y update
RUN apt -y install build-essential curl libcap-dev git cmake libncurses5-dev python-minimal python-pip unzip libtcmalloc-minimal4 libgoogle-perftools-dev libsqlite3-dev doxygen python3 python3-pip gcc-multilib g++-multilib wget vim
RUN pip3 install tabulate wllvm
RUN apt -y install clang-6.0 llvm-6.0 llvm-6.0-dev llvm-6.0-tools
RUN ln -s /usr/bin/clang-6.0 /usr/bin/clang
RUN ln -s /usr/bin/clang++-6.0 /usr/bin/clang++
RUN ln -s /usr/bin/llvm-config-6.0 /usr/bin/llvm-config
RUN ln -s /usr/bin/llvm-link-6.0 /usr/bin/llvm-link

WORKDIR ${WORK_DIR}
RUN git clone https://github.com/stp/stp.git
WORKDIR ${WORK_DIR}/stp
RUN git checkout 7a3fd493ae6f0a524f853946308f4f3c3ddcbe76
RUN apt install -y cmake bison flex libboost-all-dev python perl minisat
RUN mkdir build
WORKDIR ${WORK_DIR}/stp/build
RUN cmake ..
RUN make -j${NUM_MAKE_CORES}
RUN make install

WORKDIR ${WORK_DIR}
RUN git clone https://github.com/klee/klee-uclibc.git
WORKDIR ${WORK_DIR}/klee-uclibc
RUN git checkout 95bff341a1df58020a39b6f99cc29f6babe4dc67
RUN ./configure --make-llvm-lib
RUN make -j${NUM_MAKE_CORES}

ADD ./ ${WORK_DIR}/learch
ADD ./learch/testing-env.sh ${SANDBOX_DIR}/testing-env.sh
WORKDIR ${WORK_DIR}/learch
RUN pip3 install -r learch/requirements.txt

WORKDIR ${WORK_DIR}/learch/klee
RUN mkdir build
WORKDIR ${WORK_DIR}/learch/klee/build
RUN cmake -DENABLE_SOLVER_STP=ON -DENABLE_POSIX_RUNTIME=ON -DENABLE_KLEE_UCLIBC=ON -DKLEE_UCLIBC_PATH=/root/klee-uclibc -DENABLE_UNIT_TESTS=OFF -DENABLE_SYSTEM_TESTS=OFF -DLLVM_CONFIG_BINARY=/usr/bin/llvm-config -DLLVMCC=/usr/bin/clang -DLLVMCXX=/usr/bin/clang++ -DLIB_PYTHON=/usr/lib/python3.6/config-3.6m-x86_64-linux-gnu/libpython3.6m.so -DPYTHON_INCLUDE_DIRS=/usr/include/python3.6m/ ..
RUN make -j${NUM_MAKE_CORES}
RUN make install

RUN echo "export SOURCE_DIR=${SOURCE_DIR}" >> /root/.bashrc
RUN echo "export SANDBOX_DIR=/tmp" >> /root/.bashrc
RUN echo "export LLVM_COMPILER=clang" >> /root/.bashrc
RUN echo "export PYTHONPATH=${PYTHONPATH}:${SOURCE_DIR}" >> /root/.bashrc
WORKDIR ${SANDBOX_DIR}
RUN env -i /bin/bash -c '(source testing-env.sh; env > test.env)'


WORKDIR ${SOURCE_DIR}/benchmarks
RUN wget https://ftp.gnu.org/gnu/coreutils/coreutils-6.11.tar.gz
RUN tar -xzvf coreutils-6.11.tar.gz
WORKDIR ${SOURCE_DIR}/benchmarks/coreutils-6.11
RUN mkdir obj-gcov
WORKDIR ${SOURCE_DIR}/benchmarks/obj-gcov
RUN ../configure --disable-nls CFLAGS="-g -fprofile-arcs -ftest-coverage"
RUN make
RUN make -C src arch hostname

WORKDIR ${SOURCE_DIR}/benchmarks/coreutils-6.11
RUN mkdir obj-llvm
WORKDIR ${SOURCE_DIR}/benchmarks/coreutils-6.11/obj-llvm
RUN C=wllvm ../configure --disable-nls CFLAGS="-g -O1 -Xclang -disable-llvm-passes -D__NO_STRING_INLINES  -D_FORTIFY_SOURCE=0 -U__OPTIMIZE__"
RUN make
RUN make -C src arch hostname
WORKDIR ${SOURCE_DIR}/benchmarks/coreutils-6.11/obj-llvm/src
RUN find . -executable -type f | xargs -I '{}' extract-bc '{}'

WORKDIR ${SOURCE_DIR}/eval
RUN ./eval_gen_tests_coreutils.sh /root/learch/learch/eval/output 30

WORKDIR /root/learch/learch