package org.example;

import com.github.rvesse.airline.SingleCommand;
import com.github.rvesse.airline.annotations.Command;
import com.github.rvesse.airline.annotations.Option;
import io.grpc.Attributes;
import io.grpc.ServerTransportFilter;
import io.grpc.netty.shaded.io.grpc.netty.NettyServerBuilder;
import java.io.IOException;
import java.net.InetSocketAddress;

/**
 * Hello world!
 *
 */
@Command(name="grpc-bench-server")
public class Server
{
    @Option(name="--address")
    protected String address = "127.0.0.1";

    @Option(name="--port")
    protected Integer port = 8090;

    public void run() throws IOException, InterruptedException {
        io.grpc.Server server = NettyServerBuilder.forAddress(new InetSocketAddress(address, port))
            //.directExecutor()
            .addService(new Service())
            .intercept(new Interceptor())
            .addTransportFilter(new ServerTransportFilter() {
                @Override
                public Attributes transportReady(Attributes transportAttrs) {
                  System.out.println("Transport ready:");
                  for (Attributes.Key<?> key : transportAttrs.keys()) {
                    Object attr = transportAttrs.get(key);
                    if (attr != null) {
                      System.out.println(key + " : " + attr + "(" + attr.getClass().getCanonicalName() + ")");
                    }
                  }
                  System.out.println("----");
                  return super.transportReady(transportAttrs);
                }

                @Override
                public void transportTerminated(Attributes transportAttrs) {
                  System.out.println("Transport terminated:");
                  for (Attributes.Key<?> key : transportAttrs.keys()) {
                    Object attr = transportAttrs.get(key);
                    if (attr != null) {
                      System.out.println(key + " : " + attr + "(" + attr.getClass().getCanonicalName() + ")");
                    }
                  }
                  System.out.println("----");
                  super.transportTerminated(transportAttrs);
                }
            })
            .build();
        server.start();
        server.awaitTermination();
    }
    public static void main( String[] args ) throws IOException, InterruptedException {
        SingleCommand<Server> cmd = SingleCommand.singleCommand(Server.class);
        Server server = cmd.parse(args);
        server.run();
    }
}
