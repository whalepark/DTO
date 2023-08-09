# Copyright (C) 2023 Intel Corporation
#
# SPDX-License-Identifier: MIT

all: libdto dto-test dto-test-wodto dto-test-pinned dto-test-pinned-wodto

DML_LIB_CXX=-D_GNU_SOURCE

libdto: dto.c
	# gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) -DDTO_STATS_SUPPORT -o libdto.so.1.0 -laccel-config -ldl
	# gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) \
	# 	-L/usr/lib64 \
	# 	-Wl,--rpath=/usr/lib64 \
	# 	-DDTO_STATS_SUPPORT -o libdto.so.1.0 -laccel-config -ldl
	gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) \
		-L/usr/lib64 -L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=$(HOME)/glibc-2.37/install/lib:/usr/lib64 \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-DDTO_STATS_SUPPORT -o libdto.so.1.0 -laccel-config -ldl

libdto_nostats: dto.c
	# gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) \-o libdto.so.1.0 -laccel-config -ldl
	# gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) \
	# 	-L/usr/lib64 \
	# 	-Wl,--rpath=/usr/lib64 \
	# 	-o libdto.so.1.0 -laccel-config -ldl
	gcc -shared -fPIC -Wl,-soname,libdto.so dto.c $(DML_LIB_CXX) \
		-L/usr/lib64 -L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=$(HOME)/glibc-2.37/install/lib:/usr/lib64 \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-o libdto.so.1.0 -laccel-config -ldl

install:
	cp libdto.so.1.0 /usr/lib64/
	ln -sf /usr/lib64/libdto.so.1.0 /usr/lib64/libdto.so.1
	ln -sf /usr/lib64/libdto.so.1.0 /usr/lib64/libdto.so

dto-test-pinned: dto-test-thread-pinned.c
	# gcc -g dto-test-thread-pinned.c $(DML_LIB_CXX) -o dto-test-pinned -ldto -lpthread
	gcc -g dto-test-thread-pinned.c $(DML_LIB_CXX) -o dto-test-pinned \
		-L/usr/lib64 -L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=$(HOME)/glibc-2.37/install/lib:/usr/lib64 \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-ldto -lpthread

dto-test-pinned-wodto: dto-test-thread-pinned.c
	# gcc -g dto-test-thread-pinned.c $(DML_LIB_CXX) -o dto-test-pinned-wodto -lpthread
	gcc -g dto-test-thread-pinned.c $(DML_LIB_CXX) -o dto-test-pinned-wodto \
		-L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=$(HOME)/glibc-2.37/install/lib \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-lpthread

dto-test: dto-test.c
	# gcc -g dto-test.c $(DML_LIB_CXX) -o dto-test -ldto -lpthread
	gcc -g dto-test.c $(DML_LIB_CXX) -o dto-test \
		-L/usr/lib64 -L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=/usr/lib64:$(HOME)/glibc-2.37/install/lib \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-ldto -lpthread

dto-test-wodto: dto-test.c
	gcc -g dto-test.c $(DML_LIB_CXX) -o dto-test-wodto \
		-L$(HOME)/glibc-2.37/install/lib \
		-Wl,--rpath=$(HOME)/glibc-2.37/install/lib \
		-Wl,--dynamic-linker=$(HOME)/glibc-2.37/install/lib/ld-linux-x86-64.so.2 \
		-lpthread

# dto-test: dto-test.c
# 	gcc -g dto-test.c $(DML_LIB_CXX) -o dto-test -ldto -lpthread

# dto-test-wodto: dto-test.c
# 	gcc -g dto-test.c $(DML_LIB_CXX) -o dto-test-wodto -lpthread

clean:
	rm -rf *.o *.so dto-test dto-test-wodto dto-test-pinned dto-test-pinned-wodto
