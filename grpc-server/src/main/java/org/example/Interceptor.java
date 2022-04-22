package org.example;

import io.grpc.Context;
import io.grpc.Contexts;
import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCall.Listener;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import java.util.Optional;

public class Interceptor implements ServerInterceptor {
  public static final Metadata.Key<String> TENANT_ID =
      Metadata.Key.of("X-Tenant-ID", Metadata.ASCII_STRING_MARSHALLER);

  @Override
  public <ReqT, RespT> Listener<ReqT> interceptCall(ServerCall<ReqT, RespT> call, Metadata headers,
      ServerCallHandler<ReqT, RespT> next) {
    Optional<String> tenantId = Optional.ofNullable(headers.get(TENANT_ID));
    Context context = Context.current();
    context =
        context.withValue(Service.TENANT_KEY, tenantId.orElse("<unknown>"));
    return Contexts.interceptCall(context, call, headers, next);
  }
}
