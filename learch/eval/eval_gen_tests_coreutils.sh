#!/bin/bash

OUTPUT_DIR=${1}
MAX_TIME=${2}

declare -a arr=("mcts" "dfs" "random-state" "nurs" "learch")
declare -a progs=("echo" "sort" "md5sum" "df" "fmt")

for PROG in "${progs[@]}"
    echo "*******************"
    echo "PROGRAM: ${PROG}"
    echo "******************"
    BC_PATH=${SOURCE_DIR}/benchmarks/coreutils-6.11/obj-llvm/src/${PROG}.bc
    for searcher_name in "${arr[@]}"
    do
        echo "*******************"
        echo "SEARCHER: ${searcher_name}"
        echo "******************"
        if [[ "${searcher_name}" == "learch" ]]; then
            searcher_options="--feature-extract --search=ml --model-type=feedforward --model-path=${SOURCE_DIR}/train/trained/feedforward_0.pt"
        elif [[ "${searcher_name}" == "mcts" ]]; then
            searcher_options="--feature-extract --search=mcts"
        elif [[ "${searcher_name}" == "nurs" ]]; then
            searcher_options=""
        else
            searcher_options="--search=${searcher_name}"
        fi
        mkdir -p ${OUTPUT_DIR}/${searcher_name}
        rm -rf ${SANDBOX_DIR}/sandbox-${PROG}
        mkdir -p ${SANDBOX_DIR}/sandbox-${PROG}
        tar -xvf ${SOURCE_DIR}/sandbox.tgz -C ${SANDBOX_DIR}/sandbox-${PROG} > /dev/null

        klee --simplify-sym-indices --write-cov --output-module --disable-inlining \
        --optimize --use-forked-solver --use-cex-cache --libc=uclibc --posix-runtime \
        --external-calls=all --watchdog --max-memory-inhibit=false --switch-type=internal \
        --only-output-states-covering-new \
        --dump-states-on-halt=false \
        --output-dir=${OUTPUT_DIR}/${searcher_name}/${PROG} --env-file=${SANDBOX_DIR}/test.env --run-in-dir=${SANDBOX_DIR}/sandbox-${PROG}/sandbox \
        --max-memory=6000 --max-time=${MAX_TIME}min \
        --use-branching-search ${searcher_options} \
        ${BC_PATH} \
        --sym-args 0 1 10 --sym-args 0 2 2 --sym-files 1 8 --sym-stdin 8 --sym-stdout
    done
done