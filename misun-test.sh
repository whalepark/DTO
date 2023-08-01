#!/bin/bash

DSA_DEVICES=(0 8 2 10 4 12 6 14)
DSA_LOCAL_0=(0 2 4 6)       # dsa devices on node 0: core 
DSA_LOCAL_1=(8 10 12 14)    # dsa devices on node 1


N=20
# DATA_SIZES=(1)
DATA_SIZES=(1 4 16 32 64 128 256 512 1024)

function main () {
    rm -rf increasing_numthreads compare_distances increasing_numchannels

    dto_exp_increasing_numthreads
    dto_exp_increasing_numchannels
    dto_exp_compare_local_remote

    restore_sourcecode
}

function dto_exp_increasing_numthreads() {
:<<'DESCRIPTION'
    Purpose of this function:
        - with a fixed number of channels (n=4)
          increasing the number of threads from 1-10
DESCRIPTION

    local filename=dto-test.c
    local pattern="^#define BUF_SIZE"

    # for numthreads in $(seq 1 10); do
    for numthreads in $(seq 9 10); do
        reset_dir
        config_dsa 4 local

        grep -q "$pattern" $filename # no line defining bufsize, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '15i\#define BUF_SIZE (128*1024UL)' $filename
        fi

        grep -q "^#define MAX_THREADS" $filename # no line defining numthreads, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '22i\#define MAX_THREADS 10' $filename
        fi

        local define_numthreads="#define MAX_THREADS $numthreads"
        sed -i "/^#define MAX_THREADS/c\\${define_numthreads}" $filename

        for size in ${DATA_SIZES[@]}; do
            local define_bufsize="#define BUF_SIZE ($size*1024UL)"
            sed -i "/${pattern}/c\\${define_bufsize}" $filename
            run_wo_dto
            run_w_dto_dyn
            run_w_dto_st
            # profile_dto_w_perf
            
            parse_and_plot increasing_numthreads $numthreads 4
        done
    done
}

function dto_exp_compare_local_remote() {
:<<'DESCRIPTION'
    Purpose of this function:
        - with a fixed number of threads (n=10)
          and the number of channels of 10,
          see if locality of dsa device affects the performance or not
DESCRIPTION

    local filename=dto-test.c
    local pattern="^#define BUF_SIZE"

    for distance in local remote; do
        reset_dir
        config_dsa 10 $distance

        grep -q "$pattern" $filename # no line defining bufsize, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '15i\#define BUF_SIZE (128*1024UL)' $filename
        fi

        grep -q "^#define MAX_THREADS" $filename # no line defining numthreads, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '22i\#define MAX_THREADS 10' $filename
        fi
        local define_numthreads="#define MAX_THREADS 10"
        sed -i "/^#define MAX_THREADS/c\\${define_numthreads}" $filename

        for size in ${DATA_SIZES[@]}; do
            local define_bufsize="#define BUF_SIZE ($size*1024UL)"
            sed -i "/${pattern}/c\\${define_bufsize}" $filename
            run_wo_dto
            run_w_dto_dyn
            run_w_dto_st
            # profile_dto_w_perf
            
            parse_and_plot compare_distances 10 10
        done
    done
}

function dto_exp_increasing_numchannels() {
:<<'DESCRIPTION'
    Purpose of this function:
        - with a fixed number of threads (n=10)
          increasing the number of channels from 1-10
DESCRIPTION

    local filename=dto-test.c
    local pattern="^#define BUF_SIZE"

    for numchannels in $(seq 10 -1 1); do
    # for numchannels in $(seq 1 10); do
        reset_dir
        config_dsa $numchannels local

        grep -q "$pattern" $filename # no line defining bufsize, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '15i\#define BUF_SIZE (128*1024UL)' $filename
        fi

        grep -q "^#define MAX_THREADS" $filename # no line defining numthreads, you add one
        if [[ $? -ne 0 ]]; then
            sed -i '22i\#define MAX_THREADS 10' $filename
        fi
        local define_numthreads="#define MAX_THREADS 10"
        sed -i "/^#define MAX_THREADS/c\\${define_numthreads}" $filename

        for size in ${DATA_SIZES[@]}; do
            local define_bufsize="#define BUF_SIZE ($size*1024UL)"
            sed -i "/${pattern}/c\\${define_bufsize}" $filename
            run_wo_dto
            run_w_dto_dyn
            run_w_dto_st
            # profile_dto_w_perf
            
            parse_and_plot increasing_numchannels 10 $numchannels
        done
    done
}

