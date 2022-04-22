# gRPC connection/tenant experiment

## Setup

### Build `ngnix` docker image with lua support (base image)

```
git clone https://github.com/nginxinc/docker-nginx.git
cd docker-ngnix/modules
git checkout 1.21.6
docker build --build-arg ENABLED_MODULES="ndk lua" -t nginx-lua-1.21.6 .
```

### Build custom `ngnix` docker image and run

```
docker build . -t ngnix-grpc
```

### Build grpc server and client

```
mvn package
```


### Update `/etc/hosts` (or setup DNS using dnsmasg or similar)

Setup DNS so that nginx will route requests to the correct "coordinators" (servers) using DNS by updating `/etc/hosts/`:

```
127.0.0.1 coord.abc.test
127.0.0.2 coord.abc.test

127.0.0.1 coord.def.test
127.0.0.2 coord.def.test
```

Note: I'm using `dnsmasq` to make DNS work properly with the following file `/etc/dnsmasq.d/local.conf`:

```
address=/.test/127.0.0.1
```

You'll need to set your `resolv.conf` or `systemd-resolved` setting to use `127.0.0.1` for DNS.

## To run

### Start proxy and gRPC servers

```
docker run --network host --dns 127.0.0.1 -d --rm ngnix-stargate-grpc
java -jar grpc-server/target/grpc-server-1.0-SNAPSHOT-jar-with-dependencies.jar --address 127.0.0.1 &
java -jar grpc-server/target/grpc-server-1.0-SNAPSHOT-jar-with-dependencies.jar --address 127.0.0.2 &
```

### Run the client

```
java -jar grpc-client/target/grpc-client-1.0-SNAPSHOT-jar-with-dependencies.jar
```

### Output

The servers should output the following as connections are created and destroyed:

```
Transport ready:
remote-addr : /127.0.0.1:36714(java.net.InetSocketAddress)
local-addr : /127.0.0.2:8090(java.net.InetSocketAddress)
io.grpc.internal.GrpcAttributes.securityLevel : NONE(io.grpc.SecurityLevel)
----
Transport terminated:
remote-addr : /127.0.0.1:36686(java.net.InetSocketAddress)
local-addr : /127.0.0.2:8090(java.net.InetSocketAddress)
io.grpc.internal.GrpcAttributes.securityLevel : NONE(io.grpc.SecurityLevel)
----
```




