package org.example;

import io.grpc.CallCredentials;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.Metadata;
import io.grpc.Status;
import java.util.concurrent.Executor;
import org.example.proto.GreeterGrpc;
import org.example.proto.GreeterGrpc.GreeterBlockingStub;
import org.example.proto.Service.HelloReply;
import org.example.proto.Service.HelloRequest;

/**
 * Hello world!
 */
public class Client {
  public static void main(String[] args) throws InterruptedException {
    ManagedChannel channel =
        ManagedChannelBuilder.forAddress("localhost", 8080)
            .usePlaintext()
            .directExecutor()
            .build();

    GreeterBlockingStub stub = GreeterGrpc.newBlockingStub(channel);

    HelloReply reply;
    reply = stub.withCallCredentials(new TenantID("abc")).sayHello(HelloRequest.newBuilder().setName("Michael").build());
    System.out.println(reply.getMessage());

    reply = stub.withCallCredentials(new TenantID("def")).sayHello(HelloRequest.newBuilder().setName("Jack").build());
    System.out.println(reply.getMessage());
  }
  public static class TenantID extends CallCredentials {
    public static final Metadata.Key<String> TENANT_ID_KEY =
        Metadata.Key.of("X-Tenant-ID", Metadata.ASCII_STRING_MARSHALLER);

    private final String tenantID;

    public TenantID(String token) {
      this.tenantID = token;
    }

    @Override
    public void applyRequestMetadata(
        RequestInfo requestInfo, Executor appExecutor, MetadataApplier applier) {
      appExecutor.execute(
          () -> {
            try {
              Metadata metadata = new Metadata();
              metadata.put(TENANT_ID_KEY, tenantID);
              applier.apply(metadata);
            } catch (Exception e) {
              applier.fail(Status.UNAUTHENTICATED.withCause(e));
            }
          });
    }

    @Override
    public void thisUsesUnstableApi() {}
  }
}
