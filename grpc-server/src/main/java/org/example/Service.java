package org.example;

import io.grpc.Context;
import io.grpc.stub.StreamObserver;
import java.util.Random;
import org.example.proto.GreeterGrpc.GreeterImplBase;
import org.example.proto.Service.HelloReply;
import org.example.proto.Service.HelloRequest;

public class Service extends GreeterImplBase {
  private static Random random = new Random();

  public static final Context.Key<String> TENANT_KEY = Context.key("tenant");

  public void sayHello(HelloRequest request,
      StreamObserver<HelloReply> responseObserver) {
    responseObserver.onNext(HelloReply.newBuilder().setMessage("Hi " + request.getName() + "! Your tenant ID is: " + TENANT_KEY.get()).build());
    responseObserver.onCompleted();
  }

  public StreamObserver<HelloRequest> sayHelloAgain(
      final StreamObserver<HelloReply> responseObserver) {
    return new StreamObserver<HelloRequest>() {
      @Override
      public void onNext(HelloRequest value) {
        try {
          Thread.sleep(rand(1000));
        } catch (InterruptedException e) {
          e.printStackTrace();
        }
        responseObserver.onNext(HelloReply.newBuilder().setMessage(value.getName()).build());
      }

      @Override
      public void onError(Throwable t) {
        System.err.printf("Error: %s\n", t.getMessage());
      }

      @Override
      public void onCompleted() {
        try {
          Thread.sleep(rand(1000));
        } catch (InterruptedException e) {
          e.printStackTrace();
        }
        responseObserver.onCompleted();
      }
    };
  }

  public static synchronized int rand(int max) {
    return random.nextInt(max);
  }
}