function config_dsa() {
    if [[ $EUID -ne 0 ]]; then
        echo "This accel-config requires root privileges."
        echo "# sudo -E {script}"
        exit 1
    fi

    local numchannels=$([[ $1 -le 32 ]] && echo $1 || echo 32)
    local dsa_distance=${2:-local}

    for i in ${DSA_DEVICES[@]}; do
        accel-config disable-device dsa$i
    done

    case $dsa_distance in
        local)
            local device_denominator=4
            local numdevices=$(echo "($numchannels + $device_denominator - 1)/$device_denominator" | bc)
            numdevices=$([[ "$numchannels" -lt $device_denominator ]] && echo "$numchannels" || echo $device_denominator)
            local devices=(${DSA_LOCAL_0[@]})
            ;;
        remote)
            local device_denominator=8
            local numdevices=$(echo "($numchannels + $device_denominator - 1)/$device_denominator" | bc)
            numdevices=$([[ "$numchannels" -lt $device_denominator ]] && echo "$numchannels" || echo $device_denominator)
            local devices=(${DSA_DEVICES[@]})
            ;;
        *)
            echo Invalid dsa_distance: $dsa_distance
            exit 1
            ;;
    esac

    declare -A dsa_to_wq
    local wq_index_0=0
    local wq_index_1=1
    local engine_index=0

    misun_log '# (1) configuring devices and queues'
    for i in $(seq 0 $numchannels); do
        if [[ $i -eq $numchannels ]]; then
            break
        fi
        if [ $(expr "$i" % "$numdevices") -eq 0 ] && [ "$i" -ne 0 ]; then
            wq_index_0=$((wq_index_0+2))
            wq_index_1=$((wq_index_1+2))
            engine_index=$((engine_index+1))
        fi
        local device_index=$(bc <<< "$i % $device_denominator")
        local device_number=${devices[$device_index]}
        local group_id=$((i/device_denominator))

        # echo i=$i
        # echo device_number=$device_number
        # echo group_id=$group_id

        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --group-id=$group_id
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --priority=10
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --wq-size=16
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --type=user
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --name="dsa-test"
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --mode=shared
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --threshold=16
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --max-transfer-size=1024
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_0 --max-batch-size=1024

        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --group-id=$group_id
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --priority=10
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --wq-size=16
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --type=user
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --name="dsa-test"
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --mode=shared
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --threshold=16
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --max-transfer-size=1024 # 1-1024
        misun_log_and_run accel-config config-wq dsa$device_number/wq$device_number.$wq_index_1 --max-batch-size=1024

        misun_log_and_run accel-config config-engine dsa$device_number/engine$device_number.$engine_index --group-id=$group_id

        dto_wq_list+="wq$device_number.$wq_index_0;wq$device_number.$wq_index_1;"
        dsa_to_wq[$device_number]+="$wq_index_0 $wq_index_1 "
    done

    # Iterating over keys.. uncomment only for a debugging purpose
    misun_log \# caller=${FUNCNAME[1]}
    misun_log \# args=\($1 $2\)
    for dsa in "${!dsa_to_wq[@]}"; do
        misun_log "# # $dsa --> ${dsa_to_wq[$dsa]}"
    done
    
    misun_log
    misun_log '# (2) enabling devices and queues'
    for device_to_enable in ${!dsa_to_wq[@]}; do
        misun_log_and_run accel-config enable-device dsa${device_to_enable}
        local wq_list=(${dsa_to_wq[$device_to_enable]})
        for wq_index in ${wq_list[@]}; do
            misun_log_and_run accel-config enable-wq dsa${device_to_enable}/wq${device_to_enable}.$wq_index
        done
    done

    dto_wq_list="${dto_wq_list%?}" # to remove the trailing semicolon

    export DTO_USESTDC_CALLS=0
    export DTO_COLLECT_STATS=1
    export DTO_WAIT_METHOD=yield
    export DTO_MIN_BYTES=8192
    export DTO_CPU_SIZE_FRACTION=0.33
    export DTO_AUTO_ADJUST_KNOBS=1
    export DTO_WQ_LIST=$dto_wq_list
}

function old_config() {
    accel-config disable-device dsa0
    accel-config disable-device dsa2
    accel-config disable-device dsa4
    accel-config disable-device dsa6

    accel-config load-config -c ./dto-4-dsa.conf

    accel-config enable-device dsa0
    accel-config enable-device dsa2
    accel-config enable-device dsa4
    accel-config enable-device dsa6

    accel-config enable-wq dsa0/wq0.0
    accel-config enable-wq dsa2/wq2.0
    accel-config enable-wq dsa4/wq4.0
    accel-config enable-wq dsa6/wq6.0

    export DTO_USESTDC_CALLS=0
    export DTO_COLLECT_STATS=1
    export DTO_WAIT_METHOD=yield
    export DTO_MIN_BYTES=8192
    export DTO_CPU_SIZE_FRACTION=0.33
    export DTO_AUTO_ADJUST_KNOBS=1
}

