#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cp Dockerfile Dockerfile.profiling

sed -i -e 's/FROM\ alpine.*//g' "Dockerfile.profiling"
sed -i -e 's/apk\ update/apt-get\ update/g' "Dockerfile.profiling"
sed -i -e 's/apk\ add/apt-get\ install\ -y/g' "Dockerfile.profiling"
sed -i -e 's/apk\ del/apt-get\ remove\ -y/g' "Dockerfile.profiling"
sed -i -e 's/pcre-dev/libpcre2-dev/g' "Dockerfile.profiling"
sed -i -e 's/zlib/zlibc/g' "Dockerfile.profiling"
sed -i -e 's/zlibc-dev/lua-zlib\ lua-zlib-dev/g' "Dockerfile.profiling"
sed -i -e 's/perl-test-longstring/libtest-longstring-perl/g' "Dockerfile.profiling"
sed -i -e 's/perl-list-moreutils/liblist-moreutils-perl/g' "Dockerfile.profiling"
sed -i -e 's/perl-http-message/libhttp-message-perl/g' "Dockerfile.profiling"
sed -i -e 's/geoip-dev/libgeoip-dev/g' "Dockerfile.profiling"
sed -i -e 's/jemalloc/libjemalloc1/g' "Dockerfile.profiling"
sed -i -e 's/libjemalloc1-dev/libjemalloc-dev/g' "Dockerfile.profiling"
sed -i -e 's/openssl-dev/libssl-dev/g' "Dockerfile.profiling"
sed -i -e 's/jansson\ /libjansson4\ /g' "Dockerfile.profiling"
sed -i -e 's/jansson-dev/libjansson-dev/g' "Dockerfile.profiling"
sed -i -e 's/--with-debug/--with-debug\ --with-dtrace-probes/g' "Dockerfile.profiling"
sed -i -e 's/adduser\ -S.*/useradd\ nginx-api-gateway/g' "Dockerfile.profiling"
sed -i -e 's/&&\ addgroup.*//g' "Dockerfile.profiling"
sed -i -e 's/ENTRYPOINT.*//g' "Dockerfile.profiling"
sed -i -e 's/CMD.*//g' "Dockerfile.profiling"

cp api-gateway.conf api-gateway.conf.profiling
sed -i -e 's/worker_processes\ *auto;/worker_processes\ 1;/g' "api-gateway.conf.profiling"

cat .profiling.before | cat - Dockerfile.profiling > /tmp/out && mv /tmp/out Dockerfile.profiling
cat Dockerfile.profiling | cat - .profiling.after > /tmp/out && mv /tmp/out Dockerfile.profiling

if [[ -f "Dockerfile.profiling-e" ]]; then
	rm Dockerfile.profiling-e
fi