function misun_log() {
    mkdir -p misun-results
    echo "$@" >> misun-results/dsa_configuration
}

function misun_log_and_run() {
    misun_log "$@"
    "$@"
}

function reset_dir() {
    rm -rf misun-results
    mkdir -p misun-results

    make dto-test
    make dto-test-wodto
}

function run_wo_dto() {
    # Run dto-test without DTO library
    for i in $(seq $N); do
        /usr/bin/time --format="[results] pagefaults(min)=%R:pagefaults(maj)=%F:elapsed=%e:sys=%S:user=%U:maxrss=%M:voluntarycs=%w:involuntarycs=%c" \
            ./dto-test-wodto 2>&1 | grep 'results' >> misun-results/wo-dto.txt
    done
}

function run_w_dto_dyn() {
    # Run dto-test with DTO library using LD_PRELOAD method
    for i in $(seq $N); do
        export LD_PRELOAD=./libdto.so.1.0
        /usr/bin/time --format="[results] pagefaults(min)=%R:pagefaults(maj)=%F:elapsed=%e:sys=%S:user=%U:maxrss=%M:voluntarycs=%w:involuntarycs=%c" \
            ./dto-test-wodto 2>&1 | grep 'results' >> misun-results/w-dto-dyn.txt
        unset LD_PRELOAD
    done
    sed -i '/results/!d' misun-results/w-dto-dyn.txt
}

function run_w_dto_st() {
    # Run dto-test with DTO library using "re-compile with DTO" method
    # (i.e., without LD_PRELOAD)
    export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
    for i in $(seq $N); do
        /usr/bin/time --format="[results] pagefaults(min)=%R:pagefaults(maj)=%F:elapsed=%e:sys=%S:user=%U:maxrss=%M:voluntarycs=%w:involuntarycs=%c" \
            ./dto-test 2>&1 | grep 'results' >> misun-results/w-dto-st.txt
    done
    sed -i '/results/!d' misun-results/w-dto-st.txt
    unset LD_LIBRARY_PATH
}

function profile_dto_w_perf() {
    # Run dto-test with DTO and get DSA perfmon counters
    export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH
    perf stat -e dsa0/event=0x1,event_category=0x0/,dsa2/event=0x1,event_category=0x0/,dsa4/event=0x1,event_category=0x0/,dsa6/event=0x1,event_category=0x0/,dsa0/event=0x1,event_category=0x1/,dsa2/event=0x1,event_category=0x1/,dsa4/event=0x1,event_category=0x1/,dsa6/event=0x1,event_category=0x1/,dsa0/event=0x2,event_category=0x1/,dsa2/event=0x2,event_category=0x1/,dsa4/event=0x2,event_category=0x1/,dsa6/event=0x2,event_category=0x1/ /usr/bin/time ./dto-test
    unset LD_LIBRARY_PATH
}

function parse_and_plot() {
    local scenario=$1
    local t=$2
    local c=$3

    # cd ~ && python3.8 -m venv misun-parse && cd -
    cd ~ && source misun-parse/bin/activate && cd DTO

    # files=(wo-dto.txt w-dto-dyn.txt w-dto-st.txt)
    for file in misun-results/*.txt; do
        local parsed_file=${file%%.txt}
        python result-parse.py $file > ${parsed_file}.log
    done

    local buffer_size=$(grep '#define BUF_SIZE' dto-test.c | head -n1 | cut -d' ' -f3 | sed 's/UL//g' | tr -d '()' | bc)
    buffer_size="data=${buffer_size}_threads=${t}_channels=${c}_n=$N"
    rm -rf $buffer_size
    mkdir -p $buffer_size
    python draw-plot.py $buffer_size $(ls misun-results/*.log)
    
    mv misun-results "${buffer_size}/."
    mkdir -p $scenario misun-results
    mv "${buffer_size}" $scenario/
}

function restore_sourcecode() {
    local filename=dto-test.c

    grep -q "^#define BUF_SIZE" $filename # no line defining bufsize, you add one
    if [[ $? -ne 0 ]]; then
        sed -i '15i\#define BUF_SIZE (128*1024UL)' $filename
    else
        sed -i "/^#define BUF_SIZE/c\#define BUF_SIZE (128*1024UL)" $filename
    fi

    grep -q "^#define MAX_THREADS" $filename # no line defining bufsize, you add one
    if [[ $? -ne 0 ]]; then
        sed -i '22i\#define MAX_THREADS 10' $filename
    else
        sed -i "/^#define MAX_THREADS/c\#define MAX_THREADS 10" $filename
    fi
}

main "$@"; exit